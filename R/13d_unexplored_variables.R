# Build analysis-ready HSES hidden-variable candidate dataset.

options(warn = 1, encoding = "UTF-8")

required_pkgs <- c("haven", "dplyr", "stringr", "readr", "tibble", "purrr")
missing_pkgs <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_pkgs) > 0) stop("Missing packages: ", paste(missing_pkgs, collapse = ", "))

suppressPackageStartupMessages({
  library(haven)
  library(dplyr)
  library(stringr)
  library(readr)
  library(tibble)
  library(purrr)
})

dir.create("data/aux", recursive = TRUE, showWarnings = FALSE)
dir.create("output/tables", recursive = TRUE, showWarnings = FALSE)
dir.create("output/reports", recursive = TRUE, showWarnings = FALSE)
dir.create("output/logs", recursive = TRUE, showWarnings = FALSE)

sink("output/logs/13d_unexplored_variables.log", split = TRUE)
on.exit(sink(), add = TRUE)

cat("13d_unexplored_variables.R\n")
cat("Started:", as.character(Sys.time()), "\n\n")

num_zap <- function(x) {
  if (is.null(x)) return(NA_real_)
  suppressWarnings(as.numeric(haven::zap_labels(x)))
}

add_missing_cols <- function(df, cols) {
  for (cc in setdiff(cols, names(df))) df[[cc]] <- NA_real_
  df
}

read_indiv_extract <- function(path) {
  wave <- as.integer(str_extract(path, "20[0-9]{2}"))
  candidate_cols <- c(
    "identif", "ind_id",
    "q0114", "q0114a", "q0114b", "q0116", "q0117", "q0118", "q0118a", "q0118b",
    "q0119", "q0120", "q0121", "q0121a", "q0121b", "q0123", "q0124", "q0125", "q0125a", "q0125b",
    "q0215", "q0216", "q0217", "q0218", "q0220", "q0221", "q0222", "q0223",
    "q0303", paste0("q0324_", 1:6), paste0("q0326_", 1:8), paste0("q0328_", 1:6)
  )
  df <- read_dta(path)
  keep <- intersect(candidate_cols, names(df))
  out <- df %>% select(all_of(keep))
  out <- add_missing_cols(out, candidate_cols)
  out %>%
    mutate(
      wave = wave,
      across(-c(identif, ind_id, wave), num_zap),
      identif = as.character(identif),
      ind_id = as.character(ind_id)
    )
}

read_hhold_extract <- function(path) {
  wave <- as.integer(str_extract(path, "20[0-9]{2}"))
  df <- read_dta(path)
  keep <- intersect(c("identif", "q0601"), names(df))
  out <- df %>% select(all_of(keep))
  out <- add_missing_cols(out, c("identif", "q0601"))
  out %>%
    mutate(
      wave = wave,
      identif = as.character(identif),
      hhold_herder_q0601 = num_zap(q0601)
    ) %>%
    select(wave, identif, hhold_herder_q0601)
}

analysis_path <- "data/processed/analysis_sample.rds"
if (!file.exists(analysis_path)) stop("Missing ", analysis_path)
analysis <- readRDS(analysis_path)

indiv_files <- list.files("data", pattern = "dta$", recursive = TRUE, full.names = TRUE)
indiv_files <- indiv_files[str_detect(basename(indiv_files), regex("02_indiv", ignore_case = TRUE))]
indiv_files <- indiv_files[str_detect(indiv_files, "hses_20(20|21|22|23|24)")]
hhold_files <- list.files("data", pattern = "dta$", recursive = TRUE, full.names = TRUE)
hhold_files <- hhold_files[str_detect(basename(hhold_files), regex("01_hhold", ignore_case = TRUE))]
hhold_files <- hhold_files[str_detect(hhold_files, "hses_20(20|21|22|23|24)")]

raw_indiv <- map_dfr(indiv_files, read_indiv_extract)
raw_hhold <- map_dfr(hhold_files, read_hhold_extract)

cat("Raw individual extract rows:", nrow(raw_indiv), "\n")
cat("Raw household extract rows:", nrow(raw_hhold), "\n")

analysis2 <- analysis
if (!"id" %in% names(analysis2)) analysis2$id <- paste(analysis2$wave, analysis2$identif, analysis2$ind_id, sep = "-")
if (!"lwage" %in% names(analysis2)) {
  analysis2$lwage <- if ("ln_wage" %in% names(analysis2)) analysis2$ln_wage else NA_real_
}
if (!"age2" %in% names(analysis2)) analysis2$age2 <- analysis2$age^2
if (!"female" %in% names(analysis2)) {
  if ("is_female" %in% names(analysis2)) {
    analysis2$female <- as.numeric(analysis2$is_female)
  } else if ("sex" %in% names(analysis2)) {
    analysis2$female <- as.numeric(analysis2$sex == 2)
  } else {
    analysis2$female <- NA_real_
  }
}
if (!"married" %in% names(analysis2)) {
  if ("is_married" %in% names(analysis2)) {
    analysis2$married <- as.numeric(analysis2$is_married)
  } else if ("marital" %in% names(analysis2)) {
    analysis2$married <- as.numeric(analysis2$marital %in% c(1, 2))
  } else {
    analysis2$married <- NA_real_
  }
}
if (!"hhweight" %in% names(analysis2)) analysis2$hhweight <- NA_real_
if (!"urban" %in% names(analysis2)) analysis2$urban <- NA_real_

base <- analysis2 %>%
  mutate(
    wave = as.integer(wave),
    identif = as.character(identif),
    ind_id = as.character(ind_id),
    id = as.character(id),
    lwage = as.numeric(lwage),
    age2 = as.numeric(age2),
    female = as.numeric(female),
    married = as.numeric(married),
    urban = as.numeric(urban),
    hhweight = as.numeric(hhweight),
    birth_cohort = case_when(
      birth_year < 1970 ~ "pre1970",
      birth_year >= 1970 & birth_year <= 1974 ~ "1970_1974",
      birth_year >= 1975 & birth_year <= 1979 ~ "1975_1979",
      birth_year >= 1980 & birth_year <= 1984 ~ "1980_1984",
      birth_year >= 1985 & birth_year <= 1989 ~ "1985_1989",
      birth_year >= 1990 & birth_year <= 1994 ~ "1990_1994",
      birth_year >= 1995 ~ "post1995",
      TRUE ~ NA_character_
    )
  )

dat <- base %>%
  left_join(raw_indiv, by = c("wave", "identif", "ind_id")) %>%
  left_join(raw_hhold, by = c("wave", "identif"))

if (file.exists("data/processed/family_structure.rds")) {
  family <- readRDS("data/processed/family_structure.rds") %>%
    mutate(wave = as.integer(wave), identif = as.character(identif), ind_id = as.character(ind_id))
  dat <- dat %>% left_join(family, by = c("wave", "identif", "ind_id"), suffix = c("", "_family"))
  cat("Merged family_structure rows:", nrow(family), "\n")
} else {
  cat("No family_structure.rds found; family candidates skipped.\n")
}

make_yesno <- function(x, yes = 1, no = 2) {
  case_when(x == yes ~ 1, x == no ~ 0, TRUE ~ NA_real_)
}

dat <- dat %>%
  mutate(
    ever_migrated = case_when(
      wave %in% c(2020, 2021, 2022) ~ make_yesno(q0116),
      wave == 2024 ~ make_yesno(q0120),
      TRUE ~ NA_real_
    ),
    last_migration_year = case_when(
      wave %in% c(2020, 2021, 2022) ~ q0119,
      wave == 2024 ~ q0123,
      TRUE ~ NA_real_
    ),
    last_migration_year = if_else(last_migration_year >= 1900 & last_migration_year <= wave, last_migration_year, NA_real_),
    years_since_migration = wave - last_migration_year,
    migrated_before_18 = case_when(
      ever_migrated == 1 & !is.na(last_migration_year) & last_migration_year <= birth_year + 18 ~ 1,
      ever_migrated == 1 & !is.na(last_migration_year) ~ 0,
      ever_migrated == 0 ~ 0,
      TRUE ~ NA_real_
    ),
    migrated_school_age_6_17 = case_when(
      ever_migrated == 1 & !is.na(last_migration_year) & last_migration_year >= birth_year + 6 & last_migration_year <= birth_year + 17 ~ 1,
      ever_migrated == 1 & !is.na(last_migration_year) ~ 0,
      ever_migrated == 0 ~ 0,
      TRUE ~ NA_real_
    ),
    migration_reason_education_self = case_when(
      wave %in% c(2020, 2021, 2022) & q0120 == 3 ~ 1,
      wave == 2024 & q0124 == 5 ~ 1,
      !is.na(ever_migrated) ~ 0,
      TRUE ~ NA_real_
    ),
    migration_reason_children_school = case_when(
      wave %in% c(2020, 2021, 2022) & q0120 == 4 ~ 1,
      wave == 2024 & q0124 == 6 ~ 1,
      !is.na(ever_migrated) ~ 0,
      TRUE ~ NA_real_
    ),
    migration_reason_natural_disaster = case_when(
      wave == 2024 & q0124 == 9 ~ 1,
      wave == 2024 & !is.na(q0124) ~ 0,
      TRUE ~ NA_real_
    ),
    lived_5y_ago_aimag = case_when(
      wave %in% c(2020, 2021, 2022) ~ q0121a,
      wave == 2024 ~ q0125a,
      TRUE ~ NA_real_
    ),
    lived_5y_ago_diff_aimag = case_when(
      !is.na(lived_5y_ago_aimag) & !is.na(aimag) & lived_5y_ago_aimag != aimag ~ 1,
      !is.na(lived_5y_ago_aimag) & !is.na(aimag) ~ 0,
      TRUE ~ NA_real_
    ),
    born_foreign = case_when(
      wave %in% c(2020, 2021, 2022) ~ make_yesno(q0114, yes = 2, no = 1),
      wave == 2024 ~ make_yesno(q0118, yes = 2, no = 1),
      TRUE ~ NA_real_
    ),
    birthplace_aimag_raw = case_when(
      wave %in% c(2020, 2021, 2022) ~ q0114a,
      wave == 2024 ~ q0118a,
      TRUE ~ NA_real_
    ),
    birthplace_soum_raw = case_when(
      wave %in% c(2020, 2021, 2022) ~ q0114b,
      wave == 2024 ~ q0118b,
      TRUE ~ NA_real_
    ),
    birth_aimag_matches_raw = case_when(
      !is.na(birthplace_aimag_raw) & !is.na(birth_aimag) & birthplace_aimag_raw == birth_aimag ~ 1,
      !is.na(birthplace_aimag_raw) & !is.na(birth_aimag) ~ 0,
      TRUE ~ NA_real_
    ),
    birth_soum_available = case_when(!is.na(birth_soum) | !is.na(birthplace_soum_raw) ~ 1, TRUE ~ 0),
    rural_birth_proxy = case_when(!is.na(birth_aimag) & birth_aimag != 11 ~ 1, !is.na(birth_aimag) ~ 0, TRUE ~ NA_real_),
    born_ub = case_when(!is.na(birth_aimag) & birth_aimag == 11 ~ 1, !is.na(birth_aimag) ~ 0, TRUE ~ NA_real_),
    current_ub = case_when(!is.na(aimag) & aimag == 11 ~ 1, !is.na(aimag) ~ 0, TRUE ~ NA_real_),
    herder_household_current = make_yesno(hhold_herder_q0601),
    ever_dropout = make_yesno(q0215),
    dropout_grade = if_else(q0216 >= 1 & q0216 <= 12, q0216, NA_real_),
    dropout_reason_parent = as.numeric(q0217 == 3),
    dropout_reason_finance = as.numeric(q0217 == 7),
    dropout_reason_work = as.numeric(q0217 == 8),
    dropout_reason_health = as.numeric(q0217 == 9),
    dropout_reason_care = as.numeric(q0217 == 10),
    dropout_reason_distance = as.numeric(q0217 == 11),
    dropout_reason_migration = as.numeric(q0217 == 12),
    never_school_reason_parent = as.numeric(q0218 == 2),
    never_school_reason_finance = as.numeric(q0218 == 6),
    never_school_reason_work = as.numeric(q0218 == 7),
    never_school_reason_health = as.numeric(q0218 == 8),
    never_school_reason_care = as.numeric(q0218 == 9),
    never_school_reason_distance = as.numeric(q0218 == 10),
    never_school_reason_migration = as.numeric(q0218 == 11),
    never_school_reason_dorm_shortage = as.numeric(q0218 == 12),
    current_school_public = as.numeric(q0220 == 1),
    current_school_private = as.numeric(q0220 == 2),
    current_school_soum_center = as.numeric(q0221 == 3),
    current_school_capital = as.numeric(q0221 == 1),
    dormitory_current_student = as.numeric(q0222 == 3),
    lives_with_relatives_current_student = as.numeric(q0222 == 4),
    school_transport_walk = as.numeric(q0223 == 1),
    school_transport_boarding = as.numeric(q0223 == 7),
    health_insured = make_yesno(q0303),
    severe_vision_difficulty = as.numeric(q0328_1 %in% c(3, 4)),
    severe_hearing_difficulty = as.numeric(q0328_2 %in% c(3, 4)),
    severe_mobility_difficulty = as.numeric(q0328_3 %in% c(3, 4)),
    severe_cognitive_difficulty = as.numeric(q0328_4 %in% c(3, 4)),
    severe_selfcare_difficulty = as.numeric(q0328_5 %in% c(3, 4)),
    severe_language_difficulty = as.numeric(q0328_6 %in% c(3, 4)),
    any_severe_disability = as.numeric(rowSums(across(starts_with("severe_")), na.rm = TRUE) > 0),
    any_mildplus_disability = as.numeric(rowSums(across(q0328_1:q0328_6, ~ as.numeric(.x %in% c(2, 3, 4))), na.rm = TRUE) > 0),
    parent_educ_mean = if ("father_educ_years" %in% names(.)) rowMeans(cbind(father_educ_years, mother_educ_years), na.rm = TRUE) else NA_real_,
    parent_educ_mean = if_else(is.nan(parent_educ_mean), NA_real_, parent_educ_mean),
    large_sibship_ge4 = if ("n_siblings" %in% names(.)) as.numeric(n_siblings >= 4) else NA_real_,
    firstborn = if ("birth_order" %in% names(.)) as.numeric(birth_order == 1) else NA_real_,
    birth_year_c = birth_year - 1985,
    rural_birth_x_birth_year_c = rural_birth_proxy * birth_year_c,
    born_ub_x_birth_year_c = born_ub * birth_year_c,
    herder_current_x_birth_year_c = herder_household_current * birth_year_c,
    ever_migrated_x_birth_year_c = ever_migrated * birth_year_c,
    migrated_school_age_x_rural_birth = migrated_school_age_6_17 * rural_birth_proxy,
    diff_5y_aimag_x_birth_year_c = lived_5y_ago_diff_aimag * birth_year_c,
    dormitory_x_rural_birth = dormitory_current_student * rural_birth_proxy
  )

candidate_list <- tribble(
  ~iv_var, ~iv_name, ~expected_sign, ~source, ~exclusion_warning,
  "ever_migrated", "Ever migrated", "unknown", "HSES migration", "Migration is likely endogenous; diagnostic only",
  "years_since_migration", "Years since last migration", "unknown", "HSES migration", "Migration timing is likely endogenous",
  "migrated_before_18", "Migrated before age 18", "unknown", "HSES migration", "Retrospective migration; exclusion risk",
  "migrated_school_age_6_17", "Migrated during age 6-17", "unknown", "HSES migration", "Retrospective migration; exclusion risk",
  "migration_reason_education_self", "Migration reason: own education", "positive", "HSES migration", "Directly education-related; invalid as excluded IV",
  "migration_reason_children_school", "Migration reason: children school", "unknown", "HSES migration", "Household choice; exclusion risk",
  "migration_reason_natural_disaster", "Migration reason: natural disaster", "negative", "HSES migration 2024 only", "2024-only and migration selection",
  "lived_5y_ago_diff_aimag", "Different aimag 5 years ago", "unknown", "HSES migration", "Recent migration; not childhood for older cohorts",
  "born_foreign", "Born abroad", "unknown", "HSES birthplace", "Small cell likely",
  "birth_aimag_matches_raw", "Processed birth aimag matches raw birthplace", "unknown", "HSES validation", "Data-quality diagnostic only",
  "birth_soum_available", "Birth soum observed", "unknown", "HSES birthplace", "Availability indicator, not substantive shock",
  "rural_birth_x_birth_year_c", "Rural birth x cohort", "unknown", "Cohort x geography", "Interaction diagnostic; needs substantive shock story",
  "born_ub_x_birth_year_c", "UB birth x cohort", "unknown", "Cohort x geography", "Interaction diagnostic; needs substantive shock story",
  "herder_household_current", "Current household herder/livestock", "negative", "HSES household", "Current household status is endogenous",
  "herder_current_x_birth_year_c", "Herder household x cohort", "negative", "Cohort x household", "Current status and cohort interaction; exclusion risk",
  "ever_migrated_x_birth_year_c", "Migration x cohort", "unknown", "Cohort x migration", "Endogenous migration interaction",
  "migrated_school_age_x_rural_birth", "School-age migration x rural birth", "unknown", "Migration x geography", "Endogenous migration interaction",
  "diff_5y_aimag_x_birth_year_c", "5-year migration x cohort", "unknown", "Migration x cohort", "Recent migration, not childhood for older cohorts",
  "ever_dropout", "Ever dropped out of general school", "negative", "HSES schooling", "Post-treatment: not a valid IV",
  "dropout_grade", "Grade at dropout", "positive", "HSES schooling", "Post-treatment: not a valid IV",
  "dropout_reason_parent", "Dropout reason: parent", "negative", "HSES schooling", "Post-treatment: not a valid IV",
  "dropout_reason_finance", "Dropout reason: finance", "negative", "HSES schooling", "Post-treatment: not a valid IV",
  "dropout_reason_work", "Dropout reason: work", "negative", "HSES schooling", "Post-treatment: not a valid IV",
  "dropout_reason_health", "Dropout reason: health/disability", "negative", "HSES schooling", "Post-treatment and direct health channel",
  "dropout_reason_distance", "Dropout reason: school too far", "negative", "HSES schooling", "Post-treatment; mechanism only",
  "dropout_reason_migration", "Dropout reason: migration", "negative", "HSES schooling", "Post-treatment; mechanism only",
  "never_school_reason_finance", "Never school: finance", "negative", "HSES schooling", "Post-treatment/education outcome reason",
  "never_school_reason_distance", "Never school: school too far", "negative", "HSES schooling", "Post-treatment/education outcome reason",
  "never_school_reason_dorm_shortage", "Never school: dorm shortage", "negative", "HSES schooling", "Post-treatment/education outcome reason",
  "current_school_public", "Current student: public school", "unknown", "HSES current school", "Current student only; low adult wage coverage",
  "current_school_private", "Current student: private school", "positive", "HSES current school", "Current student only; low adult wage coverage",
  "current_school_soum_center", "Current student: school in soum center", "unknown", "HSES current school", "Current student only",
  "dormitory_current_student", "Current student: dormitory", "positive", "HSES current school", "Current student only; not adult childhood exposure",
  "school_transport_walk", "Current student: walks to school", "unknown", "HSES current school", "Current student only",
  "school_transport_boarding", "Current student: transport=dorm", "positive", "HSES current school", "Current student only",
  "health_insured", "Health insured", "positive", "HSES health", "Current health insurance; endogenous",
  "severe_vision_difficulty", "Severe vision difficulty", "negative", "HSES disability", "Current disability; direct wage channel",
  "severe_hearing_difficulty", "Severe hearing difficulty", "negative", "HSES disability", "Current disability; direct wage channel",
  "severe_mobility_difficulty", "Severe mobility difficulty", "negative", "HSES disability", "Current disability; direct wage channel",
  "severe_cognitive_difficulty", "Severe cognitive difficulty", "negative", "HSES disability", "Current disability; direct wage channel",
  "severe_language_difficulty", "Severe language communication difficulty", "negative", "HSES language/disability", "Not ethnicity; direct channels possible",
  "any_severe_disability", "Any severe disability", "negative", "HSES disability", "Current disability; direct wage channel",
  "any_mildplus_disability", "Any mild+ disability", "negative", "HSES disability", "Current disability; direct wage channel",
  "father_educ_years", "Father education years", "positive", "Family roster", "Strong first stage possible but exclusion restriction caveat",
  "mother_educ_years", "Mother education years", "positive", "Family roster", "Strong first stage possible but exclusion restriction caveat",
  "parent_educ_mean", "Mean parent education years", "positive", "Family roster", "Strong first stage possible but exclusion restriction caveat",
  "n_siblings", "Number of siblings", "negative", "Family roster", "Family size exclusion caveat",
  "birth_order", "Birth order", "negative", "Family roster", "Family composition exclusion caveat",
  "large_sibship_ge4", "At least 4 siblings", "negative", "Family roster", "Family size exclusion caveat",
  "firstborn", "Firstborn", "positive", "Family roster", "Family composition exclusion caveat"
) %>%
  filter(iv_var %in% names(dat)) %>%
  mutate(
    n_nonmissing = map_int(iv_var, ~ sum(!is.na(dat[[.x]]))),
    n_unique = map_int(iv_var, ~ n_distinct(dat[[.x]], na.rm = TRUE)),
    mean_value = map_dbl(iv_var, ~ suppressWarnings(mean(dat[[.x]], na.rm = TRUE))),
    hidden_gem = iv_var %in% c("migrated_school_age_6_17", "migration_reason_natural_disaster",
                               "dropout_reason_distance", "never_school_reason_dorm_shortage",
                               "dormitory_current_student", "birth_soum_available")
  )

saveRDS(dat, "data/aux/new_iv_candidate_data.rds")
write_csv(candidate_list, "data/aux/new_iv_candidate_list.csv")
write_csv(candidate_list, "output/tables/T2e_unexplored_variable_candidates.csv")

scan_nso_candidates <- function() {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    return(tibble(status = "API_NOT_CHECKED", reason = "jsonlite package not available"))
  }
  root <- "https://data.1212.mn/api/v1/mn/NSO"
  keywords <- regex("аж үйлдвэр|днб|уул уурхай|зам|эмнэл|хөрөнгө оруулалт|мал|кооператив|industrial|gdp|mining|road|hospital|investment", ignore_case = TRUE)
  found <- list()
  seen <- character()
  max_nodes <- 120
  node_count <- 0
  walk <- function(url, path_text = "NSO", depth = 0) {
    if (node_count > max_nodes || depth > 3 || url %in% seen) return(invisible(NULL))
    seen <<- c(seen, url)
    node_count <<- node_count + 1
    js <- tryCatch(jsonlite::fromJSON(url), error = function(e) e)
    if (inherits(js, "error")) {
      found[[length(found) + 1]] <<- tibble(status = "API_ERROR", path = path_text, table_id = NA_character_, text = conditionMessage(js), url = url)
      return(invisible(NULL))
    }
    if (!is.data.frame(js)) return(invisible(NULL))
    nm <- names(js)
    id_col <- intersect(c("id", "ID", "code"), nm)[1]
    text_col <- intersect(c("text", "Text", "title"), nm)[1]
    type_col <- intersect(c("type", "Type"), nm)[1]
    if (is.na(id_col) || is.na(text_col)) return(invisible(NULL))
    for (i in seq_len(nrow(js))) {
      id <- as.character(js[[id_col]][i])
      txt <- as.character(js[[text_col]][i])
      typ <- if (!is.na(type_col)) as.character(js[[type_col]][i]) else ""
      next_url <- paste0(url, "/", utils::URLencode(id, reserved = TRUE))
      if (str_detect(paste(path_text, txt), keywords) || typ == "t") {
        found[[length(found) + 1]] <<- tibble(status = "FOUND_OR_TABLE", path = path_text, table_id = id, text = txt, type = typ, url = next_url)
      }
      if (depth < 3 && typ != "t") walk(next_url, paste(path_text, txt, sep = " / "), depth + 1)
    }
  }
  tryCatch(walk(root), error = function(e) {
    found[[length(found) + 1]] <<- tibble(status = "API_ERROR", path = "NSO", table_id = NA_character_, text = conditionMessage(e), url = root)
  })
  if (length(found) == 0) tibble(status = "NO_MATCH", reason = "No candidate NSO tables found in limited scan") else bind_rows(found)
}

nso_candidates <- scan_nso_candidates()
write_csv(nso_candidates, "data/aux/nso_candidate_tables.csv")

report_lines <- c(
  "# Unexplored HSES Variable Candidates",
  "",
  paste0("Generated: ", Sys.time()),
  "",
  paste0("Analysis rows: ", nrow(dat)),
  paste0("Candidate variables created: ", nrow(candidate_list)),
  "",
  "## Hidden Gems",
  ""
)
hidden <- candidate_list %>% filter(hidden_gem)
if (nrow(hidden) == 0) {
  report_lines <- c(report_lines, "no relevant variable found", "")
} else {
  report_lines <- c(report_lines, paste0("- ", hidden$iv_var, ": ", hidden$iv_name, " (", hidden$exclusion_warning, ")"), "")
}
report_lines <- c(
  report_lines,
  "## Candidate Summary",
  paste0("- ", candidate_list$iv_var, ": nonmissing=", candidate_list$n_nonmissing,
         ", unique=", candidate_list$n_unique, ", expected_sign=", candidate_list$expected_sign),
  "",
  "## NSO API Candidate Scan",
  paste0("Rows saved: ", nrow(nso_candidates)),
  "See data/aux/nso_candidate_tables.csv."
)
writeLines(report_lines, "output/reports/unexplored_variables_scan.md", useBytes = TRUE)

cat("Candidate variables:", nrow(candidate_list), "\n")
print(candidate_list %>% arrange(desc(hidden_gem), desc(n_nonmissing)) %>% select(iv_var, expected_sign, n_nonmissing, n_unique, hidden_gem), n = Inf)
cat("\n13d complete.\n")
