# Clean manually downloaded 1212.mn education-supply Excel files and verify
# against PXWeb when the API is reachable.

options(warn = 1)

required_pkgs <- c("readxl", "dplyr", "tidyr", "stringr", "readr", "tibble", "purrr", "jsonlite", "httr")
missing_pkgs <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_pkgs) > 0) stop("Missing required packages: ", paste(missing_pkgs, collapse = ", "))

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(readr)
  library(tibble)
  library(purrr)
  library(jsonlite)
  library(httr)
})

root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
dir.create("R", showWarnings = FALSE, recursive = TRUE)
dir.create("data/cleaned", showWarnings = FALSE, recursive = TRUE)
dir.create("data/aux", showWarnings = FALSE, recursive = TRUE)
dir.create("output/tables", showWarnings = FALSE, recursive = TRUE)
dir.create("output/reports", showWarnings = FALSE, recursive = TRUE)
dir.create("output/logs", showWarnings = FALSE, recursive = TRUE)

sink("output/logs/03a_clean_manual_education_supply.log", split = TRUE)
on.exit(sink(), add = TRUE)

cat("03a_clean_manual_education_supply.R\n")
cat("Root:", root, "\n\n")

aimag_lookup <- tibble::tribble(
  ~aimag_name, ~aimag_code, ~region_name,
  "Улаанбаатар", 11L, "Ulaanbaatar",
  "Дорнод", 21L, "Eastern",
  "Сүхбаатар", 22L, "Eastern",
  "Хэнтий", 23L, "Eastern",
  "Төв", 41L, "Central",
  "Говьсүмбэр", 42L, "Central",
  "Сэлэнгэ", 43L, "Central",
  "Дорноговь", 44L, "Central",
  "Дархан-Уул", 45L, "Central",
  "Өмнөговь", 46L, "Central",
  "Дундговь", 48L, "Central",
  "Орхон", 61L, "Khangai",
  "Өвөрхангай", 62L, "Khangai",
  "Булган", 63L, "Khangai",
  "Баянхонгор", 64L, "Khangai",
  "Архангай", 65L, "Khangai",
  "Хөвсгөл", 67L, "Khangai",
  "Завхан", 81L, "Western",
  "Говь-Алтай", 82L, "Western",
  "Баян-Өлгий", 83L, "Western",
  "Ховд", 84L, "Western",
  "Увс", 85L, "Western"
)

standardize_name <- function(x) {
  x <- as.character(x)
  x <- str_replace_all(x, "\u00a0", " ")
  x <- str_replace_all(x, "–|—", "-")
  x <- str_squish(x)
  x <- str_remove(x, "^\\s+")
  x <- str_remove(x, "\\s+$")
  x <- str_remove(x, "\\s+аймаг$")
  case_when(
    x %in% c("УБ", "Нийслэл", "Улаанбаатар хот", "Ulaanbaatar") ~ "Улаанбаатар",
    x %in% c("Дархан уул", "Дархан-уул", "Дархан Уул") ~ "Дархан-Уул",
    x %in% c("Говь Алтай", "Говь-алтай") ~ "Говь-Алтай",
    x %in% c("Баян Өлгий", "Баян-өлгий") ~ "Баян-Өлгий",
    TRUE ~ x
  )
}

parse_num <- function(x) {
  x <- as.character(x)
  x <- str_replace_all(x, "\u00a0", "")
  x <- str_replace_all(x, "\\s+", "")
  x <- str_replace_all(x, ",", "")
  suppressWarnings(as.numeric(x))
}

find_file <- function(pattern) {
  files <- list.files("data", pattern = pattern, recursive = TRUE, full.names = TRUE)
  files <- files[grepl("\\.xlsx$", files, ignore.case = TRUE)]
  if (length(files) == 0) stop("Required Excel file not found for pattern: ", pattern)
  files[[1]]
}

files <- list(
  schools = find_file("СУРГУУЛИЙН ТОО.*аймаг.*жилээр"),
  students = find_file("СУРГУУЛЬД ӨДРӨӨР СУРАЛЦАГЧДЫН ТОО.*аймаг.*жилээр"),
  teachers = find_file("ҮНДСЭН БАГШ.*аймаг.*жилээр"),
  population_age = find_file("ХҮН АМЫН ТОО.*хүйс.*насны бүлэг.*жилээр"),
  annual_average_population = find_file("ЖИЛИЙН ДУНДАЖ ХҮН АМЫН ТОО.*аймаг.*жилээр")
)

cat("Manual Excel files found:\n")
print(tibble(role = names(files), path = unlist(files)), n = Inf)

read_wide_area_year <- function(path, value_name, scale = 1) {
  raw <- readxl::read_excel(path, sheet = 1, col_names = FALSE, col_types = "text", .name_repair = "minimal")
  year_counts <- apply(raw[seq_len(min(8, nrow(raw))), , drop = FALSE], 1, function(z) {
    sum(grepl("^(19|20)[0-9]{2}$", as.character(z)))
  })
  header_row <- which.max(year_counts)
  year_vals <- as.character(unlist(raw[header_row, ], use.names = FALSE))
  year_cols <- which(grepl("^(19|20)[0-9]{2}$", year_vals))
  if (length(year_cols) == 0) stop("No year columns detected in ", path)
  name_col <- 1L

  dat <- raw[(header_row + 1):nrow(raw), c(name_col, year_cols), drop = FALSE]
  names(dat) <- c("aimag_name", year_vals[year_cols])
  dat %>%
    mutate(aimag_name_raw = as.character(aimag_name),
           aimag_name = standardize_name(aimag_name)) %>%
    pivot_longer(cols = matches("^(19|20)[0-9]{2}$"), names_to = "year", values_to = "raw_value") %>%
    mutate(
      year = as.integer(year),
      raw_value_num = parse_num(raw_value),
      value = raw_value_num * scale
    ) %>%
    filter(!is.na(aimag_name), aimag_name != "", !is.na(year), !is.na(raw_value_num)) %>%
    left_join(aimag_lookup, by = "aimag_name") %>%
    transmute(
      aimag_code,
      aimag_name,
      aimag_name_raw,
      year,
      raw_value = raw_value_num,
      !!value_name := value
    )
}

read_population_age <- function(path) {
  raw <- readxl::read_excel(path, sheet = 1, col_names = FALSE, col_types = "text", .name_repair = "minimal")
  year_counts <- apply(raw[seq_len(min(8, nrow(raw))), , drop = FALSE], 1, function(z) {
    sum(grepl("^(19|20)[0-9]{2}$", as.character(z)))
  })
  header_row <- which.max(year_counts)
  year_vals <- as.character(unlist(raw[header_row, ], use.names = FALSE))
  year_cols <- which(grepl("^(19|20)[0-9]{2}$", year_vals))
  dat <- raw[(header_row + 1):nrow(raw), c(1, 2, year_cols), drop = FALSE]
  names(dat) <- c("sex", "age_group", year_vals[year_cols])
  dat %>%
    mutate(sex = str_squish(as.character(sex)), age_group = str_squish(as.character(age_group))) %>%
    pivot_longer(cols = matches("^(19|20)[0-9]{2}$"), names_to = "year", values_to = "population") %>%
    mutate(year = as.integer(year), population = parse_num(population)) %>%
    filter(!is.na(year), !is.na(population))
}

schools_raw <- read_wide_area_year(files$schools, "schools", scale = 1)
students_raw <- read_wide_area_year(files$students, "students", scale = 1000)
teachers_raw <- read_wide_area_year(files$teachers, "teachers", scale = 1)
annual_pop_raw <- read_wide_area_year(files$annual_average_population, "annual_average_population", scale = 1)
population_age <- read_population_age(files$population_age)

collapse_aimag_year <- function(df, value_col) {
  df %>%
    filter(!is.na(aimag_code)) %>%
    group_by(aimag_code, aimag_name, year) %>%
    summarise(
      "{value_col}" := mean(.data[[value_col]], na.rm = TRUE),
      .groups = "drop"
    )
}

schools <- collapse_aimag_year(schools_raw %>% rename(schools = schools), "schools")
students <- collapse_aimag_year(students_raw %>% rename(students = students), "students")
teachers <- collapse_aimag_year(teachers_raw %>% rename(teachers = teachers), "teachers")
annual_pop <- collapse_aimag_year(annual_pop_raw %>% rename(annual_average_population = annual_average_population), "annual_average_population")

school_age_groups <- c("5-9", "10-14", "15-19")
school_age_population_national <- population_age %>%
  filter(sex == "Бүгд", age_group %in% school_age_groups) %>%
  group_by(year) %>%
  summarise(national_school_age_population = sum(population, na.rm = TRUE), .groups = "drop") %>%
  mutate(note = "National-only age groups 5-9, 10-14, 15-19; not usable for aimag-level IV normalization.")

readr::write_csv(population_age, "data/aux/population_by_sex_age_year_manual.csv")
readr::write_csv(school_age_population_national, "data/aux/national_school_age_population_manual.csv")
readr::write_csv(annual_pop, "data/aux/annual_average_population_by_aimag_manual.csv")

unmatched <- bind_rows(
  schools_raw %>% filter(is.na(aimag_code)) %>% distinct(source = "schools", aimag_name_raw, aimag_name),
  students_raw %>% filter(is.na(aimag_code)) %>% distinct(source = "students", aimag_name_raw, aimag_name),
  teachers_raw %>% filter(is.na(aimag_code)) %>% distinct(source = "teachers", aimag_name_raw, aimag_name),
  annual_pop_raw %>% filter(is.na(aimag_code)) %>% distinct(source = "annual_average_population", aimag_name_raw, aimag_name)
) %>%
  filter(!aimag_name %in% c("Улсын дүн", "Баруун бүс", "Хангайн бүс", "Төвийн бүс", "Зүүн бүс", "Бусад")) %>%
  arrange(source, aimag_name)
readr::write_csv(unmatched, "output/tables/unmatched_aimag_names_school_supply.csv")

panel <- schools %>%
  full_join(students, by = c("aimag_code", "aimag_name", "year")) %>%
  full_join(teachers, by = c("aimag_code", "aimag_name", "year")) %>%
  full_join(annual_pop, by = c("aimag_code", "aimag_name", "year")) %>%
  arrange(aimag_code, year) %>%
  group_by(aimag_code) %>%
  mutate(
    school_age_population = NA_real_,
    school_density_student = schools / students * 1000,
    students_per_school = students / schools,
    teachers_per_student = teachers / students,
    student_teacher_ratio = students / teachers,
    school_closure_rate = (lag(schools) - schools) / lag(schools),
    school_growth_rate = (schools - lag(schools)) / lag(schools),
    teacher_growth_rate = (teachers - lag(teachers)) / lag(teachers),
    student_growth_rate = (students - lag(students)) / lag(students),
    school_density_pop = NA_real_,
    teachers_per_1000_children = NA_real_,
    students_per_1000_children = NA_real_
  ) %>%
  ungroup()

saveRDS(panel, "data/cleaned/school_supply_panel.rds")
readr::write_csv(panel, "data/cleaned/school_supply_panel.csv")

cat("\nPanel rows:", nrow(panel), "\n")
cat("Panel years:", min(panel$year, na.rm = TRUE), "-", max(panel$year, na.rm = TRUE), "\n")
cat("Aimag count:", n_distinct(panel$aimag_code), "\n\n")

px_specs <- tibble::tribble(
  ~role, ~file, ~table_name, ~table_id, ~api_url, ~local_value_col, ~local_raw_col, ~area_level,
  "schools", files$schools, "ЕРӨНХИЙ БОЛОВСРОЛЫН СУРГУУЛИЙН ТОО, аймаг, нийслэл, жилээр", "DT_NSO_2001_002V1", "https://data.1212.mn/api/v1/mn/NSO/Education,%20health/General%20educational%20schools/DT_NSO_2001_002V1.px", "schools", "raw_value", "aimag-year",
  "students", files$students, "ЕРӨНХИЙ БОЛОВСРОЛЫН СУРГУУЛЬД ӨДРӨӨР СУРАЛЦАГЧДЫН ТОО, аймаг, нийслэл, жилээр", "DT_NSO_2001_004V1", "https://data.1212.mn/api/v1/mn/NSO/Education,%20health/General%20educational%20schools/DT_NSO_2001_004V1.px", "students", "raw_value", "aimag-year",
  "teachers", files$teachers, "ЕРӨНХИЙ БОЛОВСРОЛЫН СУРГУУЛИЙН ҮНДСЭН БАГШ, аймаг, нийслэл, жилээр", "DT_NSO_2001_001V1", "https://data.1212.mn/api/v1/mn/NSO/Education,%20health/General%20educational%20schools/DT_NSO_2001_001V1.px", "teachers", "raw_value", "aimag-year",
  "population_age", files$population_age, "ХҮН АМЫН ТОО, хүйс, насны бүлэг, жилээр", "DT_NSO_0300_003V1", "https://data.1212.mn/api/v1/mn/NSO/Population,%20household/1_Population,%20household/DT_NSO_0300_003V1.px", "population", "population", "national sex-age-year",
  "annual_average_population", files$annual_average_population, "ЖИЛИЙН ДУНДАЖ ХҮН АМЫН ТОО, аймаг, нийслэл, жилээр", "DT_NSO_0300_002V1", "https://data.1212.mn/api/v1/mn/NSO/Population,%20household/1_Population,%20household/DT_NSO_0300_002V1.px", "annual_average_population", "raw_value", "aimag-year"
)

get_meta <- function(url) {
  tryCatch(jsonlite::fromJSON(url, simplifyVector = FALSE), error = function(e) structure(list(error = conditionMessage(e)), class = "px_error"))
}

meta_var <- function(meta, pattern) {
  vars <- meta$variables
  hit <- vars[vapply(vars, function(v) str_detect(v$text, pattern) || str_detect(v$code, pattern), logical(1))]
  if (length(hit) == 0) NULL else hit[[1]]
}

value_code <- function(var, value_text) {
  labs <- standardize_name(unlist(var$valueTexts))
  target <- standardize_name(value_text)
  idx <- match(target, labs)
  if (is.na(idx)) return(NA_character_)
  unlist(var$values)[[idx]]
}

year_code <- function(var, year) {
  idx <- match(as.character(year), as.character(unlist(var$valueTexts)))
  if (is.na(idx)) return(NA_character_)
  unlist(var$values)[[idx]]
}

px_query_value <- function(url, meta, area_name = NULL, year, sex = NULL, age_group = NULL) {
  vars <- meta$variables
  yvar <- vars[[length(vars)]]
  ycode <- year_code(yvar, year)
  if (is.na(ycode)) return(NA_real_)

  q <- list()
  for (v in vars) {
    code <- v$code
    txt <- v$text
    vals <- NULL
    if (identical(code, yvar$code)) {
      vals <- ycode
    } else if (str_detect(txt, "Бүс|Аймаг|Засаг")) {
      vals <- value_code(v, area_name)
    } else if (str_detect(txt, "Хүйс")) {
      vals <- value_code(v, sex)
    } else if (str_detect(txt, "Нас")) {
      vals <- value_code(v, age_group)
    }
    if (is.null(vals) || is.na(vals)) return(NA_real_)
    q <- append(q, list(list(code = code, selection = list(filter = "item", values = list(vals)))))
  }
  body <- jsonlite::toJSON(list(query = q, response = list(format = "JSON-stat2")), auto_unbox = TRUE)
  resp <- tryCatch(httr::POST(url, body = body, httr::content_type_json(), timeout(20)), error = function(e) e)
  if (inherits(resp, "error") || httr::status_code(resp) >= 300) return(NA_real_)
  js <- jsonlite::fromJSON(httr::content(resp, as = "text", encoding = "UTF-8"), simplifyVector = FALSE)
  val <- unlist(js$value)
  if (length(val) == 0) NA_real_ else as.numeric(val[[1]])
}

source_data <- list(
  schools = schools_raw %>% filter(!is.na(aimag_code)),
  students = students_raw %>% filter(!is.na(aimag_code)),
  teachers = teachers_raw %>% filter(!is.na(aimag_code)),
  annual_average_population = annual_pop_raw %>% filter(!is.na(aimag_code))
)

set.seed(1212)
verification_rows <- list()
for (i in seq_len(nrow(px_specs))) {
  spec <- px_specs[i, ]
  meta <- get_meta(spec$api_url)
  api_ok <- !inherits(meta, "px_error")
  title <- if (api_ok) meta$title else NA_character_
  dim_text <- if (api_ok) paste(vapply(meta$variables, function(v) paste0(v$text, "=", length(v$values)), character(1)), collapse = "; ") else NA_character_
  years <- NA_character_
  checks <- tibble()
  match_rate <- NA_real_

  if (api_ok) {
    yv <- meta$variables[[length(meta$variables)]]
    years <- paste(range(as.integer(unlist(yv$valueTexts)), na.rm = TRUE), collapse = "-")
    if (spec$role %in% names(source_data)) {
      loc <- source_data[[spec$role]] %>% filter(!is.na(raw_value)) %>% distinct(aimag_name, year, raw_value)
      loc <- loc %>% filter(year %in% as.integer(unlist(yv$valueTexts)))
      sample_n <- min(5, nrow(loc))
      sample_rows <- loc[sample(seq_len(nrow(loc)), sample_n), ]
      checks <- sample_rows %>%
        rowwise() %>%
        mutate(
          px_value = px_query_value(spec$api_url, meta, area_name = aimag_name, year = year),
          abs_diff = abs(raw_value - px_value),
          values_match = is.finite(abs_diff) & abs_diff < 1e-6
        ) %>%
        ungroup()
      match_rate <- mean(checks$values_match, na.rm = TRUE)
    } else if (spec$role == "population_age") {
      loc <- population_age %>% filter(sex == "Бүгд", age_group %in% c("5-9", "10-14", "15-19")) %>% distinct(sex, age_group, year, population)
      loc <- loc %>% filter(year %in% as.integer(unlist(yv$valueTexts)))
      sample_rows <- loc[sample(seq_len(nrow(loc)), min(5, nrow(loc))), ]
      checks <- sample_rows %>%
        rowwise() %>%
        mutate(
          px_value = px_query_value(spec$api_url, meta, year = year, sex = sex, age_group = age_group),
          abs_diff = abs(population - px_value),
          values_match = is.finite(abs_diff) & abs_diff < 1e-6,
          aimag_name = NA_character_,
          raw_value = population
        ) %>%
        ungroup()
      match_rate <- mean(checks$values_match, na.rm = TRUE)
    }
  }

  verification_rows[[i]] <- tibble(
    role = spec$role,
    excel_file = basename(spec$file),
    table_name = spec$table_name,
    table_id = spec$table_id,
    api_url = spec$api_url,
    api_access = ifelse(api_ok, "OK", "FAILED"),
    px_title = title,
    dimensions = dim_text,
    year_coverage_px = years,
    local_year_coverage = case_when(
      spec$role == "schools" ~ paste(range(schools$year, na.rm = TRUE), collapse = "-"),
      spec$role == "students" ~ paste(range(students$year, na.rm = TRUE), collapse = "-"),
      spec$role == "teachers" ~ paste(range(teachers$year, na.rm = TRUE), collapse = "-"),
      spec$role == "population_age" ~ paste(range(population_age$year, na.rm = TRUE), collapse = "-"),
      spec$role == "annual_average_population" ~ paste(range(annual_pop$year, na.rm = TRUE), collapse = "-"),
      TRUE ~ NA_character_
    ),
    value_check_summary = ifelse(api_ok, paste0(sum(checks$values_match, na.rm = TRUE), "/", nrow(checks), " random checks matched"), "API unavailable"),
    final_decision = ifelse(api_ok && !is.na(match_rate) && match_rate < 0.8, "DO NOT USE", "USE"),
    limitation = case_when(
      spec$role == "population_age" ~ "National-only age groups; not usable for aimag-level normalization.",
      spec$role == "annual_average_population" ~ "Aimag-level total population, not school-age population; saved as auxiliary only.",
      !api_ok ~ "API verification failed; using internally consistent Excel file.",
      TRUE ~ ""
    )
  )
  if (nrow(checks) > 0) {
    readr::write_csv(checks, file.path("output/logs", paste0("03a_px_value_checks_", spec$role, ".csv")))
  }
}

verification <- bind_rows(verification_rows)
readr::write_csv(verification, "output/logs/03a_manual_1212_excel_verification.csv")

report <- c(
  "# Manual 1212 Excel Verification",
  "",
  "Start page: https://data.1212.mn/pxweb/mn/NSO/",
  "",
  paste0(
    "## ", verification$role, "\n",
    "- Excel file: `", verification$excel_file, "`\n",
    "- Matching 1212 table name: ", verification$table_name, "\n",
    "- Matching 1212 table ID: ", verification$table_id, "\n",
    "- API URL: ", verification$api_url, "\n",
    "- API access: ", verification$api_access, "\n",
    "- PXWeb title: ", verification$px_title, "\n",
    "- Dimensions: ", verification$dimensions, "\n",
    "- Local year coverage: ", verification$local_year_coverage, "\n",
    "- PXWeb year coverage: ", verification$year_coverage_px, "\n",
    "- Random value checks: ", verification$value_check_summary, "\n",
    "- Final decision: ", verification$final_decision, "\n",
    ifelse(verification$limitation == "", "", paste0("- Limitation: ", verification$limitation, "\n"))
  )
)
writeLines(report, "output/reports/manual_1212_excel_verification.md", useBytes = TRUE)

cat("Saved data/cleaned/school_supply_panel.rds/csv\n")
cat("Saved output/reports/manual_1212_excel_verification.md\n")
cat("Saved output/tables/unmatched_aimag_names_school_supply.csv rows:", nrow(unmatched), "\n")
cat("03a complete.\n")
