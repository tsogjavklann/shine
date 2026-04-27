suppressPackageStartupMessages({library(readxl); library(here)})
options(width = 130)
f <- file.path(here("data"), "ХЭРЭГЛЭЭНИЙ ҮНИЙН УЛСЫН СУУРЬ ИНДЕКС, бүлгээр, сараар.xlsx")
d <- read_excel(f, sheet = 1, .name_repair = "minimal", col_types = "text")
cat(sprintf("Dim: %d × %d\n\n", nrow(d), ncol(d)))

cat("Эхний 12 мөр × 6 багана:\n")
print(d[1:min(12, nrow(d)), 1:6])

cat("\nБагана 1-ийн бүх утга (32 мөр):\n")
for (i in seq_len(nrow(d))) cat(sprintf("[%2d] '%s' | '%s'\n", i,
  ifelse(is.na(d[[1]][i]), "<NA>", d[[1]][i]),
  ifelse(is.na(d[[2]][i]), "<NA>", d[[2]][i])))
