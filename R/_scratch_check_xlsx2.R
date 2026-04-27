suppressPackageStartupMessages({library(readxl); library(here); library(dplyr)})
options(width = 130)
fs <- list.files(here("data"), pattern = "\\.xlsx$", full.names = TRUE)
for (f in fs[5:6]) {
  cat("==============================================================\n", basename(f), "\n==============================================================\n")
  s <- excel_sheets(f)
  cat("Sheets:", paste(s, collapse = ", "), "\n")
  d <- read_excel(f, sheet = 1, .name_repair = "minimal", col_types = "text")
  cat(sprintf("Dim: %d x %d\n", nrow(d), ncol(d)))
  cat("First 10 rows × 10 cols:\n")
  print(d[1:min(10, nrow(d)), 1:min(10, ncol(d))])
  cat("\n")
}
