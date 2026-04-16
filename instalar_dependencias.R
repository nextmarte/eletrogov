pkgs <- c(
  "tidyverse", "haven", "broom", "pROC", "nnet",
  "caret", "fastDummies", "plotly", "gganimate",
  "gifski", "scales"
)

faltantes <- pkgs[!sapply(pkgs, requireNamespace, quietly = TRUE)]

if (length(faltantes) > 0) {
  cat("Instalando:", paste(faltantes, collapse = ", "), "\n")
  install.packages(faltantes, repos = "https://cloud.r-project.org")
} else {
  cat("Todos os pacotes já estão instalados.\n")
}
