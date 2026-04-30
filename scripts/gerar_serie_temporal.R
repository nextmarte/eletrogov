#!/usr/bin/env Rscript
# Gera dados/serie_egov.rds com a proporção anual de uso de e-gov (2015-2025).
# Usado por artigo.qmd para a fig-evolucao. Roda em ~30s.

suppressPackageStartupMessages({
  library(tidyverse); library(haven)
})

anos <- c(2015:2019, 2021:2025)

ler_sav <- function(a) {
  enc <- if (a %in% c(2016, 2017, 2019)) "latin1" else "UTF-8"
  read_sav(sprintf("dados/tic_ind_%d.sav", a), encoding = enc)
}

harmonizar_nomes <- function(d) {
  names(d) <- toupper(names(d))
  d
}

calc_prop <- function(a) {
  d <- ler_sav(a) |> harmonizar_nomes()
  d <- d |> mutate(across(where(is.labelled), as.numeric))
  if (!"G1_AGREG" %in% names(d)) {
    g1_cols <- grep("^G1_[A-H]$", names(d), value = TRUE)
    d$G1_AGREG <- as.integer(rowSums(
      sapply(d[g1_cols], function(x) as.numeric(x) == 1), na.rm = TRUE) > 0)
  }
  if ("C1" %in% names(d) && "IDADE" %in% names(d)) {
    d <- d |> filter(C1 == 1, IDADE >= 16)
  }
  tibble(ano = a,
         prop = mean(d$G1_AGREG == 1, na.rm = TRUE),
         n = sum(!is.na(d$G1_AGREG)))
}

cat("Calculando proporção anual de uso de e-gov (2015-2025)...\n")
serie <- map_dfr(anos, function(a) {
  cat("  ", a, "...\n", sep = "")
  calc_prop(a)
})

saveRDS(serie, "dados/serie_egov.rds")
cat("\n[OK] Salvo em dados/serie_egov.rds\n")
print(serie)
