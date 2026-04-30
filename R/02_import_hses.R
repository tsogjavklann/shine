# =============================================================================
# 02_import_hses.R
# -----------------------------------------------------------------------------
# Зорилго : 5 wave (2020-2024) × 3 файл (basicvars, 01_hhold, 02_indiv) = 15
#           .dta файлыг haven-оор уншиж raw_list-д хадгалах.
#           Ингэснээр R/03_harmonize.R-д ашиглах variable inventory-г үүсгэнэ.
# Орц     : data/hses_2020/ ... data/hses_2024/ (read-only)
# Гарц    : data/raw/hses_raw.rds                  — бүх 15 файлын list
#           output/logs/02_variable_inventory.csv  — багана бүрийн жагсаалт
#           output/logs/02_key_var_presence.csv    — гол хувьсагчдын хүснэгт
#           output/logs/02_import.log              — нэгтгэсэн лог
# =============================================================================

source(here::here("R", "paths.R"))
suppressPackageStartupMessages({
  library(haven)
  library(dplyr)
  library(tibble)
  library(purrr)
  library(readr)
  library(stringr)
  library(cli)
  library(tictoc)
})

cli::cli_h1("02_import_hses.R")
tic("Total")

# ---- 1. Wave-аар .dta файлуудыг хайх ---------------------------------------
WAVES <- 2020:2024
FILE_TYPES <- c(
  basicvars = "^basicvars",
  hhold     = "^01_hhold",
  indiv     = "^02_indiv"
)

find_dta <- function(wave, type_pattern) {
  dir <- file.path(PATHS$data_root, paste0("hses_", wave))
  files <- list.files(dir, pattern = "\\.dta$", full.names = TRUE)
  hits  <- files[stringr::str_detect(basename(files), type_pattern)]
  if (length(hits) == 0) return(NA_character_)
  if (length(hits) > 1) {
    # Хамгийн сүүлд өөрчлөгдсөнийг авна (хамгийн шинэ хувилбар)
    info <- file.info(hits)
    hits <- hits[order(info$mtime, decreasing = TRUE)][1]
  }
  hits
}

file_index <- expand.grid(wave = WAVES, type = names(FILE_TYPES),
                          stringsAsFactors = FALSE) |>
  as_tibble() |>
  mutate(
    pattern = FILE_TYPES[type],
    path    = purrr::map2_chr(wave, pattern, find_dta)
  )

missing_files <- file_index |> filter(is.na(path))
if (nrow(missing_files) > 0) {
  cli::cli_alert_warning("Дараах файлууд олдсонгүй:")
  print(missing_files)
}

cli::cli_alert_info("Олдсон файл: {sum(!is.na(file_index$path))} / 15")

# ---- 2. Бүх файлыг унших -----------------------------------------------------
read_one <- function(path, wave, type) {
  if (is.na(path)) return(NULL)
  cli::cli_alert("[{wave}/{type}] унш: {basename(path)}")
  tryCatch(
    haven::read_dta(path, encoding = "UTF-8"),
    error = function(e) {
      cli::cli_alert_warning("  алдаа: {conditionMessage(e)}")
      tryCatch(haven::read_dta(path),
               error = function(e2) {
                 cli::cli_alert_danger("  үл уншигдав: {conditionMessage(e2)}")
                 NULL
               })
    }
  )
}

raw_list <- file_index |>
  mutate(data = purrr::pmap(list(path, wave, type), read_one))

# ---- 3. Variable inventory үүсгэх -------------------------------------------
extract_var_info <- function(df, wave, type) {
  if (is.null(df)) return(NULL)
  tibble(
    wave = wave,
    file_type = type,
    var_name  = names(df),
    var_label = vapply(df, function(x) {
      lab <- attr(x, "label")
      if (is.null(lab) || !nzchar(lab)) NA_character_ else as.character(lab)
    }, character(1)),
    var_class = vapply(df, function(x) class(x)[1], character(1))
  )
}

inventory <- raw_list |>
  pmap_dfr(function(wave, type, pattern, path, data) {
    extract_var_info(data, wave, type)
  })

cli::cli_alert_info("Inventory: {nrow(inventory)} variable-rows from {dplyr::n_distinct(inventory$wave)} waves × {dplyr::n_distinct(inventory$file_type)} files")

write_csv(inventory, file.path(PATHS$out_logs, "02_variable_inventory.csv"))

# ---- 4. Key variable presence matrix ----------------------------------------
# Wage construction & threshold-д хэрэгтэй цөм хувьсагчдын check
# (HSES Mongolian survey-ийн стандарт нэрс)
KEY_VARS <- c(
  # Wage Tier 1 (2020+)
  "q0436a", "q0436b",
  "q0437", "q0438", "q0439",
  # Wage Tier 2 (2020+)
  "q0427",
  # Wage Tier 3 (2016/2018)
  "q0414",
  # Birth aimag (home_aimag)
  "q0118a",
  # Education
  "q0306", "q0307", "q0308",   # education-related codes (HSES общая структура)
  # Demographic
  "q0102",  # sex code
  "q0103",  # birth year/month/age
  "q0104",  # marital
  "q0202",  # urban/rural
  # Geographic — basicvars-д
  "newaimag", "aimag", "newsoum",
  # Survey month-ийг basicvars-аас авна
  "intmonth", "intyear", "yymm"
)

presence <- inventory |>
  filter(var_name %in% KEY_VARS) |>
  group_by(wave, file_type, var_name) |>
  summarise(present = TRUE, label = first(var_label), .groups = "drop") |>
  tidyr::pivot_wider(
    names_from  = c(wave, file_type),
    values_from = present,
    names_glue  = "w{wave}_{file_type}",
    values_fill = FALSE
  ) |>
  arrange(var_name)

# Хэрэв пристутут байхгүй бол FALSE-ээр дүүргэх
all_keys <- tibble(var_name = KEY_VARS)
presence <- all_keys |>
  left_join(presence, by = "var_name")

write_csv(presence, file.path(PATHS$out_logs, "02_key_var_presence.csv"))

cli::cli_h2("Key variable presence (T = байгаа):")
print(presence, n = Inf)

# ---- 5. Raw_list-ийг хадгалах -----------------------------------------------
out_data <- file.path(PATHS$data_raw, "hses_raw.rds")
saveRDS(raw_list, out_data)

# Файлын хэмжээ check
n_total_rows <- raw_list |>
  pmap_int(function(wave, type, pattern, path, data) {
    if (is.null(data)) 0L else nrow(data)
  }) |>
  sum()

cli::cli_alert_success("Raw data saved: {out_data}")
cli::cli_alert_info("Нийт мөр: {n_total_rows}")

# ---- 6. Лог -----------------------------------------------------------------
log_path <- file.path(PATHS$out_logs, "02_import.log")
sink(log_path, append = FALSE)
cat("==========================================================\n")
cat("02_import_hses.R лог  ", as.character(Sys.time()), "\n")
cat("==========================================================\n")
cat(sprintf("Файл олдсон: %d / 15\n", sum(!is.na(file_index$path))))
cat(sprintf("Нийт мөр (бүх 15 файл): %d\n", n_total_rows))
cat("\n--- Wave × file × n_rows ---\n")
size_tbl <- raw_list |>
  pmap_dfr(function(wave, type, pattern, path, data) {
    tibble(
      wave   = wave,
      type   = type,
      file   = if (is.na(path)) NA else basename(path),
      n_rows = if (is.null(data)) 0L else nrow(data),
      n_cols = if (is.null(data)) 0L else ncol(data)
    )
  })
print(size_tbl, n = Inf)

cat("\n--- Key variable presence (T/F) ---\n")
print(presence, n = Inf)
sink()

toc()
cli::cli_alert_success("Гарц: {out_data}, {file.path(PATHS$out_logs, '02_variable_inventory.csv')}, {file.path(PATHS$out_logs, '02_key_var_presence.csv')}")
cli::cli_alert_info("Дараагийн алхам: R/03_harmonize.R")
