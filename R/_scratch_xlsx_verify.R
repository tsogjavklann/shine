suppressPackageStartupMessages({library(readxl); library(dplyr); library(here); library(readr); library(stringr)})
options(width = 130)

xlsx <- list.files(here("data"), pattern = "\\.xlsx$", full.names = TRUE)
local <- read_csv(here("data/auxiliary/livestock_loss_aimag_136.csv"), show_col_types = FALSE)
lookup <- read_csv(here("data/auxiliary/aimag_lookup.csv"), show_col_types = FALSE)

cat("==============================================================\n")
cat("FILE 5: aimag-level dzud loss (xlsx) vs CSV-аар татсан 136V1\n")
cat("==============================================================\n\n")

f5 <- xlsx[grepl("аймаг, нийслэл, жилээр\\.xlsx$", xlsx) & grepl("ХОРОГДОЛ", xlsx)]
cat("Файл:", basename(f5), "\n")
d5 <- read_excel(f5, sheet = 1, .name_repair = "minimal", col_types = "text")
cat(sprintf("Хэмжээ: %d мөр × %d багана\n", nrow(d5), ncol(d5)))

# Header row 2 has years
yr_row <- as.character(d5[2, ])
cat("Жилийн багана (2-р мөр):\n")
print(yr_row[1:15])
cat("...\n")
print(yr_row[(length(yr_row)-5):length(yr_row)])

# Find Архангай row 2024 col
arkh_row <- which(grepl("Архангай", as.character(d5[[2]])))
cat(sprintf("\nАрхангай мөр index in xlsx: %s\n", paste(arkh_row, collapse = ",")))

# Compare specific values: Архангай 2024 in xlsx vs CSV
csv_arkh_2024 <- local |> filter(hses_code == 65, year == 2024) |> pull(loss)
cat(sprintf("CSV (DT_NSO_1001_136V1): Архангай 2024 loss = %s (мянган толгой)\n", csv_arkh_2024))

if (length(arkh_row) > 0) {
  yr_2024_col <- which(yr_row == "2024")
  cat(sprintf("XLSX file: Архангай 2024 loss = %s\n", as.character(d5[arkh_row[1], yr_2024_col[1]])))
}

# Завхан 2010 verify (zууны зуд)
cat("\n--- Завхан 2010 (зууны зуд) ---\n")
zav_row <- which(grepl("Завхан", as.character(d5[[2]])))
yr_2010_col <- which(yr_row == "2010")
csv_zav_2010 <- local |> filter(hses_code == 81, year == 2010) |> pull(loss)
cat(sprintf("CSV: %s\n", csv_zav_2010))
if (length(zav_row) > 0 & length(yr_2010_col) > 0)
  cat(sprintf("XLSX: %s\n", as.character(d5[zav_row[1], yr_2010_col[1]])))

cat("\n==============================================================\n")
cat("FILE 3: livestock count (баг/хороо) — has aimag-level rows нь\n")
cat("==============================================================\n\n")
f3 <- xlsx[grepl("МАЛЫН ТОО", xlsx) & grepl("баг", xlsx)]
cat("Файл:", basename(f3), "\n")
d3 <- read_excel(f3, sheet = 1, .name_repair = "minimal", col_types = "text")
cat(sprintf("Хэмжээ: %d мөр × %d багана\n", nrow(d3), ncol(d3)))

# Show rows with 3-digit codes
codes_col <- as.character(d3[[3]])
nrows_show <- which(nchar(codes_col) %in% c(1, 2, 3) & codes_col != "" & !is.na(codes_col))
cat("\nАймаг-түвшний мөр (1-3 оронтой код):\n")
print(d3[nrows_show[1:30], 1:5])

cat("\n==============================================================\n")
cat("FILE 4: dzud loss (баг/хороо) — буруу хувилбар\n")
cat("==============================================================\n\n")
f4 <- xlsx[grepl("ХОРОГДОЛ", xlsx) & grepl("баг", xlsx)]
cat("Файл:", basename(f4), "\n")
d4 <- read_excel(f4, sheet = 1, .name_repair = "minimal", col_types = "text")
cat(sprintf("Хэмжээ: %d мөр × %d багана\n", nrow(d4), ncol(d4)))

# Compare 1999-2002 famous dzud Архангай
cat("\nАрхангай 1999-2002 in баг/хороо file (буруу) vs аймаг file (зөв):\n")
arkh3 <- which(grepl("Архангай", as.character(d4[[2]])))
yr_row4 <- as.character(d4[1, ])  # might be in row 1
yr_row4_alt <- as.character(d4[1, ])
cat("Header row 1 (sample):\n")
print(d4[1, 1:8])

cat("\n==============================================================\n")
cat("FILE 6: CPI verify\n")
cat("==============================================================\n\n")
f6 <- xlsx[grepl("ХЭРЭГЛЭЭНИЙ", xlsx)]
cat("Файл:", basename(f6), "\n")
d6 <- read_excel(f6, sheet = 1, .name_repair = "minimal", col_types = "text")
cat(sprintf("Хэмжээ: %d мөр × %d багана\n", nrow(d6), ncol(d6)))
cat("Эхний 8 мөр × 12 багана:\n")
print(d6[1:8, 1:12])

# Verify it's 2020-base
cat(sprintf("\nЦэлмэгийн ишлэгдсэн '2020=100' гэж буй мөр илэрсэн: %s\n",
            ifelse(any(grepl("2020=100", as.character(unlist(d6[1:5,]))), na.rm = TRUE), "ТИЙМ", "ҮГҮЙ")))


