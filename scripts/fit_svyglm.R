#!/usr/bin/env Rscript
# fit_svyglm.R — Análise de sensibilidade com pesos amostrais (survey)
# Compara GLM não-ponderado (já no fit_ml.R) com svyglm ponderado pelo
# PESO da TIC Domicílios, pooled 2021-2025.
# Saída: dados/svyglm_results.rds.

suppressPackageStartupMessages({
  library(tidyverse)
  library(haven)
  library(survey)
  library(pROC)
})

# Dicionário canônico (vars_extra com nomes interpretáveis)
source("scripts/var_labels.R")

set.seed(42)
t0 <- Sys.time()

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

vars_art <- c("IDADE","PEA","H2","RENDA_FAMILIAR","CLASSE_CB",
              "GRAU_INSTRUCAO","C5_DISPOSITIVOS")
vars_categoricas <- c("RENDA_FAMILIAR","CLASSE_CB","GRAU_INSTRUCAO","C5_DISPOSITIVOS")

# vars_extra carregado de scripts/var_labels.R (nomes interpretáveis).
# vars_extra_codigos = códigos TIC originais (para selecionar dos SAVs).
vars_extra_codigos <- unname(vars_extra_rename)

cat("[1/3] Carregando 2021-2025\n")
dados <- map(anos, function(a) {
  cat("  ", a, "...", sep = "")
  d <- ler_sav(a) %>% harmonizar_nomes()
  d <- d %>% mutate(across(where(is.labelled), as.numeric))
  d$.ano <- a
  cat(" OK\n")
  d
})

vars_todas_codigos <- c("G1_AGREG","C1","PESO", vars_art, vars_extra_codigos)

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
vars_todas <- c("G1_AGREG","C1","PESO", vars_art, vars_extra)

cat("\n[2/3] Preparo + filtros\n")
recode_na <- function(x) { x <- as.numeric(x); x[x %in% c(97,98,99)] <- NA; x }

pool <- pool %>%
  mutate(across(all_of(c(vars_art, vars_extra)), recode_na)) %>%
  filter(C1 == 1, IDADE >= 16) %>%
  mutate(
    egov = as.integer(G1_AGREG == 1),
    RENDA_FAMILIAR = if_else(RENDA_FAMILIAR == 9, 0, RENDA_FAMILIAR),
    CLASSE_CB      = if_else(CLASSE_CB >= 1 & CLASSE_CB <= 4, CLASSE_CB, NA_real_),
    ano_num        = as.numeric(.ano) - 2021
  ) %>%
  select(-C1, -.ano, -G1_AGREG)

df <- pool %>%
  select(egov, PESO, all_of(vars_art), all_of(vars_extra), ano_num) %>%
  drop_na() %>%
  mutate(across(all_of(vars_categoricas), ~ factor(as.integer(.x))))

cat(sprintf("  N: %d | Peso soma: %.0f | Prop egov não-ponderada: %.4f\n",
            nrow(df), sum(df$PESO), mean(df$egov)))
cat(sprintf("  Prop egov ponderada:  %.4f\n",
            weighted.mean(df$egov, df$PESO)))

cat("\n[3/3] Ajustando GLM não-ponderado vs svyglm ponderado\n")
# Modelo original (vars do artigo)
fmla_orig <- egov ~ IDADE + PEA + H2 + RENDA_FAMILIAR + CLASSE_CB +
                    GRAU_INSTRUCAO + C5_DISPOSITIVOS + ano_num
# Modelo expandido (artigo + 16 extras)
fmla_exp  <- update(fmla_orig, paste("~ . +",
                                      paste(vars_extra, collapse = " + ")))

unw_orig <- glm(fmla_orig, data = df, family = binomial())
unw_exp  <- glm(fmla_exp,  data = df, family = binomial())

des <- svydesign(ids = ~1, weights = ~PESO, data = df)
sv_orig <- svyglm(fmla_orig, design = des, family = quasibinomial())
sv_exp  <- svyglm(fmla_exp,  design = des, family = quasibinomial())

resumir <- function(m, label, ponderado) {
  ty <- broom::tidy(m, conf.int = TRUE, exponentiate = FALSE)
  ty$modelo <- label
  ty$ponderado <- ponderado
  ty
}

coefs_todos <- bind_rows(
  resumir(unw_orig, "Original", FALSE),
  resumir(unw_exp,  "Expandido", FALSE),
  resumir(sv_orig,  "Original", TRUE),
  resumir(sv_exp,   "Expandido", TRUE)
)

# AUC (in-sample, só comparativo — não é CV)
pred <- function(m, d) predict(m, newdata = d, type = "response")

aucs <- tibble(
  modelo    = c("Original","Expandido","Original","Expandido"),
  ponderado = c(FALSE,FALSE,TRUE,TRUE),
  AUC = c(
    as.numeric(auc(roc(df$egov, pred(unw_orig, df), quiet=TRUE))),
    as.numeric(auc(roc(df$egov, pred(unw_exp,  df), quiet=TRUE))),
    as.numeric(auc(roc(df$egov, pred(sv_orig,  df), quiet=TRUE))),
    as.numeric(auc(roc(df$egov, pred(sv_exp,   df), quiet=TRUE)))
  )
) %>% mutate(AUC = round(AUC, 4))

cat("\nAUC in-sample (comparativo):\n"); print(aucs)

# Comparação dos coefs chave
cat("\n=== Comparação de coefs: Expandido (não ponderado vs ponderado) ===\n")
comp <- coefs_todos %>%
  filter(modelo == "Expandido", term != "(Intercept)") %>%
  select(term, ponderado, estimate, p.value) %>%
  pivot_wider(names_from = ponderado,
              values_from = c(estimate, p.value),
              names_prefix = "") %>%
  rename(est_unw = estimate_FALSE, p_unw = p.value_FALSE,
         est_pon = estimate_TRUE,  p_pon = p.value_TRUE) %>%
  mutate(delta = round(est_pon - est_unw, 3),
         est_unw = round(est_unw, 3), est_pon = round(est_pon, 3))
print(comp, n = 40)

saveRDS(list(
  modelos = list(unw_orig = unw_orig, unw_exp = unw_exp,
                 sv_orig  = sv_orig,  sv_exp  = sv_exp),
  coefs = coefs_todos,
  aucs  = aucs,
  meta  = list(timestamp = Sys.time(), N = nrow(df), anos = anos)
), "dados/svyglm_results.rds")

cat(sprintf("\n[OK] dados/svyglm_results.rds | Tempo: %s\n",
            format(Sys.time() - t0)))
