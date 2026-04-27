suppressPackageStartupMessages({library(readxl); library(here); library(dplyr); library(stringr)})
options(width = 130)

f <- file.path(here("data"), "МАЛЫН ТОО, малын төрөл, аймаг, нийслэл, жилээр.xlsx")
d <- read_excel(f, sheet = 1, .name_repair = "minimal", col_types = "text")

# Check Дорноговь rows
spec <- as.character(d[[1]])
bus  <- as.character(d[[2]])
for (i in seq_along(spec)) if (is.na(spec[i]) || spec[i] == "") spec[i] <- ifelse(i > 1, spec[i-1], NA_character_)

# Find rows with Дорноговь
dornogovi_idx <- which(grepl("Дорноговь", str_trim(bus)))
cat("Дорноговь rows in xlsx:\n")
for (i in dornogovi_idx) {
  cat(sprintf("  Row %d: spec='%s', bus='%s'\n", i, spec[i], str_trim(bus[i])))
}

# Show sample data values for Дорноговь Бүгд
yr_row <- as.character(d[2, ])
yr_1993_col <- which(yr_row == "1993")
yr_2010_col <- which(yr_row == "2010")
yr_2024_col <- which(yr_row == "2024")
cat("\nДорноговь values (1993, 2010, 2024):\n")
for (i in dornogovi_idx) {
  cat(sprintf("  Row %d (spec=%s): 1993=%s, 2010=%s, 2024=%s\n",
              i, spec[i],
              as.character(d[i, yr_1993_col]),
              as.character(d[i, yr_2010_col]),
              as.character(d[i, yr_2024_col])))
}

# All Бүгд rows (showing aimag names)
cat("\nAll species == 'Бүгд' rows (with aimag matches):\n")
bugd_idx <- which(spec == "Бүгд")
for (i in head(bugd_idx, 30)) {
  cat(sprintf("  Row %d: bus='%s'\n", i, str_trim(bus[i])))
}
