suppressPackageStartupMessages({library(readxl); library(dplyr); library(here); library(readr); library(stringr)})
options(width = 130)

cat("==============================================================\n")
cat("New file: МАЛЫН ТОО, аймаг, нийслэл vs API CSV\n")
cat("==============================================================\n\n")

f <- file.path(here("data"), "МАЛЫН ТОО, малын төрөл, аймаг, нийслэл, жилээр.xlsx")
cat("Файл:", basename(f), "\n")
cat("Хэмжээ:", round(file.size(f)/1024), "KB\n")
sheets <- excel_sheets(f)
cat("Sheet-ууд:", paste(sheets, collapse = ", "), "\n\n")

d <- read_excel(f, sheet = 1, .name_repair = "minimal", col_types = "text")
cat(sprintf("Dim: %d мөр × %d багана\n", nrow(d), ncol(d)))
cat("Эхний 8 мөр × 10 багана:\n")
print(d[1:8, 1:10])

# Find year row and aimag rows
yr_row <- as.character(d[2, ])
cat("\nЖилийн багана (header row 2):\n")
yrs <- yr_row[!is.na(yr_row) & yr_row != ""]
cat(sprintf("  Жил-ийн тоо: %d\n", length(yrs)))
cat(sprintf("  %s\n", paste(yrs, collapse = ", ")))

# Cross-check: Завхан 2010 livestock count
cat("\n--- ВАЛИДАЦИ: Завхан 2010 livestock тоо ---\n")
zav_row <- which(grepl("Завхан", as.character(d[[2]])))
yr_2010_col <- which(yr_row == "2010")
if (length(zav_row) & length(yr_2010_col)) {
  xlsx_val <- as.character(d[zav_row[1], yr_2010_col[1]])
  cat(sprintf("XLSX: Завхан 2010 livestock count = %s (мянган толгой)\n", xlsx_val))
}

# Compare to API-fetched dzud_panel.csv
local_panel <- read_csv(here("data/auxiliary/dzud_panel.csv"), show_col_types = FALSE)
api_val <- local_panel |> filter(hses_code == 81, year == 2010) |> pull(livestock)
cat(sprintf("API CSV (dzud_panel.csv): Завхан 2010 livestock = %s\n", api_val))

# Архангай 2020
cat("\n--- ВАЛИДАЦИ: Архангай 2020 livestock тоо ---\n")
arkh_row <- which(grepl("Архангай", as.character(d[[2]])))
yr_2020_col <- which(yr_row == "2020")
if (length(arkh_row) & length(yr_2020_col)) {
  xlsx_val2 <- as.character(d[arkh_row[1], yr_2020_col[1]])
  cat(sprintf("XLSX: Архангай 2020 livestock count = %s\n", xlsx_val2))
}
api_val2 <- local_panel |> filter(hses_code == 65, year == 2020) |> pull(livestock)
cat(sprintf("API CSV: Архангай 2020 livestock = %s\n", api_val2))


