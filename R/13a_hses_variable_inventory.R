# HSES 2020-2024 full variable inventory and preview.

options(warn = 1)

required_pkgs <- c("haven", "dplyr", "tidyr", "stringr", "readr", "tibble", "purrr")
missing_pkgs <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_pkgs) > 0) stop("Missing packages: ", paste(missing_pkgs, collapse = ", "))

suppressPackageStartupMessages({
  library(haven)
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(readr)
  library(tibble)
  library(purrr)
})

dir.create("data/auxiliary", recursive = TRUE, showWarnings = FALSE)
dir.create("output/logs", recursive = TRUE, showWarnings = FALSE)
dir.create("output/tables", recursive = TRUE, showWarnings = FALSE)
dir.create("output/reports", recursive = TRUE, showWarnings = FALSE)

sink("output/logs/13a_hses_variable_inventory.log", split = TRUE)
on.exit(sink(), add = TRUE)

cat("13a_hses_variable_inventory.R\n")
cat("Started:", as.character(Sys.time()), "\n\n")

rough_translate_label <- function(x) {
  if (is.na(x) || !nzchar(x)) return(NA_character_)
  y <- x
  repl <- c(
    "нас" = "age", "хүйс" = "sex", "эрэгтэй" = "male", "эмэгтэй" = "female",
    "өрх" = "household", "өрхийн" = "household", "тэргүүлэгч" = "head",
    "ам бүл" = "household size", "гэрлэлт" = "marital", "боловсрол" = "education",
    "сургууль" = "school", "анги" = "grade", "ажил" = "work", "цалин" = "wage",
    "орлого" = "income", "аймаг" = "aimag", "сум" = "soum", "төрсөн" = "birth/born",
    "нутаг" = "place/area", "нүү" = "move/migrate", "шилж" = "move/migrate",
    "үндэс" = "ethnicity/nationality", "яс" = "ethnicity", "шашин" = "religion",
    "өвчин" = "illness", "хөгжлийн бэрхшээл" = "disability", "эрүүл" = "health",
    "дотуур байр" = "dormitory/boarding", "малчин" = "herder",
    "шалтгаан" = "reason", "тасал" = "interruption/absence"
  )
  for (k in names(repl)) y <- str_replace_all(y, fixed(k, ignore_case = TRUE), repl[[k]])
  y
}

category_from_text <- function(var_name, label) {
  txt <- str_to_lower(paste(var_name, label, sep = " "))
  case_when(
    str_detect(txt, "нас|хүйс|гэрл|marital|sex|age|q0103|q0105") ~ "demographics",
    str_detect(txt, "боловсрол|сургууль|анги|дээд|education|school|grade|q02") ~ "education",
    str_detect(txt, "ажил|цалин|мэргэжил|occupation|hour|wage|labor|q04") ~ "labor",
    str_detect(txt, "өрх|ам бүл|тэргүүлэгч|relation|household|head|q0102") ~ "household",
    str_detect(txt, "аймаг|сум|хот|хөдөө|байрш|urban|rural|aimag|soum|location") ~ "geography",
    str_detect(txt, "төрсөн|эцэг|эх|аав|ээж|parent|birth|childhood") ~ "childhood",
    str_detect(txt, "нүү|шилж|оршин суу|migration|moved|lived|resid") ~ "migration",
    str_detect(txt, "үндэс|яс|шашин|хэл|ethnic|nation|religion|language") ~ "ethnic_cultural",
    str_detect(txt, "өвчин|эрүүл|эмнэл|хөгжлийн бэрхшээл|health|illness|disab") ~ "health",
    str_detect(txt, "орлого|тэтгэвэр|тэтгэмж|шилжүүлэг|income|transfer|asset|мал") ~ "economic",
    str_detect(txt, "бүлэг|холбоо|нийгэм|network|membership|social") ~ "social",
    TRUE ~ "other"
  )
}

read_meta_file <- function(path) {
  wave <- as.integer(str_extract(path, "20[0-9]{2}"))
  source_type <- case_when(
    str_detect(basename(path), regex("02_indiv", ignore_case = TRUE)) ~ "indiv",
    str_detect(basename(path), regex("01_hhold", ignore_case = TRUE)) ~ "hhold",
    str_detect(basename(path), regex("basicvars", ignore_case = TRUE)) ~ "basicvars",
    TRUE ~ "other"
  )
  cat("Reading", wave, source_type, path, "\n")
  df <- haven::read_dta(path)
  map_dfr(names(df), function(v) {
    x <- df[[v]]
    lab <- attr(x, "label", exact = TRUE)
    type <- paste(class(x), collapse = "/")
    x_plain <- if (inherits(x, "haven_labelled")) haven::zap_labels(x) else x
    n_missing <- sum(is.na(x_plain))
    n_unique <- dplyr::n_distinct(x_plain, na.rm = TRUE)
    tibble(
      wave = wave,
      source_type = source_type,
      source_file = path,
      var_name = v,
      label_mn = ifelse(is.null(lab), NA_character_, as.character(lab)),
      type = type,
      n_obs = length(x_plain),
      n_missing = n_missing,
      n_unique = n_unique
    )
  })
}

preview_file <- function(path) {
  wave <- as.integer(str_extract(path, "20[0-9]{2}"))
  source_type <- case_when(
    str_detect(basename(path), regex("02_indiv", ignore_case = TRUE)) ~ "indiv",
    str_detect(basename(path), regex("01_hhold", ignore_case = TRUE)) ~ "hhold",
    str_detect(basename(path), regex("basicvars", ignore_case = TRUE)) ~ "basicvars",
    TRUE ~ "other"
  )
  df <- haven::read_dta(path)
  map_dfr(names(df), function(v) {
    x <- df[[v]]
    lab <- attr(x, "label", exact = TRUE)
    labels <- attr(x, "labels", exact = TRUE)
    x_plain <- if (inherits(x, "haven_labelled")) haven::zap_labels(x) else x
    miss_rate <- mean(is.na(x_plain))
    is_num <- is.numeric(x_plain) || is.integer(x_plain)
    top_vals <- tryCatch({
      vals <- as.character(x_plain)
      tb <- sort(table(vals, useNA = "no"), decreasing = TRUE)
      paste(paste0(names(tb)[seq_len(min(10, length(tb)))], " (", as.integer(tb[seq_len(min(10, length(tb)))]), ")"), collapse = " | ")
    }, error = function(e) NA_character_)
    value_labels <- if (!is.null(labels)) {
      paste(paste0(as.character(labels), "=", names(labels)), collapse = " | ")
    } else NA_character_
    tibble(
      wave = wave,
      source_type = source_type,
      source_file = path,
      var_name = v,
      label_mn = ifelse(is.null(lab), NA_character_, as.character(lab)),
      type = paste(class(x), collapse = "/"),
      n_obs = length(x_plain),
      n_missing = sum(is.na(x_plain)),
      missing_rate = miss_rate,
      n_unique = dplyr::n_distinct(x_plain, na.rm = TRUE),
      min = if (is_num) suppressWarnings(min(as.numeric(x_plain), na.rm = TRUE)) else NA_real_,
      max = if (is_num) suppressWarnings(max(as.numeric(x_plain), na.rm = TRUE)) else NA_real_,
      mean = if (is_num) suppressWarnings(mean(as.numeric(x_plain), na.rm = TRUE)) else NA_real_,
      median = if (is_num) suppressWarnings(stats::median(as.numeric(x_plain), na.rm = TRUE)) else NA_real_,
      top_10_values = top_vals,
      value_labels = value_labels
    )
  })
}

files <- list.files("data", pattern = "\\.dta$", recursive = TRUE, full.names = TRUE)
files <- files[str_detect(files, "hses_20(20|21|22|23|24)")]
files <- files[!str_detect(files, "/renv/|/.git/|/codex/")]
if (length(files) == 0) stop("No HSES .dta files found.")

meta_long <- map_dfr(files, read_meta_file)
preview_long <- map_dfr(files, preview_file)

choose_label <- function(labels) {
  labels <- unique(na.omit(labels))
  if (length(labels) == 0) return(NA_character_)
  score <- str_count(labels, "[А-Яа-яӨөҮүЁё]") - str_count(labels, "Р|С|Т|Ð|Ñ")
  labels[[which.max(score)]]
}

inventory <- meta_long %>%
  group_by(var_name) %>%
  summarise(
    label_mn = choose_label(label_mn),
    label_en = rough_translate_label(label_mn),
    type = paste(sort(unique(type)), collapse = " | "),
    waves_present = paste(sort(unique(wave)), collapse = ","),
    source_types = paste(sort(unique(source_type)), collapse = ","),
    source_files = paste(sort(unique(basename(source_file))), collapse = " | "),
    n_obs = sum(n_obs),
    n_missing = sum(n_missing),
    n_unique = max(n_unique, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  rowwise() %>%
  mutate(
    label_en = rough_translate_label(label_mn),
    category = category_from_text(var_name, label_mn)
  ) %>%
  ungroup() %>%
  arrange(category, var_name)

preview <- preview_long %>%
  mutate(
    label_en = vapply(label_mn, rough_translate_label, character(1)),
    category = mapply(category_from_text, var_name, label_mn),
    preview_key = paste0(wave, "_", source_type)
  ) %>%
  arrange(var_name, wave, source_type)

readr::write_csv(inventory, "data/auxiliary/hses_variable_inventory.csv")
readr::write_csv(preview, "data/auxiliary/hses_variable_preview.csv")

category_summary <- inventory %>% count(category, sort = TRUE)
readr::write_csv(category_summary, "output/tables/hses_variable_category_summary.csv")

cat("\nInventory variables:", nrow(inventory), "\n")
cat("Preview rows:", nrow(preview), "\n")
cat("Category summary:\n")
print(category_summary, n = Inf)
cat("\n13a complete.\n")


