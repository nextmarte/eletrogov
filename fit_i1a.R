#!/usr/bin/env Rscript
# fit_i1a.R — Sub-modelo 2022-2025 com habilidades digitais (I1A_*)
# Treina GLM e RF com vars do artigo + 16 universais + 12 I1A_* (só anos 2022+).
# Saída: dados/i1a_results.rds.
#
# Uso: Rscript fit_i1a.R

suppressPackageStartupMessages({
  library(tidyverse)
  library(haven)
  library(caret)
  library(pROC)
  library(doParallel)
})

set.seed(42)
t0 <- Sys.time()

anos <- 2022:2025
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

vars_art <- c("IDADE","PEA","H2","RENDA_FAMILIAR","CLASSE_CB",
              "GRAU_INSTRUCAO","C5_DISPOSITIVOS")
vars_categoricas <- c("RENDA_FAMILIAR","CLASSE_CB","GRAU_INSTRUCAO","C5_DISPOSITIVOS")

vars_extra <- c("C8_A","C8_B","C8_D","C8_E","J2_L","J2_J","J2_G","J2_K",
                "C9_D","C9_C","C10_A","C10_C","C10_D","C11_A","C7_A","B1")

vars_i1a <- c("I1A_A","I1A_B","I1A_C","I1A_D","I1A_E","I1A_F",
              "I1A_G","I1A_H","I1A_I","I1A_J","I1A_K","I1A_L")

cat("[1/4] Carregando 2022-2025\n")
dados <- map(anos, function(a) {
  cat("  ", a, "...", sep = "")
  d <- ler_sav(a) %>% harmonizar_nomes()
  d <- d %>% mutate(across(where(is.labelled), as.numeric))
  d$.ano <- a
  cat(" OK\n")
  d
})

vars_todas <- c("G1_AGREG","C1", vars_art, vars_extra, vars_i1a)

dados_red <- map(dados, function(d) {
  if (!"G1_AGREG" %in% names(d)) {
    g1_cols <- grep("^G1_[A-H]$", names(d), value = TRUE)
    d$G1_AGREG <- as.integer(rowSums(
      sapply(d[g1_cols], function(x) as.numeric(x) == 1), na.rm = TRUE) > 0)
  }
  cols_ok <- intersect(vars_todas, names(d))
  d <- d[, c(cols_ok, ".ano")]
  faltam <- setdiff(vars_todas, cols_ok)
  for (f in faltam) d[[f]] <- NA_real_
  d[, c(vars_todas, ".ano")]
})
pool <- bind_rows(dados_red)

cat("\n[2/4] Filtros + preparo\n")
recode_na <- function(x) { x <- as.numeric(x); x[x %in% c(97,98,99)] <- NA; x }
# Para I1A_* (habilidades digitais): "Não sei/Não respondeu" (97/98/99) é
# tratado como "não tem a habilidade" (0). Sem isso, o drop_na zera o N
# (maioria responde NS/NR em pelo menos uma das 12 habilidades).
recode_hab <- function(x) { x <- as.numeric(x); x[x %in% c(97,98,99)] <- 0; x }

pool <- pool %>%
  mutate(across(all_of(c(vars_art, vars_extra)), recode_na)) %>%
  mutate(across(all_of(vars_i1a), recode_hab)) %>%
  filter(C1 == 1, IDADE >= 16) %>%
  mutate(
    G1_AGREG       = factor(if_else(G1_AGREG == 1, 1, 0),
                            levels = c(1, 0), labels = c("Sim","Nao")),
    RENDA_FAMILIAR = if_else(RENDA_FAMILIAR == 9, 0, RENDA_FAMILIAR),
    CLASSE_CB      = if_else(CLASSE_CB >= 1 & CLASSE_CB <= 4, CLASSE_CB, NA_real_),
    ano_num        = as.numeric(.ano) - 2022
  ) %>%
  select(-C1, -.ano)

df_full <- pool %>%
  select(G1_AGREG, all_of(vars_art), all_of(vars_extra),
         all_of(vars_i1a), ano_num) %>%
  drop_na() %>%
  mutate(across(all_of(vars_categoricas), ~ factor(as.integer(.x))))

df_sem_i1a <- df_full %>% select(-all_of(vars_i1a))

cat(sprintf("  N comum (vars + I1A, sem NA): %d\n", nrow(df_full)))
cat(sprintf("  Proporção e-gov: %.4f\n", mean(df_full$G1_AGREG == "Sim")))

set.seed(42)
folds <- createFolds(df_full$G1_AGREG, k = 5, returnTrain = TRUE)
ctrl <- trainControl(method = "cv", number = 5, index = folds,
                     classProbs = TRUE, summaryFunction = twoClassSummary,
                     savePredictions = "final", allowParallel = TRUE)

cat("\n[3/4] Treinando GLM e RF com/sem I1A_*\n")
registerDoParallel(cores = max(1, parallel::detectCores() - 1))
on.exit(stopImplicitCluster(), add = TRUE)

treinar_glm <- function(df, rot) {
  cat(sprintf("  GLM %-20s (N=%d, p=%d) ... ", rot, nrow(df), ncol(df) - 1))
  t1 <- Sys.time()
  m <- train(G1_AGREG ~ ., data = df, method = "glm", family = "binomial",
             trControl = ctrl, metric = "ROC")
  cat(format(Sys.time() - t1), "\n"); m
}

treinar_rf <- function(df, rot) {
  cat(sprintf("  RF  %-20s (N=%d, p=%d) ... ", rot, nrow(df), ncol(df) - 1))
  t1 <- Sys.time()
  p <- ncol(model.matrix(G1_AGREG ~ ., data = df)) - 1
  grid <- expand.grid(mtry = unique(round(c(sqrt(p), p/3, p/2))),
                      splitrule = "gini", min.node.size = 5)
  m <- train(G1_AGREG ~ ., data = df, method = "ranger",
             trControl = ctrl, metric = "ROC", tuneGrid = grid,
             importance = "impurity", num.trees = 300, num.threads = 1)
  cat(format(Sys.time() - t1), "\n"); m
}

modelos <- list()
modelos$glm_sem_i1a <- treinar_glm(df_sem_i1a, "sem I1A_*")
modelos$glm_com_i1a <- treinar_glm(df_full,    "com I1A_*")
modelos$rf_sem_i1a  <- treinar_rf(df_sem_i1a,  "sem I1A_*")
modelos$rf_com_i1a  <- treinar_rf(df_full,     "com I1A_*")

cat("\n[4/4] Resumo\n")
pegar_oof <- function(m, label) {
  p <- m$pred
  if (!is.null(m$bestTune)) {
    for (col in intersect(names(m$bestTune), names(p)))
      p <- p[p[[col]] == m$bestTune[[col]], ]
  }
  cm  <- caret::confusionMatrix(p$pred, p$obs, positive = "Sim")
  r   <- roc(p$obs, p$Sim, levels = c("Nao","Sim"), direction = "<", quiet = TRUE)
  tibble(modelo = label, N = nrow(p),
         AUC = as.numeric(auc(r)),
         Sens = as.numeric(cm$byClass["Sensitivity"]),
         Spec = as.numeric(cm$byClass["Specificity"]),
         Prec = as.numeric(cm$byClass["Pos Pred Value"]),
         F1   = as.numeric(cm$byClass["F1"]))
}

resumo <- bind_rows(
  pegar_oof(modelos$glm_sem_i1a, "GLM sem I1A_*"),
  pegar_oof(modelos$glm_com_i1a, "GLM com I1A_*"),
  pegar_oof(modelos$rf_sem_i1a,  "RF sem I1A_*"),
  pegar_oof(modelos$rf_com_i1a,  "RF com I1A_*")
) %>% mutate(across(c(AUC, Sens, Spec, Prec, F1), ~ round(.x, 4)))

print(resumo)

auc <- setNames(resumo$AUC, resumo$modelo)
cat(sprintf("\nΔAUC (GLM com vs sem I1A_*): %+.4f\n",
            auc["GLM com I1A_*"] - auc["GLM sem I1A_*"]))
cat(sprintf("ΔAUC (RF  com vs sem I1A_*): %+.4f\n",
            auc["RF com I1A_*"] - auc["RF sem I1A_*"]))

saveRDS(list(
  modelos  = modelos,
  resumo   = resumo,
  df_full  = df_full,
  vars_art = vars_art,
  vars_extra = vars_extra,
  vars_i1a = vars_i1a,
  meta = list(timestamp = Sys.time(), N = nrow(df_full), anos = anos,
              classe_positiva = "Sim")
), "dados/i1a_results.rds")

cat(sprintf("\n[OK] dados/i1a_results.rds | Tempo: %s\n",
            format(Sys.time() - t0)))
