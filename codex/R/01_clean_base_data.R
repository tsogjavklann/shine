# Clean base HSES and livestock data for dzud IV audit.

options(warn = 1)

get_script_path <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) == 0) return(file.path("codex", "R", "01_clean_base_data.R"))
  sub("^--file=", "", file_arg[[1]])
}

script_dir <- dirname(normalizePath(get_script_path(), winslash = "/", mustWork = FALSE))
project_root <- normalizePath(file.path(script_dir, "..", ".."), winslash = "/", mustWork = TRUE)
codex_root <- file.path(project_root, "codex")

dirs <- file.path(codex_root, c("R", "output/tables", "output/logs", "output/reports", "data/cleaned"))
invisible(lapply(dirs, dir.create, recursive = TRUE, showWarnings = FALSE))

log_file <- file.path(codex_root, "output/logs/01_clean_base_data.log")
sink(log_file, split = TRUE)
on.exit(sink(), add = TRUE)

cat("01_clean_base_data.R\n")
cat("Project root:", project_root, "\n")
cat("Output root:", codex_root, "\n\n")

required_pkgs <- c("dplyr", "tidyr", "stringr", "readr", "readxl", "haven", "tibble", "purrr")
missing_pkgs <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_pkgs) > 0) {
  stop("Missing required R packages: ", paste(missing_pkgs, collapse = ", "))
}

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(readr)
  library(readxl)
  library(haven)
  library(tibble)
  library(purrr)
})

aimag_lookup <- tibble::tribble(
  ~aimag_name, ~hses_code, ~birth_region,
  "Улаанбаатар", 11, "Ulaanbaatar",
  "Дорнод", 21, "Eastern",
  "Сүхбаатар", 22, "Eastern",
  "Хэнтий", 23, "Eastern",
  "Төв", 41, "Central",
  "Говьсүмбэр", 42, "Central",
  "Сэлэнгэ", 43, "Central",
  "Дорноговь", 44, "Central",
  "Дархан-Уул", 45, "Central",
  "Өмнөговь", 46, "Central",
  "Дундговь", 48, "Central",
  "Орхон", 61, "Khangai",
  "Өвөрхангай", 62, "Khangai",
  "Булган", 63, "Khangai",
  "Баянхонгор", 64, "Khangai",
  "Архангай", 65, "Khangai",
  "Хөвсгөл", 67, "Khangai",
  "Завхан", 81, "Western",
  "Говь-Алтай", 82, "Western",
  "Баян-Өлгий", 83, "Western",
  "Ховд", 84, "Western",
  "Увс", 85, "Western"
)

standardize_aimag <- function(x) {
  x <- as.character(x)
  x <- str_squish(x)
  x <- str_replace_all(x, "\u00a0", " ")
  x <- str_replace_all(x, "–|—", "-")
  x <- str_remove(x, "\\s+аймаг$")
  dplyr::case_when(
    x %in% c("УБ", "Улаанбаатар хот", "Нийслэл", "Ulaanbaatar") ~ "Улаанбаатар",
    x %in% c("Дархан уул", "Дархан-уул", "Дархан Уул") ~ "Дархан-Уул",
    x %in% c("Говь Алтай", "Говь-алтай") ~ "Говь-Алтай",
    x %in% c("Баян Өлгий", "Баян-өлгий") ~ "Баян-Өлгий",
    TRUE ~ x
  )
}

to_num <- function(x) {
  if (inherits(x, "haven_labelled")) x <- haven::zap_labels(x)
  suppressWarnings(as.numeric(x))
}

pick_first <- function(nms, candidates) {
  hit <- candidates[candidates %in% nms]
  if (length(hit) == 0) NA_character_ else hit[[1]]
}

read_candidate_data <- function(path, n_max = Inf) {
  ext <- tolower(tools::file_ext(path))
  if (ext == "rds") {
    x <- readRDS(path)
    if (is.data.frame(x)) return(x)
    return(NULL)
  }
  if (ext == "csv") {
    return(readr::read_csv(path, show_col_types = FALSE, n_max = n_max))
  }
  if (ext == "dta") {
    return(haven::read_dta(path, n_max = if (is.infinite(n_max)) Inf else n_max))
  }
  if (ext == "sav") {
    return(haven::read_sav(path, n_max = if (is.infinite(n_max)) Inf else n_max))
  }
  NULL
}

score_hses_candidate <- function(path) {
  out <- tryCatch({
    x <- read_candidate_data(path, n_max = 300)
    if (is.null(x) || !is.data.frame(x)) {
      return(tibble(path = path, n_cols = NA_integer_, n_rows_sample = NA_integer_, score = -1))
    }
    nms <- names(x)
    synonyms <- list(
      id = c("id", "pid", "person_id", "ind_id", "identif"),
      educ_years = c("educ_years", "education_years", "years_educ", "n_years_new"),
      wage = c("real_hourly", "nominal_hourly", "wage", "hourly_wage", "monthly_wage", "q0436a", "q0436b"),
      ln_wage = c("lwage", "ln_wage", "log_wage", "ln_real_hourly", "ln_nominal_hourly"),
      birth_year = c("birth_year", "byear", "birthyear"),
      birth_aimag = c("birth_aimag", "birthplace_aimag", "birth_aimag_code"),
      age = c("age", "q0105y"),
      sex = c("female", "is_female", "sex", "q0103"),
      marital = c("married", "is_married", "marital", "q0106"),
      urban = c("urban"),
      hhweight = c("hhweight", "household_weight", "weight"),
      wave = c("wave", "survey_year", "year")
    )
    hits <- vapply(synonyms, function(v) any(v %in% nms), logical(1))
    score <- sum(hits) + 2 * any(c("lwage", "ln_wage", "log_wage", "ln_real_hourly") %in% nms)
    score <- score + 2 * any(c("real_hourly", "nominal_hourly", "wage") %in% nms)
    score <- score + ifelse(grepl("analysis_sample", basename(path), ignore.case = TRUE), 3, 0)
    tibble(path = path, n_cols = length(nms), n_rows_sample = nrow(x), score = score)
  }, error = function(e) {
    tibble(path = path, n_cols = NA_integer_, n_rows_sample = NA_integer_,
           score = -1, error = conditionMessage(e))
  })
  out
}

all_data_files <- list.files(
  project_root,
  pattern = "\\.(rds|csv|dta|sav)$",
  recursive = TRUE,
  full.names = TRUE,
  ignore.case = TRUE
)
all_data_files <- all_data_files[
  !grepl("(^|/)(renv|\\.git|codex)(/|$)", normalizePath(all_data_files, winslash = "/", mustWork = FALSE))
]
all_data_files <- all_data_files[
  grepl("hses|analysis|processed|raw", normalizePath(all_data_files, winslash = "/", mustWork = FALSE), ignore.case = TRUE)
]

cat("Candidate HSES/data files searched:", length(all_data_files), "\n")
candidate_scores <- purrr::map_dfr(all_data_files, score_hses_candidate) %>%
  arrange(desc(score), path)
readr::write_csv(candidate_scores, file.path(codex_root, "output/logs/01_hses_candidate_scores.csv"))
print(candidate_scores, n = min(nrow(candidate_scores), 30))

if (nrow(candidate_scores) == 0 || max(candidate_scores$score, na.rm = TRUE) < 6) {
  stop("No plausible individual-level HSES file found with the required variables.")
}

hses_path <- candidate_scores$path[[which.max(candidate_scores$score)]]
cat("\nSelected HSES file:", hses_path, "\n")
hses_raw <- read_candidate_data(hses_path, n_max = Inf)
if (!is.data.frame(hses_raw)) stop("Selected HSES file did not load as a data frame.")

cat("\nAvailable HSES column names:\n")
cat(paste(names(hses_raw), collapse = ", "), "\n\n")
writeLines(names(hses_raw), file.path(codex_root, "output/logs/01_hses_columns.txt"), useBytes = TRUE)

nms <- names(hses_raw)
mapping <- c(
  id = pick_first(nms, c("id", "person_id", "pid")),
  identif = pick_first(nms, c("identif", "household_id", "hhid")),
  ind_id = pick_first(nms, c("ind_id", "person_no")),
  educ_years = pick_first(nms, c("educ_years", "education_years", "years_educ", "n_years_new")),
  wage = pick_first(nms, c("real_hourly", "wage", "hourly_wage", "nominal_hourly", "monthly_wage", "q0436a", "q0436b")),
  ln_wage = pick_first(nms, c("lwage", "ln_wage", "log_wage", "ln_real_hourly", "ln_nominal_hourly")),
  birth_year = pick_first(nms, c("birth_year", "byear", "birthyear")),
  birth_aimag = pick_first(nms, c("birth_aimag", "birthplace_aimag", "birth_aimag_code")),
  age = pick_first(nms, c("age", "q0105y")),
  age2 = pick_first(nms, c("age2")),
  sex = pick_first(nms, c("is_female", "female", "sex", "q0103")),
  married = pick_first(nms, c("is_married", "married", "marital", "q0106")),
  urban = pick_first(nms, c("urban")),
  hhweight = pick_first(nms, c("hhweight", "household_weight", "weight")),
  wave = pick_first(nms, c("wave", "survey_year", "year")),
  region = pick_first(nms, c("region", "region_f")),
  hhsize = pick_first(nms, c("hhsize", "household_size"))
)

mapping_tbl <- tibble(standard_name = names(mapping), source_name = unname(mapping))
readr::write_csv(mapping_tbl, file.path(codex_root, "output/logs/01_variable_mapping.csv"))
cat("Variable mapping:\n")
print(mapping_tbl, n = nrow(mapping_tbl))

must_have <- c("educ_years", "birth_year", "birth_aimag", "age", "wave")
missing_must <- must_have[is.na(mapping[must_have])]
if (length(missing_must) > 0) {
  stop("Required HSES variables missing after mapping: ", paste(missing_must, collapse = ", "))
}
if (is.na(mapping[["wage"]]) && is.na(mapping[["ln_wage"]])) {
  stop("No wage or log-wage variable found in selected HSES file.")
}

get_col <- function(df, nm) {
  if (is.na(nm) || !nm %in% names(df)) return(rep(NA, nrow(df)))
  df[[nm]]
}

id_val <- if (!is.na(mapping[["id"]])) {
  as.character(get_col(hses_raw, mapping[["id"]]))
} else if (!is.na(mapping[["identif"]]) && !is.na(mapping[["ind_id"]])) {
  paste(get_col(hses_raw, mapping[["wave"]]), get_col(hses_raw, mapping[["identif"]]), get_col(hses_raw, mapping[["ind_id"]]), sep = "-")
} else {
  as.character(seq_len(nrow(hses_raw)))
}

wage_val <- if (!is.na(mapping[["wage"]])) to_num(get_col(hses_raw, mapping[["wage"]])) else rep(NA_real_, nrow(hses_raw))
ln_wage_val <- if (!is.na(mapping[["ln_wage"]])) to_num(get_col(hses_raw, mapping[["ln_wage"]])) else rep(NA_real_, nrow(hses_raw))
if (all(is.na(ln_wage_val)) && any(is.finite(wage_val) & wage_val > 0)) {
  ln_wage_val <- ifelse(is.finite(wage_val) & wage_val > 0, log(wage_val), NA_real_)
}
if (all(is.na(wage_val)) && any(is.finite(ln_wage_val))) {
  wage_val <- exp(ln_wage_val)
}

sex_src <- get_col(hses_raw, mapping[["sex"]])
sex_num <- to_num(sex_src)
female_val <- if (!is.na(mapping[["sex"]]) && mapping[["sex"]] %in% c("is_female", "female")) {
  as.integer(sex_num == 1)
} else if (all(na.omit(unique(sex_num)) %in% c(0, 1))) {
  as.integer(sex_num == 1)
} else {
  as.integer(sex_num == 2)
}

married_src <- get_col(hses_raw, mapping[["married"]])
married_num <- to_num(married_src)
married_val <- if (!is.na(mapping[["married"]]) && mapping[["married"]] %in% c("is_married", "married")) {
  as.integer(married_num == 1)
} else {
  as.integer(married_num %in% c(2))
}

urban_src <- get_col(hses_raw, mapping[["urban"]])
urban_num <- to_num(urban_src)
urban_unique <- sort(unique(stats::na.omit(urban_num)))
urban_val <- if (length(urban_unique) > 0 && all(urban_unique %in% c(0, 1))) {
  as.integer(urban_num == 1)
} else {
  as.integer(urban_num == 1)
}

birth_aimag_src <- get_col(hses_raw, mapping[["birth_aimag"]])
birth_aimag_num <- to_num(birth_aimag_src)
birth_aimag_chr <- standardize_aimag(as.character(birth_aimag_src))
birth_aimag_code <- ifelse(!is.na(birth_aimag_num), birth_aimag_num,
                           aimag_lookup$hses_code[match(birth_aimag_chr, aimag_lookup$aimag_name)])

hhweight_val <- if (!is.na(mapping[["hhweight"]])) to_num(get_col(hses_raw, mapping[["hhweight"]])) else rep(1, nrow(hses_raw))
hhweight_val <- ifelse(is.finite(hhweight_val) & hhweight_val > 0, hhweight_val, 1)

age_val <- to_num(get_col(hses_raw, mapping[["age"]]))
age2_val <- if (!is.na(mapping[["age2"]])) to_num(get_col(hses_raw, mapping[["age2"]])) else age_val^2

hses_std <- tibble(
  id = id_val,
  educ_years = to_num(get_col(hses_raw, mapping[["educ_years"]])),
  wage = wage_val,
  ln_wage = ln_wage_val,
  birth_year = to_num(get_col(hses_raw, mapping[["birth_year"]])),
  birth_aimag = birth_aimag_code,
  age = age_val,
  age2 = age2_val,
  female = female_val,
  married = married_val,
  urban = urban_val,
  hhweight = hhweight_val,
  wave = to_num(get_col(hses_raw, mapping[["wave"]])),
  region = if (!is.na(mapping[["region"]])) as.character(get_col(hses_raw, mapping[["region"]])) else NA_character_,
  hhsize = if (!is.na(mapping[["hhsize"]])) to_num(get_col(hses_raw, mapping[["hhsize"]])) else NA_real_
) %>%
  mutate(
    birth_aimag = as.integer(birth_aimag),
    birth_year = as.integer(birth_year),
    wave = as.integer(wave)
  ) %>%
  left_join(aimag_lookup, by = c("birth_aimag" = "hses_code")) %>%
  rename(birth_aimag_name = aimag_name)

unmatched_hses <- hses_std %>%
  count(birth_aimag, sort = TRUE) %>%
  filter(is.na(birth_aimag) | !birth_aimag %in% aimag_lookup$hses_code)
readr::write_csv(unmatched_hses, file.path(codex_root, "output/logs/01_unmatched_hses_birth_aimag.csv"))

hses_clean <- hses_std %>%
  filter(
    age >= 25, age <= 60,
    is.finite(ln_wage),
    is.finite(wage), wage > 0,
    !is.na(educ_years),
    !is.na(birth_year),
    !is.na(birth_aimag),
    birth_aimag %in% aimag_lookup$hses_code
  ) %>%
  mutate(
    row_id = row_number(),
    female = ifelse(is.na(female), NA_integer_, as.integer(female)),
    married = ifelse(is.na(married), NA_integer_, as.integer(married)),
    urban = ifelse(is.na(urban), NA_integer_, as.integer(urban))
  )

cat("\nHSES rows loaded:", nrow(hses_raw), "\n")
cat("HSES clean wage-earner sample rows:", nrow(hses_clean), "\n")
cat("Birth year range:", min(hses_clean$birth_year, na.rm = TRUE), "-", max(hses_clean$birth_year, na.rm = TRUE), "\n")
cat("Birth aimag matched rows:", sum(!is.na(hses_clean$birth_aimag_name)), "\n\n")

livestock_count_path <- list.files(project_root, pattern = "МАЛЫН ТОО.*\\.xlsx$", recursive = TRUE, full.names = TRUE)
livestock_loss_paths <- list.files(project_root, pattern = "ТОМ МАЛЫН ЗҮЙ БУС ХОРОГДОЛ.*\\.xlsx$", recursive = TRUE, full.names = TRUE)
livestock_count_path <- livestock_count_path[!grepl("(^|/)(codex|renv|\\.git)(/|$)", normalizePath(livestock_count_path, winslash = "/", mustWork = FALSE))]
livestock_loss_paths <- livestock_loss_paths[!grepl("(^|/)(codex|renv|\\.git)(/|$)", normalizePath(livestock_loss_paths, winslash = "/", mustWork = FALSE))]

if (length(livestock_count_path) == 0) stop("Livestock count XLSX not found.")
if (length(livestock_loss_paths) == 0) stop("Livestock mortality XLSX not found.")

livestock_count_path <- livestock_count_path[[1]]
aimag_loss_path <- livestock_loss_paths[grepl("аймаг", basename(livestock_loss_paths))]
if (length(aimag_loss_path) == 0) aimag_loss_path <- livestock_loss_paths[[1]]
aimag_loss_path <- aimag_loss_path[[1]]
bag_loss_path <- livestock_loss_paths[grepl("баг|хороо|2026-04-26", basename(livestock_loss_paths), ignore.case = TRUE)]

cat("Livestock count XLSX:", livestock_count_path, "\n")
cat("Livestock aimag mortality XLSX:", aimag_loss_path, "\n")
if (length(bag_loss_path) == 0) {
  cat("Bag/khoroo mortality XLSX listed in task was not found locally; using aimag-level mortality workbook.\n")
} else {
  cat("Bag/khoroo mortality XLSX found but not used for main aimag IV:", bag_loss_path[[1]], "\n")
}

valid_animals <- c("Бүгд", "Адуу", "Үхэр", "Тэмээ", "Хонь", "Ямаа")

parse_nso_number <- function(x) {
  x <- as.character(x)
  x <- str_replace_all(x, "\u00a0", "")
  x <- str_replace_all(x, "\\s+", "")
  x <- str_replace_all(x, ",", "")
  suppressWarnings(as.numeric(x))
}

clean_livestock_workbook <- function(path, value_name) {
  raw <- readxl::read_excel(path, col_names = FALSE, col_types = "text", .name_repair = "minimal")
  header <- as.character(unlist(raw[3, ], use.names = FALSE))
  year_cols <- which(grepl("^[0-9]{4}$", header))
  if (length(year_cols) == 0) stop("No year columns detected in ", path)

  dat <- raw[-c(1:3), c(1, 2, year_cols)]
  names(dat) <- c("animal_type", "aimag_name", header[year_cols])
  dat <- dat %>%
    tidyr::fill(animal_type, .direction = "down") %>%
    mutate(
      animal_type = str_squish(as.character(animal_type)),
      aimag_name = standardize_aimag(aimag_name)
    ) %>%
    filter(animal_type %in% valid_animals, !is.na(aimag_name), aimag_name != "")

  long <- dat %>%
    tidyr::pivot_longer(
      cols = matches("^[0-9]{4}$"),
      names_to = "year",
      values_to = value_name
    ) %>%
    mutate(
      year = as.integer(year),
      value_tmp = parse_nso_number(.data[[value_name]])
    ) %>%
    select(-all_of(value_name)) %>%
    rename(!!value_name := value_tmp) %>%
    left_join(aimag_lookup, by = c("aimag_name" = "aimag_name"))

  unmatched <- long %>%
    filter(is.na(hses_code), !grepl("бүс|Улсын дүн", aimag_name)) %>%
    distinct(aimag_name) %>%
    arrange(aimag_name)
  if (nrow(unmatched) > 0) {
    cat("Unmatched livestock names in", basename(path), ":\n")
    print(unmatched, n = nrow(unmatched))
  }

  long %>%
    filter(!is.na(hses_code), !is.na(.data[[value_name]])) %>%
    transmute(
      aimag_name,
      aimag_code = as.integer(hses_code),
      animal_type,
      year,
      !!value_name := .data[[value_name]]
    ) %>%
    group_by(aimag_code, aimag_name, animal_type, year) %>%
    summarise(!!value_name := mean(.data[[value_name]], na.rm = TRUE), .groups = "drop") %>%
    arrange(animal_type, aimag_code, year)
}

livestock_by_animal <- clean_livestock_workbook(livestock_count_path, "livestock_count")
loss_by_animal <- clean_livestock_workbook(aimag_loss_path, "loss_count")

cat("\nLivestock count rows:", nrow(livestock_by_animal), "\n")
cat("Livestock mortality rows:", nrow(loss_by_animal), "\n")
cat("Count years:", min(livestock_by_animal$year), "-", max(livestock_by_animal$year), "\n")
cat("Loss years:", min(loss_by_animal$year), "-", max(loss_by_animal$year), "\n\n")

dzud_panel <- full_join(
  livestock_by_animal %>% filter(animal_type == "Бүгд"),
  loss_by_animal %>% filter(animal_type == "Бүгд"),
  by = c("aimag_code", "aimag_name", "animal_type", "year")
) %>%
  arrange(aimag_code, year) %>%
  group_by(aimag_code) %>%
  mutate(livestock_lag = lag(livestock_count)) %>%
  ungroup() %>%
  mutate(
    loss_rate = ifelse(is.finite(loss_count) & is.finite(livestock_lag) & livestock_lag > 0,
                       loss_count / livestock_lag * 100, NA_real_)
  ) %>%
  group_by(year) %>%
  mutate(
    loss_rate_p75 = ifelse(all(is.na(loss_rate)), NA_real_,
                           as.numeric(stats::quantile(loss_rate, 0.75, na.rm = TRUE))),
    dzud5 = ifelse(is.na(loss_rate), NA_integer_, as.integer(loss_rate >= 5)),
    dzud10 = ifelse(is.na(loss_rate), NA_integer_, as.integer(loss_rate >= 10)),
    dzud_p75 = ifelse(is.na(loss_rate) | is.na(loss_rate_p75), NA_integer_,
                      as.integer(loss_rate >= loss_rate_p75))
  ) %>%
  ungroup() %>%
  arrange(aimag_code, year)

cat("Dzud panel rows:", nrow(dzud_panel), "\n")
cat("Dzud panel nonmissing loss_rate rows:", sum(!is.na(dzud_panel$loss_rate)), "\n")
cat("Dzud5 events:", sum(dzud_panel$dzud5 == 1, na.rm = TRUE), "\n")
cat("Dzud10 events:", sum(dzud_panel$dzud10 == 1, na.rm = TRUE), "\n")
cat("Dzud p75 events:", sum(dzud_panel$dzud_p75 == 1, na.rm = TRUE), "\n\n")

saveRDS(hses_clean, file.path(codex_root, "data/cleaned/hses_clean.rds"))
saveRDS(dzud_panel, file.path(codex_root, "data/cleaned/dzud_panel.rds"))
readr::write_csv(dzud_panel, file.path(codex_root, "data/cleaned/dzud_panel.csv"))
saveRDS(livestock_by_animal, file.path(codex_root, "data/cleaned/livestock_by_animal.rds"))
saveRDS(loss_by_animal, file.path(codex_root, "data/cleaned/loss_by_animal.rds"))

data_files_used <- tibble::tibble(
  role = c("HSES individual analysis data", "Livestock count XLSX", "Livestock mortality XLSX"),
  path = c(hses_path, livestock_count_path, aimag_loss_path)
)
readr::write_csv(data_files_used, file.path(codex_root, "output/logs/01_data_files_used.csv"))

cat("Saved:\n")
cat(" -", file.path(codex_root, "data/cleaned/hses_clean.rds"), "\n")
cat(" -", file.path(codex_root, "data/cleaned/dzud_panel.rds"), "\n")
cat(" -", file.path(codex_root, "data/cleaned/dzud_panel.csv"), "\n")
cat(" -", file.path(codex_root, "data/cleaned/livestock_by_animal.rds"), "\n")
cat(" -", file.path(codex_root, "data/cleaned/loss_by_animal.rds"), "\n")
cat("\n01_clean_base_data.R complete.\n")
