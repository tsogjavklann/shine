# =============================================================================
# R/02b_clean_nso_xlsx.R — NSO 1212.mn-аас гараар татсан xlsx-уудыг цэвэрлэх
#
# Оролт: data/*.xlsx (5 файл — гар татсан)
# Гарц : data/auxiliary/*.csv + *.rds (analysis-д шууд бэлэн)
#
# Pipeline:
#   1. ЕБС сургууль (DT_NSO_2001_002V1)         → school_count_by_aimag.csv
#   2. ЕБС сурагч  (DT_NSO_2001_004V1)          → student_count_by_aimag.csv
#   3. Малын тоо  (DT_NSO_1001_109V1 ≈ 008V1*) → livestock_count_by_aimag.csv
#   4. Хорогдол   (DT_NSO_1001_136V1)           → livestock_loss_by_aimag.csv
#   5. ХҮИ        (DT_NSO_0600_001V3)           → cpi_2020base_monthly.csv +
#                                                 cpi_annual_2020base.csv
#   6. DERIVED:                                 → school_density_by_aimag.csv
#   7. DERIVED:                                 → dzud_panel.csv
#
# *Тэмдэглэл: Малын тоо xlsx-н sheet нэр "DT_NSO_1001_008V1" гэсэн ч агуулга нь
#  яг 109V1-тэй ижил байгаа (Завхан 2010=1717.7 ✓).
# =============================================================================
suppressPackageStartupMessages({
  library(readxl); library(dplyr); library(tidyr); library(readr); library(stringr)
  library(here); library(tibble); library(cli)
})

setFixest_quiet <- function(...) invisible(NULL)
options(width = 130)

DATA_DIR  <- here("data")
AUX_DIR   <- here("data", "auxiliary")
LOOKUP    <- read_csv(file.path(AUX_DIR, "aimag_lookup.csv"), show_col_types = FALSE)

# Common: NSO Бүс label → HSES hses_code
match_aimag <- function(labels) {
  trimmed <- str_trim(labels)
  LOOKUP$hses_code[match(trimmed, LOOKUP$aimag_mn)]
}

# Generic wide → long for "Бүс × year" tables (file 1, 2)
read_aimag_year <- function(xlsx_path, value_name) {
  d <- suppressMessages(read_excel(xlsx_path, sheet = 1, .name_repair = "minimal", col_types = "text"))
  yr_row <- as.character(d[2, ])
  is_year <- grepl("^[0-9]{4}$", yr_row)
  year_cols <- which(is_year)
  years <- as.integer(yr_row[year_cols])

  # Row 3+ = data, col 1 = Бүс label
  body <- d[3:nrow(d), ]
  bus_label <- as.character(body[[1]])
  hses_code <- match_aimag(bus_label)
  keep <- !is.na(hses_code)
  body <- body[keep, ]
  hses_code <- hses_code[keep]
  bus_label <- bus_label[keep]

  # Build wide matrix then pivot
  mat <- as.data.frame(lapply(body[, year_cols, drop = FALSE], function(x) suppressWarnings(as.numeric(x))))
  names(mat) <- as.character(years)
  mat$hses_code <- hses_code
  mat$aimag_mn  <- str_trim(bus_label)

  out <- pivot_longer(mat, cols = -c(hses_code, aimag_mn),
                      names_to = "year", values_to = value_name) |>
    mutate(year = as.integer(year)) |>
    filter(!is.na(.data[[value_name]])) |>
    group_by(hses_code, year) |>
    summarise(aimag_mn = first(aimag_mn),
              !!value_name := first(.data[[value_name]]),
              .groups = "drop") |>
    arrange(hses_code, year)
  out
}

# Wide → long for "Малын төрөл × Бүс × year" tables (files 3, 4)
# species_keep: which species labels to keep (default = "Бүгд"; can be c("Бүгд","Адуу",...))
read_livestock_aimag_year <- function(xlsx_path, value_name,
                                      species_keep = "Бүгд") {
  d <- suppressMessages(read_excel(xlsx_path, sheet = 1, .name_repair = "minimal", col_types = "text"))
  yr_row <- as.character(d[2, ])
  is_year <- grepl("^[0-9]{4}$", yr_row)
  year_cols <- which(is_year)
  years <- as.integer(yr_row[year_cols])

  body <- d[3:nrow(d), ]
  spec  <- as.character(body[[1]])
  bus_label <- as.character(body[[2]])

  # Forward-fill species (NSO export leaves duplicate species blank)
  for (i in seq_along(spec)) if (is.na(spec[i]) || spec[i] == "") spec[i] <- spec[i-1]
  keep_spec <- spec %in% species_keep

  hses_code <- match_aimag(bus_label)
  keep <- keep_spec & !is.na(hses_code)
  body <- body[keep, ]
  hses_code <- hses_code[keep]
  bus_label <- bus_label[keep]
  spec <- spec[keep]

  mat <- as.data.frame(lapply(body[, year_cols, drop = FALSE], function(x) suppressWarnings(as.numeric(x))))
  names(mat) <- as.character(years)
  mat$hses_code <- hses_code
  mat$aimag_mn  <- str_trim(bus_label)
  mat$species   <- spec

  pivot_longer(mat, cols = -c(hses_code, aimag_mn, species),
               names_to = "year", values_to = value_name) |>
    mutate(year = as.integer(year)) |>
    filter(!is.na(.data[[value_name]])) |>
    group_by(species, hses_code, year) |>
    summarise(aimag_mn = first(aimag_mn),
              !!value_name := first(.data[[value_name]]),
              .groups = "drop") |>
    arrange(species, hses_code, year)
}

# CPI specific reader: "Суурь он × Бүлэг × Сар" — wide format
# Бид зөвхөн нэг мөртэй: 2020=100 + Ерөнхий индекс (row 3)
read_cpi_xlsx <- function(xlsx_path) {
  d <- suppressMessages(read_excel(xlsx_path, sheet = 1, .name_repair = "minimal", col_types = "text"))
  mo_row <- as.character(d[2, ])
  is_mo  <- grepl("^[0-9]{4}-[0-9]{2}$", mo_row)
  mo_cols <- which(is_mo)
  months  <- mo_row[mo_cols]

  data_row <- which(as.character(d[[1]]) == "2020=100" &
                    as.character(d[[2]]) == "Ерөнхий индекс")
  if (length(data_row) != 1L)
    stop(sprintf("CPI: '2020=100' + 'Ерөнхий индекс' row not found uniquely (found %d)",
                 length(data_row)))

  vals <- as.numeric(unlist(d[data_row, mo_cols], use.names = FALSE))
  tibble(year_month = months, cpi = vals) |>
    mutate(year  = as.integer(substr(year_month, 1, 4)),
           month = as.integer(substr(year_month, 6, 7))) |>
    arrange(year, month) |>
    filter(!is.na(cpi))
}

# -----------------------------------------------------------------------------
# 1. Schools
# -----------------------------------------------------------------------------
cli_h1("STEP 1: ЕБС сургуулийн тоо")
schools <- read_aimag_year(
  file.path(DATA_DIR, "ЕРӨНХИЙ БОЛОВСРОЛЫН СУРГУУЛИЙН ТОО, аймаг, нийслэл, жилээр.xlsx"),
  value_name = "schools"
)
cat(sprintf("Schools: %d мөр (22 аймаг × %d жил)\n",
            nrow(schools), length(unique(schools$year))))
cat(sprintf("Жилийн хүрээ: %d-%d\n", min(schools$year), max(schools$year)))
write_csv(schools, file.path(AUX_DIR, "school_count_by_aimag.csv"))
saveRDS(schools, file.path(AUX_DIR, "school_count_by_aimag.rds"))

# -----------------------------------------------------------------------------
# 2. Students
# -----------------------------------------------------------------------------
cli_h1("STEP 2: ЕБС суралцагчийн тоо")
students <- read_aimag_year(
  file.path(DATA_DIR, "ЕРӨНХИЙ БОЛОВСРОЛЫН СУРГУУЛЬД ӨДРӨӨР СУРАЛЦАГЧДЫН ТОО, аймаг, нийслэл, жилээр.xlsx"),
  value_name = "students"
)
cat(sprintf("Students: %d мөр (22 аймаг × %d жил)\n",
            nrow(students), length(unique(students$year))))
cat(sprintf("Жилийн хүрээ: %d-%d\n", min(students$year), max(students$year)))
write_csv(students, file.path(AUX_DIR, "student_count_by_aimag.csv"))
saveRDS(students, file.path(AUX_DIR, "student_count_by_aimag.rds"))

# -----------------------------------------------------------------------------
# 3. Livestock count (denominator for dzud loss_rate)
# -----------------------------------------------------------------------------
cli_h1("STEP 3: Малын тоо (Бүгд + бүх 5 төрөл)")
livestock_all <- read_livestock_aimag_year(
  file.path(DATA_DIR, "МАЛЫН ТОО, малын төрөл, аймаг, нийслэл, жилээр.xlsx"),
  value_name = "livestock",
  species_keep = c("Бүгд","Адуу","Үхэр","Тэмээ","Хонь","Ямаа")
)
cat(sprintf("Livestock all-species: %d мөр (6 species × 22 аймаг × ~%d жил)\n",
            nrow(livestock_all), length(unique(livestock_all$year))))
cat(sprintf("Жилийн хүрээ: %d-%d\n", min(livestock_all$year), max(livestock_all$year)))
write_csv(livestock_all, file.path(AUX_DIR, "livestock_count_by_aimag_species.csv"))
saveRDS(livestock_all, file.path(AUX_DIR, "livestock_count_by_aimag_species.rds"))

livestock <- livestock_all |> filter(species == "Бүгд") |> select(-species)
write_csv(livestock, file.path(AUX_DIR, "livestock_count_by_aimag.csv"))
saveRDS(livestock, file.path(AUX_DIR, "livestock_count_by_aimag.rds"))

# -----------------------------------------------------------------------------
# 4. Livestock loss (dzud numerator)
# -----------------------------------------------------------------------------
cli_h1("STEP 4: Том малын зүй бус хорогдол (Бүгд + бүх 5 төрөл)")
loss_all <- read_livestock_aimag_year(
  file.path(DATA_DIR, "ТОМ МАЛЫН ЗҮЙ БУС ХОРОГДОЛ, малын төрөл, аймаг, нийслэл, жилээр.xlsx"),
  value_name = "loss",
  species_keep = c("Бүгд","Адуу","Үхэр","Тэмээ","Хонь","Ямаа")
)
cat(sprintf("Loss all-species: %d мөр\n", nrow(loss_all)))
cat(sprintf("Жилийн хүрээ: %d-%d\n", min(loss_all$year), max(loss_all$year)))
write_csv(loss_all, file.path(AUX_DIR, "livestock_loss_by_aimag_species.csv"))
saveRDS(loss_all, file.path(AUX_DIR, "livestock_loss_by_aimag_species.rds"))

loss <- loss_all |> filter(species == "Бүгд") |> select(-species)
write_csv(loss, file.path(AUX_DIR, "livestock_loss_by_aimag.csv"))
saveRDS(loss, file.path(AUX_DIR, "livestock_loss_by_aimag.rds"))

# -----------------------------------------------------------------------------
# 5. CPI (Y хувьсагчийн deflator)
# -----------------------------------------------------------------------------
cli_h1("STEP 5: ХҮИ суурь индекс (2020=100)")
cpi_monthly <- read_cpi_xlsx(file.path(DATA_DIR, "ХЭРЭГЛЭЭНИЙ ҮНИЙН УЛСЫН СУУРЬ ИНДЕКС, бүлгээр, сараар.xlsx"))
cat(sprintf("CPI monthly: %d сар, хүрээ %s - %s\n",
            nrow(cpi_monthly),
            paste(min(cpi_monthly$year), formatC(min(cpi_monthly$month[cpi_monthly$year == min(cpi_monthly$year)]), width=2, flag="0"), sep="-"),
            paste(max(cpi_monthly$year), formatC(max(cpi_monthly$month[cpi_monthly$year == max(cpi_monthly$year)]), width=2, flag="0"), sep="-")))
write_csv(cpi_monthly, file.path(AUX_DIR, "cpi_monthly_2020base.csv"))
saveRDS(cpi_monthly, file.path(AUX_DIR, "cpi_monthly_2020base.rds"))

# Annual CPI = 12-month average (2020=100)
cpi_annual <- cpi_monthly |>
  group_by(year) |>
  summarise(cpi = mean(cpi, na.rm = TRUE), n_mo = n(), .groups = "drop") |>
  filter(n_mo >= 6) |>  # At least 6 months for stable annual estimate
  select(year, cpi)
cat(sprintf("CPI annual: %d жил (%d-%d)\n",
            nrow(cpi_annual), min(cpi_annual$year), max(cpi_annual$year)))
write_csv(cpi_annual, file.path(AUX_DIR, "cpi_annual_2020base.csv"))
saveRDS(cpi_annual, file.path(AUX_DIR, "cpi_annual_2020base.rds"))

# -----------------------------------------------------------------------------
# 6. DERIVED: school_density (q_school_access threshold variable бэлдэх)
# -----------------------------------------------------------------------------
cli_h1("STEP 6: school_density (DERIVED)")
school_density <- schools |>
  inner_join(students, by = c("hses_code", "aimag_mn", "year")) |>
  mutate(school_density = schools / students)  # schools per (1000) students; students unit = thousand
cat(sprintf("school_density: %d (aimag × year) cells\n", nrow(school_density)))
cat(sprintf("Statistics:\n"))
print(summary(school_density$school_density))
write_csv(school_density, file.path(AUX_DIR, "school_density_by_aimag.csv"))
saveRDS(school_density, file.path(AUX_DIR, "school_density_by_aimag.rds"))

# -----------------------------------------------------------------------------
# 7. DERIVED: dzud_panel (loss_rate + thresholds)
# -----------------------------------------------------------------------------
cli_h1("STEP 7: dzud_panel (DERIVED)")
dzud <- loss |>
  rename(loss_aimag = aimag_mn) |>
  inner_join(livestock |> select(-aimag_mn), by = c("hses_code", "year")) |>
  arrange(hses_code, year) |>
  group_by(hses_code) |>
  mutate(livestock_lag = lag(livestock),
         loss_rate = if_else(!is.na(livestock_lag) & livestock_lag > 0,
                             loss / livestock_lag, NA_real_)) |>
  ungroup()

cat(sprintf("dzud_panel: %d мөр\n", nrow(dzud)))
cat("loss_rate (% of livestock at start of year) statistics:\n")
print(summary(dzud$loss_rate))

dzud <- dzud |>
  mutate(dzud_5pct  = as.integer(loss_rate >= 0.05),
         dzud_10pct = as.integer(loss_rate >= 0.10),
         dzud_top10 = as.integer(loss_rate >= quantile(dzud$loss_rate, 0.90, na.rm = TRUE)))

cat(sprintf("\nDzud-аар бүртгэгдсэн (any aimag, any year):\n"))
cat(sprintf("  >=5%%  loss rate: %d aimag-years\n", sum(dzud$dzud_5pct, na.rm = TRUE)))
cat(sprintf("  >=10%% loss rate: %d aimag-years\n", sum(dzud$dzud_10pct, na.rm = TRUE)))
cat(sprintf("  Top 10%%        : %d aimag-years\n", sum(dzud$dzud_top10, na.rm = TRUE)))

cat("\nТоп жил (>=5% хорогдсон аймагийн тоо):\n")
print(dzud |>
        group_by(year) |>
        summarise(n_aimags_dzud5 = sum(dzud_5pct, na.rm = TRUE),
                  mean_loss_rate = mean(loss_rate, na.rm = TRUE),
                  .groups = "drop") |>
        arrange(desc(n_aimags_dzud5)) |>
        head(10))

write_csv(dzud, file.path(AUX_DIR, "dzud_panel.csv"))
saveRDS(dzud, file.path(AUX_DIR, "dzud_panel.rds"))

cli_h1("ЦЭВЭРЛЭЛТ ДУУСЛАА")
cat("\nГарц файлууд (data/auxiliary/):\n")
cat("  school_count_by_aimag.{csv,rds}\n")
cat("  student_count_by_aimag.{csv,rds}\n")
cat("  livestock_count_by_aimag.{csv,rds}\n")
cat("  livestock_loss_by_aimag.{csv,rds}\n")
cat("  cpi_monthly_2020base.{csv,rds}  (245 сар?)\n")
cat("  cpi_annual_2020base.{csv,rds}\n")
cat("  school_density_by_aimag.{csv,rds}\n")
cat("  dzud_panel.{csv,rds}\n")


