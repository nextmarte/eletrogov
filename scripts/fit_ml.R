#!/usr/bin/env Rscript
# fit_ml.R — Matriz de modelos (GLM / RF × Original / Expandido) + Árvore
# Pooled TIC Domicílios 2021-2025, CV 5-fold com folds fixos (comparação pareada).
# Holdout temporal: treina em 2021-2024, testa em 2025.
# Saída: dados/ml_results.rds (lido pelo chunk ml-setup em analise_egov.qmd).
#
# Correções em relação à versão anterior:
#  - Vars categóricas (RENDA_FAMILIAR, CLASSE_CB, GRAU_INSTRUCAO, C5_DISPOSITIVOS)
#    convertidas para factor -> GLM dummifica corretamente.
#  - Classe positiva = "Sim" (usa e-gov); Sens passa a ser recall de e-gov.
#  - Holdout temporal 2025 como teste externo (treina 2021-2024).
#
# Uso: Rscript fit_ml.R

suppressPackageStartupMessages({
  library(tidyverse)
  library(haven)
  library(caret)
  library(pROC)
  library(doParallel)
})

# Dicionário canônico das 16 vars de uso digital (nomes interpretáveis).
# Carrega: vars_extra (nomes novos), vars_extra_rename (mapa código TIC -> nome).
source("scripts/var_labels.R")

set.seed(42)
t0 <- Sys.time()

# ---- [1/6] Carregar microdados ----
anos <- 2021:2025
ler_sav <- function(a) read_sav(sprintf("dados/tic_ind_%d.sav", a), encoding = "UTF-8")

harmonizar_nomes <- function(d) {
  names(d) <- toupper(names(d))
  ren <- function(df, from, to) {
    if (from %in% names(df)) {
      if (to %in% names(df)) df[[to]] <- NULL
      names(df)[names(df) == from] <- to
    }
    df
  }
  d <- ren(d, "RENDA_FAMILIAR_2", "RENDA_FAMILIAR")
  d <- ren(d, "PEA_2", "PEA")
  if ("GRAU_INSTRUCAO_2" %in% names(d)) d <- ren(d, "GRAU_INSTRUCAO_2", "GRAU_INSTRUCAO")
  else if ("GRAU_INST_1" %in% names(d)) d <- ren(d, "GRAU_INST_1", "GRAU_INSTRUCAO")
  for (src in c("CLASSE_CB2015", "CLASSE_2015")) {
    if (src %in% names(d) && !("CLASSE_CB" %in% names(d))) {
      names(d)[names(d) == src] <- "CLASSE_CB"; break
    }
  }
  d <- ren(d, "COD_REGIAO_2", "COD_REGIAO")
  d
}

cat("[1/6] Carregando 2021-2025\n")
dados <- map(anos, function(a) {
  cat("  ", a, "...", sep = "")
  d <- ler_sav(a) %>% harmonizar_nomes()
  d <- d %>% mutate(across(where(is.labelled), as.numeric))
  d$.ano <- a
  cat(" OK\n")
  d
})

# ---- [2/6] Variáveis ----
vars_art <- c("IDADE", "PEA", "H2", "RENDA_FAMILIAR", "CLASSE_CB",
              "GRAU_INSTRUCAO", "C5_DISPOSITIVOS")

# Vars que devem virar factor (categóricas/ordinais sem assumir linearidade)
vars_categoricas <- c("RENDA_FAMILIAR", "CLASSE_CB", "GRAU_INSTRUCAO", "C5_DISPOSITIVOS")

# Top universais do screening (explora_variaveis_full.R), exclui endógenas
# (C8_F busca-info-governo, C8_G serviços-públicos, C8_H pagamentos — outcome).
# Códigos TIC usados para SELECIONAR colunas dos SAVs; logo após o bind_rows
# aplicamos rename(any_of(vars_extra_rename)) para os nomes interpretáveis.
vars_extra_codigos <- unname(vars_extra_rename)

vars_todas_codigos <- c("G1_AGREG", "C1", vars_art, vars_extra_codigos)

dados_red <- map(dados, function(d) {
  if (!"G1_AGREG" %in% names(d)) {
    g1_cols <- grep("^G1_[A-H]$", names(d), value = TRUE)
    d$G1_AGREG <- as.integer(rowSums(
      sapply(d[g1_cols], function(x) as.numeric(x) == 1), na.rm = TRUE) > 0)
  }
  cols_ok <- intersect(vars_todas_codigos, names(d))
  d <- d[, c(cols_ok, ".ano")]
  faltam <- setdiff(vars_todas_codigos, cols_ok)
  for (f in faltam) d[[f]] <- NA_real_
  d[, c(vars_todas_codigos, ".ano")]
})
pool <- bind_rows(dados_red)

# Rename: códigos TIC -> nomes interpretáveis (BUSCA_SAUDE, CELULAR_MAPAS, ...)
pool <- pool %>% rename(any_of(vars_extra_rename))
vars_todas <- c("G1_AGREG", "C1", vars_art, vars_extra)
cat(sprintf("  Pool bruto: %d × %d\n", nrow(pool), ncol(pool)))

# ---- [3/6] Filtros + preparo ----
cat("\n[3/6] Aplicando filtros e preparando datasets\n")
recode_na <- function(x) { x <- as.numeric(x); x[x %in% c(97, 98, 99)] <- NA; x }

pool <- pool %>%
  mutate(across(all_of(c(vars_art, vars_extra)), recode_na)) %>%
  filter(C1 == 1, IDADE >= 16) %>%
  mutate(
    # Classe positiva = "Sim" (usa e-gov). Ordem do factor inverte default do
    # caret/twoClassSummary -> Sens passa a ser recall de e-gov.
    G1_AGREG       = factor(if_else(G1_AGREG == 1, 1, 0),
                            levels = c(1, 0), labels = c("Sim", "Nao")),
    RENDA_FAMILIAR = if_else(RENDA_FAMILIAR == 9, 0, RENDA_FAMILIAR),
    CLASSE_CB      = if_else(CLASSE_CB >= 1 & CLASSE_CB <= 4, CLASSE_CB, NA_real_),
    ano_num        = as.numeric(.ano) - 2021,
    .ano           = as.integer(.ano)
  ) %>%
  select(-C1)

# N comum (drop_na sobre vars artigo + extras) — garante comparação pareada
df_exp_all <- pool %>%
  select(G1_AGREG, all_of(vars_art), all_of(vars_extra), ano_num, .ano) %>%
  drop_na()

# Factorizar vars categóricas APÓS drop_na (mantém preenchimento consistente)
df_exp_all <- df_exp_all %>%
  mutate(across(all_of(vars_categoricas), ~ factor(as.integer(.x))))

df_orig_all <- df_exp_all %>%
  select(G1_AGREG, all_of(vars_art), ano_num, .ano)

# Dataset de CV (todos os anos, 2021-2025)
df_exp  <- df_exp_all %>% select(-.ano)
df_orig <- df_orig_all %>% select(-.ano)

# Dataset de holdout temporal: treino 2021-2024, teste 2025
df_exp_train  <- df_exp_all %>% filter(.ano <= 2024) %>% select(-.ano)
df_exp_test   <- df_exp_all %>% filter(.ano == 2025) %>% select(-.ano)
df_orig_train <- df_orig_all %>% filter(.ano <= 2024) %>% select(-.ano)
df_orig_test  <- df_orig_all %>% filter(.ano == 2025) %>% select(-.ano)

cat(sprintf("  N comum total (2021-2025): %d\n", nrow(df_exp)))
cat(sprintf("  N treino (2021-2024):      %d\n", nrow(df_exp_train)))
cat(sprintf("  N teste (2025):            %d\n", nrow(df_exp_test)))
cat(sprintf("  Proporção e-gov (total):   %.4f\n", mean(df_exp$G1_AGREG == "Sim")))

# ---- [4/6] CV folds fixos ----
set.seed(42)
folds <- createFolds(df_exp$G1_AGREG, k = 5, returnTrain = TRUE)

ctrl <- trainControl(
  method = "cv", number = 5, index = folds,
  classProbs = TRUE, summaryFunction = twoClassSummary,
  savePredictions = "final", allowParallel = TRUE
)

# ---- [4b/6] Treinar modelos (CV) ----
cat("\n[4b/6] Treinando modelos com CV 5-fold paralelo\n")
registerDoParallel(cores = max(1, parallel::detectCores() - 1))
on.exit(stopImplicitCluster(), add = TRUE)

treinar_glm <- function(df, rot) {
  cat(sprintf("  GLM  %-10s (N=%d, p=%d) ... ", rot, nrow(df), ncol(df) - 1))
  t1 <- Sys.time()
  m <- train(G1_AGREG ~ ., data = df, method = "glm", family = "binomial",
             trControl = ctrl, metric = "ROC")
  cat(format(Sys.time() - t1), "\n"); m
}

treinar_tree <- function(df, rot) {
  cat(sprintf("  Tree %-10s (N=%d, p=%d) ... ", rot, nrow(df), ncol(df) - 1))
  t1 <- Sys.time()
  m <- train(G1_AGREG ~ ., data = df, method = "rpart",
             trControl = ctrl, metric = "ROC", tuneLength = 10)
  cat(format(Sys.time() - t1), "\n"); m
}

treinar_rf <- function(df, rot) {
  cat(sprintf("  RF   %-10s (N=%d, p=%d) ... ", rot, nrow(df), ncol(df) - 1))
  t1 <- Sys.time()
  # Com factors, o número efetivo de colunas no modelo.matrix difere de p
  p <- ncol(model.matrix(G1_AGREG ~ ., data = df)) - 1
  grid <- expand.grid(
    mtry          = unique(round(c(sqrt(p), p / 3, p / 2))),
    splitrule     = "gini",
    min.node.size = 5
  )
  m <- train(G1_AGREG ~ ., data = df, method = "ranger",
             trControl = ctrl, metric = "ROC",
             tuneGrid = grid, importance = "impurity",
             num.trees = 300, num.threads = 1)
  cat(format(Sys.time() - t1), "\n"); m
}

modelos <- list()
modelos$glm_orig <- treinar_glm(df_orig, "original")
modelos$glm_exp  <- treinar_glm(df_exp,  "expandido")
modelos$tree     <- treinar_tree(df_orig,"original")
modelos$rf_orig  <- treinar_rf(df_orig,  "original")
modelos$rf_exp   <- treinar_rf(df_exp,   "expandido")

# ---- [5/6] Holdout temporal 2025 ----
cat("\n[5/6] Holdout temporal (treino 2021-2024, teste 2025)\n")
# Reuso os modelos já treinados com CV? Não — eles viram treino em TODAS as
# linhas do CV. Treino aqui somente nos dados de treino, avalio no teste 2025.
# Uso o best-tune de cada modelo do CV para não re-tunar.

treinar_final <- function(df_tr, method, best_tune = NULL, ...) {
  ctrl_f <- trainControl(method = "none", classProbs = TRUE,
                         savePredictions = "final")
  args <- list(form = G1_AGREG ~ ., data = df_tr, method = method,
               trControl = ctrl_f, metric = "ROC", ...)
  if (!is.null(best_tune)) args$tuneGrid <- best_tune
  do.call(train, args)
}

avaliar <- function(m, df_te) {
  prob <- predict(m, newdata = df_te, type = "prob")[, "Sim"]
  pred <- predict(m, newdata = df_te)
  r <- roc(df_te$G1_AGREG, prob, levels = c("Nao", "Sim"),
           direction = "<", quiet = TRUE)
  auc_v <- as.numeric(auc(r))
  cm <- caret::confusionMatrix(pred, df_te$G1_AGREG, positive = "Sim")
  tibble(
    AUC   = auc_v,
    Sens  = cm$byClass["Sensitivity"],
    Spec  = cm$byClass["Specificity"],
    Prec  = cm$byClass["Pos Pred Value"],
    F1    = cm$byClass["F1"]
  )
}

holdout <- list()
holdout$glm_orig <- treinar_final(df_orig_train, "glm", family = "binomial")
holdout$glm_exp  <- treinar_final(df_exp_train,  "glm", family = "binomial")
holdout$rf_orig  <- treinar_final(df_orig_train, "ranger",
                                  best_tune = modelos$rf_orig$bestTune,
                                  num.trees = 300, num.threads = 4,
                                  importance = "impurity")
holdout$rf_exp   <- treinar_final(df_exp_train,  "ranger",
                                  best_tune = modelos$rf_exp$bestTune,
                                  num.trees = 300, num.threads = 4,
                                  importance = "impurity")

resumo_holdout <- imap_dfr(holdout, function(m, nome) {
  r <- avaliar(m, if (str_detect(nome, "exp$")) df_exp_test else df_orig_test)
  r$modelo <- nome
  r
}) %>% select(modelo, AUC, Sens, Spec, Prec, F1)

cat("\nResultados no holdout 2025:\n")
print(resumo_holdout)

# ---- [6/6] Resamples, resumo e save ----
cat("\n[6/6] Consolidando CV + holdout\n")
resultados_ml <- resamples(list(
  `GLM Original`  = modelos$glm_orig,
  `GLM Expandido` = modelos$glm_exp,
  `Árvore`        = modelos$tree,
  `RF Original`   = modelos$rf_orig,
  `RF Expandido`  = modelos$rf_exp
))

# Métricas OOF com positive=Sim (calcula direto das predições salvas)
pegar_oof <- function(m, label) {
  p <- m$pred
  if (!is.null(m$bestTune)) {
    # filtra predições do best tune
    for (col in intersect(names(m$bestTune), names(p))) {
      p <- p[p[[col]] == m$bestTune[[col]], ]
    }
  }
  cm  <- caret::confusionMatrix(p$pred, p$obs, positive = "Sim")
  roc_obj <- roc(p$obs, p$Sim, levels = c("Nao", "Sim"),
                 direction = "<", quiet = TRUE)
  tibble(
    modelo = label,
    N      = nrow(p),
    AUC    = as.numeric(auc(roc_obj)),
    Sens   = as.numeric(cm$byClass["Sensitivity"]),
    Spec   = as.numeric(cm$byClass["Specificity"]),
    Prec   = as.numeric(cm$byClass["Pos Pred Value"]),
    F1     = as.numeric(cm$byClass["F1"])
  )
}

resumo <- bind_rows(
  pegar_oof(modelos$glm_orig, "GLM Original"),
  pegar_oof(modelos$glm_exp,  "GLM Expandido"),
  pegar_oof(modelos$tree,     "Árvore"),
  pegar_oof(modelos$rf_orig,  "RF Original"),
  pegar_oof(modelos$rf_exp,   "RF Expandido")
) %>%
  mutate(vars = if_else(modelo %in% c("GLM Expandido","RF Expandido"),
                        "artigo+extra", "artigo"),
         .before = N) %>%
  mutate(across(c(AUC, Sens, Spec, Prec, F1), ~ round(.x, 4)))

print(resumo)

auc <- set_names(resumo$AUC, resumo$modelo)
cat("\n=== Ganhos (AUC) ===\n")
cat(sprintf("  ML (RF vs GLM, vars originais):   ΔAUC = %+.4f\n",
            auc["RF Original"] - auc["GLM Original"]))
cat(sprintf("  Novas vars (GLM Exp vs Orig):     ΔAUC = %+.4f\n",
            auc["GLM Expandido"] - auc["GLM Original"]))
cat(sprintf("  Novas vars (RF Exp vs Orig):      ΔAUC = %+.4f\n",
            auc["RF Expandido"] - auc["RF Original"]))
cat(sprintf("  Combinado (RF Exp vs GLM Orig):   ΔAUC = %+.4f\n",
            auc["RF Expandido"] - auc["GLM Original"]))

dir.create("dados", showWarnings = FALSE)
saveRDS(list(
  modelos        = modelos,
  holdout        = holdout,
  resamples      = resultados_ml,
  resumo         = resumo,
  resumo_holdout = resumo_holdout,
  df_orig        = df_orig,
  df_exp         = df_exp,
  df_exp_train   = df_exp_train,
  df_exp_test    = df_exp_test,
  df_orig_train  = df_orig_train,
  df_orig_test   = df_orig_test,
  vars_art       = vars_art,
  vars_extra     = vars_extra,
  vars_categoricas = vars_categoricas,
  meta           = list(
    timestamp = Sys.time(),
    R_version = R.version.string,
    N         = nrow(df_exp),
    N_train   = nrow(df_exp_train),
    N_test    = nrow(df_exp_test),
    anos      = anos,
    classe_positiva = "Sim"
  )
), "dados/ml_results.rds")

cat(sprintf("\n[OK] Gravado dados/ml_results.rds (%s bytes) | Tempo total: %s\n",
            format(file.size("dados/ml_results.rds"), big.mark = "."),
            format(Sys.time() - t0)))
