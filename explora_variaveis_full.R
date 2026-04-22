#!/usr/bin/env Rscript
# explora_variaveis_full.R — screening de TODAS as candidatas que estão
# em todos os 10 anos (2015-2019, 2021-2025), DEPOIS de harmonizar as
# variáveis do modelo base do artigo (que mudam de nome entre anos).
#
# Saída: dados/screening_full.rds

suppressPackageStartupMessages({
  library(tidyverse)
  library(haven)
  library(pROC)
})

set.seed(42)
t0 <- Sys.time()

anos_enc <- tribble(
  ~ano, ~encoding,
  2015, "UTF-8",
  2016, "latin1",
  2017, "latin1",
  2018, "UTF-8",
  2019, "latin1",
  2021, "UTF-8",
  2022, "UTF-8",
  2023, "UTF-8",
  2024, "UTF-8",
  2025, "UTF-8"
)
anos <- anos_enc$ano

ler_sav <- function(a, n_max = Inf) {
  enc <- anos_enc$encoding[anos_enc$ano == a]
  read_sav(sprintf("dados/tic_ind_%d.sav", a), encoding = enc, n_max = n_max)
}

# Harmonizar nomes de colunas variáveis-base entre anos
harmonizar_nomes <- function(d) {
  nm <- toupper(names(d))
  names(d) <- nm

  encontrar <- function(pads) {
    for (p in pads) {
      m <- grep(p, nm, value = TRUE)
      if (length(m)) return(m[1])
    }
    NA_character_
  }

  # Renames canônicos
  renames <- c(
    CLASSE_CB       = encontrar(c("^CLASSE_CB", "^CLASSE_2015$", "^CLASSE")),
    GRAU_INSTRUCAO  = encontrar(c("^GRAU_INST")),
    C5_DISPOSITIVOS = encontrar(c("^C5_DISPOSITIVOS$")),
    RENDA_FAMILIAR  = encontrar(c("^RENDA_FAMILIAR$", "^RENDA_FAMILIAR_2$", "^RENDA.*FAM")),
    PEA             = encontrar(c("^PEA_?2$", "^PEA$")),
    COD_REGIAO      = encontrar(c("^COD.*REGIAO"))
  )
  renames <- renames[!is.na(renames)]

  # Renomear: canonical <- original; mas precisa do sentido inverso
  for (canonical in names(renames)) {
    orig <- renames[[canonical]]
    if (orig != canonical && orig %in% names(d)) {
      names(d)[names(d) == orig] <- canonical
    }
  }
  d
}

# --- 1. Ler cabeçalho + harmonizar ---
cat("[1/6] Mapeando colunas após harmonização\n")
cols_por_ano <- map(anos, function(a) {
  d <- ler_sav(a, n_max = 1)
  d <- harmonizar_nomes(d)
  names(d)
})
names(cols_por_ano) <- anos

# Interseção 10 anos (candidatas longitudinalmente consistentes)
cols_universais <- reduce(cols_por_ano, intersect)
# Interseção 2021-2025 (define o que pode entrar no modelo base do pooled)
cols_pool_2125 <- reduce(cols_por_ano[as.character(2021:2025)], intersect)

cat(sprintf("  Universais 10 anos: %d\n", length(cols_universais)))
cat(sprintf("  Universais 2021-2025: %d\n", length(cols_pool_2125)))

# --- 2. Carregar tudo e juntar ---
# Para o df_base (2021-2025), precisamos das vars de cols_pool_2125.
# Para candidatas (universal), cols_universais.
# Juntamos: UNIÃO das duas, mas pra 2015-2019 só existirão as universais.
cat("\n[2/6] Carregando os 10 anos (pode demorar)\n")
cols_guardar <- union(cols_universais, cols_pool_2125)
dados <- map(anos, function(a) {
  cat(sprintf("  %d... ", a))
  d <- ler_sav(a)
  d <- harmonizar_nomes(d)
  d <- d[, intersect(cols_guardar, names(d))]
  d <- d %>% mutate(across(where(is.labelled), as.numeric))
  d$.ano <- a
  cat("OK\n")
  d
})

pool_full <- bind_rows(dados)
cat(sprintf("  Pool: %d linhas × %d cols\n", nrow(pool_full), ncol(pool_full)))

# --- 3. Construir G1_AGREG ---
if (!"G1_AGREG" %in% names(pool_full)) {
  g1_cols <- grep("^G1_[A-H]$", names(pool_full), value = TRUE)
  pool_full$G1_AGREG <- as.integer(rowSums(
    sapply(pool_full[g1_cols], function(x) as.numeric(x) == 1), na.rm = TRUE) > 0)
}

# --- 4. df_base 2021-2025 ---
cat("\n[3/6] Preparando df_base (2021-2025)\n")
pool_full$.row_id <- seq_len(nrow(pool_full))

base_cols <- c("G1_AGREG", "C1", "IDADE", "PEA", "H2", "RENDA_FAMILIAR",
               "CLASSE_CB", "GRAU_INSTRUCAO", "C5_DISPOSITIVOS")
base_cols <- intersect(base_cols, names(pool_full))

df_base <- pool_full %>%
  filter(.ano >= 2021) %>%
  select(.row_id, .ano, all_of(base_cols)) %>%
  rename(
    g1_agreg        = G1_AGREG,
    c1              = C1,
    idade           = IDADE,
    pea             = PEA,
    h2              = H2,
    renda_familiar  = RENDA_FAMILIAR,
    classe_cb       = CLASSE_CB,
    grau_instrucao  = GRAU_INSTRUCAO,
    c5_dispositivos = C5_DISPOSITIVOS
  ) %>%
  filter(c1 == 1, idade >= 16) %>%
  mutate(
    across(c(h2, renda_familiar, classe_cb, grau_instrucao, c5_dispositivos),
           ~ if_else(.x %in% c(97, 98, 99), NA_real_, .x)),
    g1_agreg = if_else(g1_agreg == 1, 1, 0),
    renda_familiar = if_else(renda_familiar == 9, 0, renda_familiar),
    classe_cb = if_else(classe_cb >= 1 & classe_cb <= 4, classe_cb, NA_real_)
  )

cat(sprintf("  df_base 2021-2025: N = %d\n", nrow(df_base)))

vars_art <- c("idade", "pea", "h2", "renda_familiar", "classe_cb",
              "grau_instrucao", "c5_dispositivos")
form_base <- as.formula(paste("g1_agreg ~", paste(vars_art, collapse = " + ")))

dados_base <- df_base %>% select(g1_agreg, all_of(vars_art)) %>% drop_na()
m_base <- glm(form_base, data = dados_base, family = binomial)
auc_base_ref <- as.numeric(auc(roc(dados_base$g1_agreg,
                                   predict(m_base, type = "response"), quiet = TRUE)))
cat(sprintf("  AUC base (pooled 2021-2025, N=%d): %.4f\n",
            nrow(dados_base), auc_base_ref))

# --- 5. Candidatas universais ---
cat("\n[4/6] Identificando candidatas\n")
excluir <- c(
  "QUEST", "ID_DOMICILIO", "ID_MORADOR", ".ROW_ID", ".ANO",
  base_cols,
  grep("^G[0-9]", cols_universais, value = TRUE),
  grep("_COB$|_COB_", cols_universais, value = TRUE),
  grep("^PESO|^WEIGHT|^FATOR", cols_universais, value = TRUE)
)
candidatas <- setdiff(cols_universais, excluir)
cat(sprintf("  Candidatas: %d\n", length(candidatas)))

# --- 6. Screening ---
cat("\n[5/6] Screening GLM base vs base+cand\n\n")
recode_na <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  x[x %in% c(97, 98, 99)] <- NA
  x
}

# Labels de 2025 (mais ricos)
labels_2025 <- map(dados[[length(dados)]], ~ attr(.x, "label") %||% "")

resultados <- vector("list", length(candidatas))
names(resultados) <- candidatas

for (i in seq_along(candidatas)) {
  col <- candidatas[i]
  if (i %% 25 == 0) cat(sprintf("    ... %d/%d\n", i, length(candidatas)))

  vals <- recode_na(pool_full[[col]])
  if (sum(!is.na(vals)) < 500) next
  n_unicos <- length(unique(vals[!is.na(vals)]))
  if (n_unicos < 2 || n_unicos > 20) next

  df_cand <- df_base %>%
    mutate(.cand = vals[.row_id]) %>%
    select(g1_agreg, all_of(vars_art), .cand) %>%
    drop_na()

  if (nrow(df_cand) < 500 || length(unique(df_cand$.cand)) < 2) next
  if (n_unicos > 2) df_cand$.cand <- factor(df_cand$.cand)

  m_b <- tryCatch(glm(form_base, data = df_cand, family = binomial), error = function(e) NULL)
  m_c <- tryCatch(glm(update(form_base, . ~ . + .cand), data = df_cand, family = binomial),
                  error = function(e) NULL)
  if (is.null(m_b) || is.null(m_c)) next

  auc_b <- tryCatch(as.numeric(auc(roc(df_cand$g1_agreg,
                                       predict(m_b, type = "response"), quiet = TRUE))),
                    error = function(e) NA)
  auc_c <- tryCatch(as.numeric(auc(roc(df_cand$g1_agreg,
                                       predict(m_c, type = "response"), quiet = TRUE))),
                    error = function(e) NA)
  if (is.na(auc_b) || is.na(auc_c)) next

  lr <- tryCatch(anova(m_b, m_c, test = "LRT"), error = function(e) NULL)
  if (is.null(lr)) next

  lab <- labels_2025[[col]]
  if (is.null(lab)) lab <- ""

  resultados[[col]] <- tibble(
    variavel   = col,
    label      = substr(as.character(lab), 1, 80),
    N          = nrow(df_cand),
    n_niveis   = n_unicos,
    tipo       = if (is.factor(df_cand$.cand)) "factor" else "num",
    auc_base   = auc_b,
    auc_com    = auc_c,
    delta_auc  = auc_c - auc_b,
    lr_chi2    = lr$Deviance[2],
    lr_df      = lr$Df[2],
    p_valor    = lr$`Pr(>Chi)`[2]
  )
}

resultados <- bind_rows(resultados) %>%
  arrange(desc(delta_auc)) %>%
  mutate(across(c(auc_base, auc_com, delta_auc), ~ round(.x, 4)),
         lr_chi2 = round(lr_chi2, 2))

cat(sprintf("  Testadas: %d / %d\n", nrow(resultados), length(candidatas)))

saveRDS(resultados, "dados/screening_full.rds")
cat(sprintf("  Gravado: dados/screening_full.rds | Tempo: %s\n",
            format(Sys.time() - t0)))

cat("\n[6/6] TOP 30 por ΔAUC\n\n")
resultados %>%
  head(30) %>%
  mutate(p_fmt = format.pval(p_valor, digits = 2)) %>%
  select(variavel, label, N, n_niveis, auc_com, delta_auc, p_fmt) %>%
  print(n = Inf)

cat("\n=== Distribuição ===\n")
cat("  p < 0.001:    ", sum(resultados$p_valor < 0.001), "\n")
cat("  ΔAUC > 0.01:  ", sum(resultados$delta_auc > 0.01), "\n")
cat("  ΔAUC > 0.005: ", sum(resultados$delta_auc > 0.005), "\n")
cat("  ΔAUC > 0.001: ", sum(resultados$delta_auc > 0.001), "\n")
