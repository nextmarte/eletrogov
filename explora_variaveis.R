#!/usr/bin/env Rscript
# explora_variaveis.R — screening de variáveis candidatas na TIC 2025
# Objetivo: ranquear candidatas por poder preditivo marginal sobre o modelo base
# do artigo (idade, pea, h2, renda_familiar, classe_cb, grau_instrucao, c5_dispositivos).
#
# Saídas:
#   - dados/screening_vars.rds   (tibble com resultados)
#   - screening_vars.log         (stdout)
#
# Uso: Rscript explora_variaveis.R

suppressPackageStartupMessages({
  library(tidyverse)
  library(haven)
  library(pROC)
})

set.seed(42)
t0 <- Sys.time()

# --- 1. Carrega 2025 ---
cat("[1/4] Carregando TIC 2025\n")
d <- read_sav("dados/tic_ind_2025.sav")
cat("  Linhas:", nrow(d), "| Colunas:", ncol(d), "\n")

# --- 2. Base harmonizada (igual ao qmd, subset de colunas) ---
encontrar <- function(padroes) {
  for (p in padroes) {
    idx <- grep(p, names(d), ignore.case = TRUE, value = TRUE)
    if (length(idx) > 0) return(idx[1])
  }
  NA_character_
}

base_cols <- list(
  g1_agreg        = "G1_AGREG",  # pode não existir, vamos checar
  c1              = "C1",
  idade           = "IDADE",
  pea             = encontrar(c("^PEA_?2$", "^PEA$")),
  h2              = "H2",
  renda_familiar  = encontrar(c("^RENDA_FAMILIAR$", "RENDA.*FAMILIAR")),
  classe_cb       = encontrar(c("^CLASSE_CB.*$", "^CLASSE_2015$", "CLASSE.*CB", "^CLASSE")),
  grau_instrucao  = encontrar(c("^GRAU_INST.*$", "GRAU.*INSTRUCAO")),
  c5_dispositivos = encontrar(c("^C5_DISPOSITIVOS$", "^C5_DISP")),
  area            = "AREA",
  cod_regiao      = encontrar(c("^COD.*REGIAO.*2$", "^COD.*REGIAO")),
  raca            = "RACA",
  sexo            = "SEXO"
)

# Construir G1_AGREG se não existir (G1_A..G1_H = uso de e-gov)
if (!"G1_AGREG" %in% names(d)) {
  g1_cols <- grep("^G1_[A-H]$", names(d), value = TRUE)
  cat("  G1_AGREG ausente — agregando de:", paste(g1_cols, collapse=","), "\n")
  d$G1_AGREG <- as.integer(rowSums(sapply(d[g1_cols], function(x) as.numeric(x) == 1), na.rm = TRUE) > 0)
}

cat("  Colunas base encontradas:\n")
for (n in names(base_cols)) cat(sprintf("    %-18s -> %s\n", n, base_cols[[n]]))

# --- 3. Prepara base (mesmos filtros do artigo) ---
limpar <- function(df) {
  # Colunas numéricas-codificadas (existência depende do ano)
  miss_cols  <- intersect(c("h2", "renda_familiar", "classe_cb",
                            "grau_instrucao", "c5_dispositivos"), names(df))
  out <- df %>%
    mutate(across(where(is.labelled), as.numeric)) %>%
    filter(c1 == 1, idade >= 16) %>%
    mutate(across(all_of(miss_cols),
                  ~ if_else(.x %in% c(97, 98, 99), NA_real_, .x)))

  if ("sexo" %in% names(out))
    out <- out %>% mutate(sexo = if_else(sexo == 2, 1, 0))
  if ("area" %in% names(out))
    out <- out %>% mutate(area = if_else(area == 1, 1, 0))
  if ("g1_agreg" %in% names(out))
    out <- out %>% mutate(g1_agreg = if_else(g1_agreg == 1, 1, 0))
  if ("renda_familiar" %in% names(out))
    out <- out %>% mutate(renda_familiar = if_else(renda_familiar == 9, 0, renda_familiar))
  if ("classe_cb" %in% names(out))
    out <- out %>% mutate(classe_cb = if_else(classe_cb >= 1 & classe_cb <= 4, classe_cb, NA_real_))
  if ("raca" %in% names(out))
    out <- out %>% mutate(raca = if_else(raca %in% c(97, 98, 99), NA_real_, raca))
  out
}

# Seleciona e renomeia (preserva .row_id pra juntar candidatas depois)
d2 <- d
names(d2) <- toupper(names(d2))
d2$.row_id <- seq_len(nrow(d2))

sel_cols <- base_cols[!is.na(base_cols)]
cols_ok <- intersect(unlist(sel_cols), names(d2))
df_base <- d2[, c(".row_id", cols_ok)]
nomes_novos <- names(sel_cols)[match(cols_ok, unlist(sel_cols))]
names(df_base) <- c(".row_id", nomes_novos)
df_base <- limpar(df_base)

cat("  Após filtros (C1=1, idade>=16): N =", nrow(df_base), "\n")

# --- 4. Variáveis originais (artigo) ---
vars_art <- c("idade", "pea", "h2", "renda_familiar", "classe_cb",
              "grau_instrucao", "c5_dispositivos")

dados_base <- df_base %>%
  select(g1_agreg, all_of(vars_art)) %>%
  drop_na()

cat("  N completo (vars originais): ", nrow(dados_base), "\n")

# Modelo base
cat("\n[2/4] Ajustando modelo base (vars do artigo)\n")
form_base <- as.formula(paste("g1_agreg ~", paste(vars_art, collapse = " + ")))
m_base <- glm(form_base, data = dados_base, family = binomial)
auc_base <- as.numeric(auc(roc(dados_base$g1_agreg, predict(m_base, type = "response"), quiet = TRUE)))
cat(sprintf("  AUC base (N=%d): %.4f\n", nrow(dados_base), auc_base))

# --- 5. Candidatas ---
cat("\n[3/4] Screening de candidatas\n")

candidatas <- list(
  FAIXA_ETARIA     = "FAIXA_ETARIA",
  APOSENT          = "APOSENT",
  ESTUD            = "ESTUD",
  RENDA_PESSOAL    = "RENDA_PESSOAL",
  RELIGIAO         = "RELIGIAO",
  B1               = "B1",
  B2               = "B2",
  J5               = "J5",    # tem celular
  J6               = "J6",
  J7               = "J7",
  sexo             = "SEXO",
  area             = "AREA",
  raca             = "RACA",
  cod_regiao       = base_cols$cod_regiao,
  # Habilidades digitais (binárias 0/1)
  I1A_A = "I1A_A", I1A_B = "I1A_B", I1A_C = "I1A_C", I1A_D = "I1A_D",
  I1A_E = "I1A_E", I1A_F = "I1A_F", I1A_G = "I1A_G", I1A_H = "I1A_H",
  # Atividades online
  C14_A = "C14_A", C14_B = "C14_B", C14_C = "C14_C", C14_D = "C14_D",
  C11_A = "C11_A", C11_B = "C11_B", C11_C = "C11_C",
  # Uso de IA
  C13A = "C13A"
)

# Recoding auxiliar — codifica missings/refs, mantém binárias 0/1
recode_candidata <- function(v) {
  v <- as.numeric(v)
  v[v %in% c(97, 98, 99)] <- NA
  v
}

# Classificar variáveis nominais com >2 niveis como fator (raca, cod_regiao, religião, faixa_etária)
nominais_multi <- c("raca", "cod_regiao", "RELIGIAO", "FAIXA_ETARIA",
                    "RENDA_PESSOAL")

resultados <- list()

for (nome_cand in names(candidatas)) {
  col <- candidatas[[nome_cand]]
  if (is.na(col) || !(col %in% names(d2))) {
    cat(sprintf("  [skip] %s  (coluna %s não existe)\n", nome_cand, col))
    next
  }
  vals <- recode_candidata(d2[[col]])

  df_cand <- df_base %>%
    mutate(.cand = vals[.row_id]) %>%
    select(g1_agreg, all_of(vars_art), .cand) %>%
    drop_na()

  if (nrow(df_cand) < 200) {
    cat(sprintf("  [skip] %-15s  N=%d (muito pequeno)\n", nome_cand, nrow(df_cand)))
    next
  }

  # Decide se fator
  n_unicos <- length(unique(df_cand$.cand))
  if (nome_cand %in% nominais_multi || n_unicos > 5) {
    df_cand$.cand <- factor(df_cand$.cand)
  }

  # Modelos base vs base+cand no MESMO N
  m_b <- glm(form_base, data = df_cand, family = binomial)
  m_c <- glm(update(form_base, . ~ . + .cand), data = df_cand, family = binomial)

  auc_b <- as.numeric(auc(roc(df_cand$g1_agreg, predict(m_b, type = "response"), quiet = TRUE)))
  auc_c <- as.numeric(auc(roc(df_cand$g1_agreg, predict(m_c, type = "response"), quiet = TRUE)))

  # LR test
  lr  <- anova(m_b, m_c, test = "LRT")
  pval <- lr$`Pr(>Chi)`[2]
  df_diff <- lr$Df[2]

  resultados[[nome_cand]] <- tibble(
    variavel = nome_cand,
    col_sav  = col,
    N        = nrow(df_cand),
    tipo     = if (is.factor(df_cand$.cand)) "factor" else "num",
    n_niveis = n_unicos,
    auc_base = round(auc_b, 4),
    auc_com  = round(auc_c, 4),
    delta_auc= round(auc_c - auc_b, 4),
    lr_chi2  = round(lr$Deviance[2], 2),
    lr_df    = df_diff,
    p_valor  = pval
  )

  cat(sprintf("  %-16s N=%-6d AUC: %.4f -> %.4f (Δ=%+.4f)  p=%.2e\n",
              nome_cand, nrow(df_cand), auc_b, auc_c, auc_c - auc_b, pval))
}

resultados <- bind_rows(resultados) %>%
  arrange(desc(delta_auc))

# --- 6. Salvar e reportar ---
cat("\n[4/4] Resultados\n\n")
print(resultados, n = Inf)

saveRDS(resultados, "dados/screening_vars.rds")
cat(sprintf("\nGravado: dados/screening_vars.rds | Tempo: %s\n", format(Sys.time() - t0)))

# Top 5
cat("\n=== TOP 5 por ΔAUC ===\n")
print(head(resultados, 5))
