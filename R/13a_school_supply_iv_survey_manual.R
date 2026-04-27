# Survey manually downloaded school-supply IV candidates for educ_years.

options(warn = 1)

required_pkgs <- c("dplyr", "tidyr", "stringr", "readr", "tibble", "purrr", "haven", "fixest")
missing_pkgs <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_pkgs) > 0) stop("Missing required packages: ", paste(missing_pkgs, collapse = ", "))

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(readr)
  library(tibble)
  library(purrr)
  library(haven)
  library(fixest)
})

root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
dir.create("output/tables", showWarnings = FALSE, recursive = TRUE)
dir.create("output/reports", showWarnings = FALSE, recursive = TRUE)
dir.create("output/logs", showWarnings = FALSE, recursive = TRUE)
dir.create("data/cleaned", showWarnings = FALSE, recursive = TRUE)

sink("output/logs/13a_school_supply_iv_survey_manual.log", split = TRUE)
on.exit(sink(), add = TRUE)

cat("13a_school_supply_iv_survey_manual.R\n")
cat("Root:", root, "\n\n")

to_num <- function(x) {
  if (inherits(x, "haven_labelled")) x <- haven::zap_labels(x)
  suppressWarnings(as.numeric(x))
}

pick_first <- function(nms, candidates) {
  hit <- candidates[candidates %in% nms]
  if (length(hit) == 0) NA_character_ else hit[[1]]
}

read_candidate <- function(path, n_max = Inf) {
  ext <- tolower(tools::file_ext(path))
  if (ext == "rds") {
    x <- readRDS(path)
    if (is.data.frame(x)) return(x)
    return(NULL)
  }
  if (ext == "csv") return(readr::read_csv(path, show_col_types = FALSE, n_max = n_max))
  if (ext == "dta") return(haven::read_dta(path, n_max = if (is.infinite(n_max)) Inf else n_max))
  if (ext == "sav") return(haven::read_sav(path, n_max = if (is.infinite(n_max)) Inf else n_max))
  NULL
}

score_hses <- function(path) {
  tryCatch({
    x <- read_candidate(path, n_max = 200)
    if (is.null(x)) return(tibble(path = path, score = -1, n_cols = NA_integer_))
    nms <- names(x)
    groups <- list(
      educ = c("educ_years", "education_years", "years_educ"),
      wage = c("lwage", "ln_wage", "log_wage", "real_hourly", "nominal_hourly", "wage"),
      birth_year = c("birth_year", "byear", "birthyear"),
      birth_aimag = c("birth_aimag", "birthplace_aimag"),
      age = c("age", "q0105y"),
      sex = c("female", "is_female", "sex"),
      married = c("married", "is_married", "marital"),
      urban = c("urban"),
      weight = c("hhweight", "weight"),
      wave = c("wave", "survey_year", "year")
    )
    hits <- vapply(groups, function(v) any(v %in% nms), logical(1))
    score <- sum(hits) + ifelse(grepl("analysis_sample", basename(path), ignore.case = TRUE), 5, 0)
    tibble(path = path, score = score, n_cols = length(nms))
  }, error = function(e) tibble(path = path, score = -1, n_cols = NA_integer_))
}

candidate_files <- list.files(".", pattern = "\\.(rds|csv|dta|sav)$", recursive = TRUE, full.names = TRUE)
candidate_files <- candidate_files[!grepl("(^|/)(renv|\\.git|codex)(/|$)", normalizePath(candidate_files, winslash = "/", mustWork = FALSE))]
candidate_files <- candidate_files[grepl("hses|analysis|processed|raw", candidate_files, ignore.case = TRUE)]
scores <- map_dfr(candidate_files, score_hses) %>% arrange(desc(score), path)
readr::write_csv(scores, "output/logs/13a_hses_candidate_scores.csv")
if (nrow(scores) == 0 || max(scores$score, na.rm = TRUE) < 6) stop("No usable HSES analysis file found.")

hses_path <- scores$path[[which.max(scores$score)]]
hses_raw <- read_candidate(hses_path)
cat("Selected HSES:", hses_path, "\n")
cat("Columns:\n", paste(names(hses_raw), collapse = ", "), "\n\n")

nms <- names(hses_raw)
mapping <- c(
  id = pick_first(nms, c("id", "person_id", "pid")),
  identif = pick_first(nms, c("identif", "household_id", "hhid")),
  ind_id = pick_first(nms, c("ind_id", "person_no")),
  educ_years = pick_first(nms, c("educ_years", "education_years", "years_educ")),
  lwage = pick_first(nms, c("lwage", "ln_wage", "log_wage", "ln_real_hourly", "ln_nominal_hourly")),
  wage = pick_first(nms, c("real_hourly", "nominal_hourly", "wage", "hourly_wage", "monthly_wage")),
  birth_year = pick_first(nms, c("birth_year", "byear", "birthyear")),
  birth_aimag = pick_first(nms, c("birth_aimag", "birthplace_aimag")),
  age = pick_first(nms, c("age", "q0105y")),
  age2 = pick_first(nms, c("age2")),
  female = pick_first(nms, c("female", "is_female", "sex")),
  married = pick_first(nms, c("married", "is_married", "marital")),
  urban = pick_first(nms, c("urban")),
  hhweight = pick_first(nms, c("hhweight", "weight", "household_weight")),
  wave = pick_first(nms, c("wave", "survey_year", "year")),
  region = pick_first(nms, c("region", "region_f"))
)
readr::write_csv(tibble(standard_name = names(mapping), source_name = unname(mapping)), "output/logs/13a_hses_variable_mapping.csv")

must <- c("educ_years", "birth_year", "birth_aimag", "age", "wave")
miss <- must[is.na(mapping[must])]
if (length(miss) > 0) stop("Missing required HSES variables: ", paste(miss, collapse = ", "))
if (is.na(mapping[["lwage"]]) && is.na(mapping[["wage"]])) stop("Missing wage/lwage variable.")

get_col <- function(df, nm) if (is.na(nm)) rep(NA, nrow(df)) else df[[nm]]
id_val <- if (!is.na(mapping[["id"]])) {
  as.character(get_col(hses_raw, mapping[["id"]]))
} else if (!is.na(mapping[["identif"]]) && !is.na(mapping[["ind_id"]])) {
  paste(get_col(hses_raw, mapping[["wave"]]), get_col(hses_raw, mapping[["identif"]]), get_col(hses_raw, mapping[["ind_id"]]), sep = "-")
} else as.character(seq_len(nrow(hses_raw)))

wage <- if (!is.na(mapping[["wage"]])) to_num(get_col(hses_raw, mapping[["wage"]])) else rep(NA_real_, nrow(hses_raw))
lwage <- if (!is.na(mapping[["lwage"]])) to_num(get_col(hses_raw, mapping[["lwage"]])) else rep(NA_real_, nrow(hses_raw))
if (all(is.na(lwage)) && any(is.finite(wage) & wage > 0)) lwage <- ifelse(is.finite(wage) & wage > 0, log(wage), NA_real_)
if (all(is.na(wage)) && any(is.finite(lwage))) wage <- exp(lwage)

female_src <- to_num(get_col(hses_raw, mapping[["female"]]))
female <- if (!is.na(mapping[["female"]]) && mapping[["female"]] %in% c("female", "is_female")) {
  as.integer(female_src == 1)
} else if (all(na.omit(unique(female_src)) %in% c(0, 1))) {
  as.integer(female_src == 1)
} else as.integer(female_src == 2)

married_src <- to_num(get_col(hses_raw, mapping[["married"]]))
married <- if (!is.na(mapping[["married"]]) && mapping[["married"]] %in% c("married", "is_married")) {
  as.integer(married_src == 1)
} else as.integer(married_src == 2)

urban_src <- to_num(get_col(hses_raw, mapping[["urban"]]))
urban <- if (all(na.omit(unique(urban_src)) %in% c(0, 1))) as.integer(urban_src == 1) else as.integer(urban_src == 1)

age <- to_num(get_col(hses_raw, mapping[["age"]]))
age2 <- if (!is.na(mapping[["age2"]])) to_num(get_col(hses_raw, mapping[["age2"]])) else age^2
hhweight <- if (!is.na(mapping[["hhweight"]])) to_num(get_col(hses_raw, mapping[["hhweight"]])) else rep(1, nrow(hses_raw))
hhweight <- ifelse(is.finite(hhweight) & hhweight > 0, hhweight, 1)

hses <- tibble(
  id = id_val,
  educ_years = to_num(get_col(hses_raw, mapping[["educ_years"]])),
  lwage = lwage,
  wage = wage,
  birth_year = as.integer(to_num(get_col(hses_raw, mapping[["birth_year"]]))),
  birth_aimag = as.integer(to_num(get_col(hses_raw, mapping[["birth_aimag"]]))),
  age = age,
  age2 = age2,
  female = female,
  married = married,
  urban = urban,
  hhweight = hhweight,
  wave = as.integer(to_num(get_col(hses_raw, mapping[["wave"]]))),
  region = if (!is.na(mapping[["region"]])) as.character(get_col(hses_raw, mapping[["region"]])) else NA_character_
) %>%
  filter(
    age >= 25, age <= 60,
    is.finite(lwage) | (is.finite(wage) & wage > 0),
    !is.na(educ_years),
    !is.na(birth_year),
    !is.na(birth_aimag)
  ) %>%
  mutate(
    lwage = ifelse(is.finite(lwage), lwage, log(wage)),
    row_id = row_number(),
    birth_cohort = case_when(
      birth_year < 1970 ~ "pre1970",
      birth_year >= 1970 & birth_year <= 1974 ~ "1970_1974",
      birth_year >= 1975 & birth_year <= 1979 ~ "1975_1979",
      birth_year >= 1980 & birth_year <= 1984 ~ "1980_1984",
      birth_year >= 1985 & birth_year <= 1989 ~ "1985_1989",
      birth_year >= 1990 & birth_year <= 1994 ~ "1990_1994",
      birth_year >= 1995 ~ "post1995",
      TRUE ~ NA_character_
    ),
    birth_cohort = factor(birth_cohort, levels = c("pre1970", "1970_1974", "1975_1979", "1980_1984", "1985_1989", "1990_1994", "post1995")),
    year_at_7 = birth_year + 7L,
    year_at_12 = birth_year + 12L,
    year_at_15 = birth_year + 15L,
    year_at_17 = birth_year + 17L
  )

panel <- readRDS("data/cleaned/school_supply_panel.rds") %>%
  mutate(aimag_code = as.integer(aimag_code), year = as.integer(year))

hses <- hses %>%
  filter(birth_aimag %in% unique(panel$aimag_code)) %>%
  mutate(row_id = row_number())

exposure_vars <- c(
  "school_density_student", "students_per_school", "teachers_per_student",
  "student_teacher_ratio", "school_closure_rate", "school_growth_rate",
  "school_density_pop", "teachers_per_1000_children", "students_per_1000_children"
)
exposure_vars <- exposure_vars[exposure_vars %in% names(panel)]

add_point <- function(df, age_num) {
  join_panel <- panel %>%
    select(aimag_code, year, all_of(exposure_vars)) %>%
    rename_with(~ paste0(.x, "_at_", age_num), all_of(exposure_vars))
  df %>%
    left_join(join_panel, by = setNames(c("aimag_code", "year"), c("birth_aimag", paste0("year_at_", age_num))))
}

analysis <- hses %>%
  add_point(12) %>%
  add_point(15) %>%
  add_point(17)

cum_panel <- panel %>%
  select(aimag_code, year, all_of(exposure_vars))

cum_exposure <- hses %>%
  select(row_id, birth_aimag, birth_year) %>%
  tidyr::crossing(age_school = 7:15) %>%
  mutate(year = birth_year + age_school) %>%
  left_join(cum_panel, by = c("birth_aimag" = "aimag_code", "year" = "year")) %>%
  group_by(row_id) %>%
  summarise(
    n_density_student = sum(!is.na(school_density_student)),
    cumulative_school_closure_age7_15 = ifelse(sum(!is.na(school_closure_rate)) == 9, sum(school_closure_rate, na.rm = TRUE), NA_real_),
    cumulative_school_growth_age7_15 = ifelse(sum(!is.na(school_growth_rate)) == 9, sum(school_growth_rate, na.rm = TRUE), NA_real_),
    mean_school_density_student_age7_15 = ifelse(sum(!is.na(school_density_student)) == 9, mean(school_density_student, na.rm = TRUE), NA_real_),
    mean_teachers_per_student_age7_15 = ifelse(sum(!is.na(teachers_per_student)) == 9, mean(teachers_per_student, na.rm = TRUE), NA_real_),
    mean_students_per_school_age7_15 = ifelse(sum(!is.na(students_per_school)) == 9, mean(students_per_school, na.rm = TRUE), NA_real_),
    mean_student_teacher_ratio_age7_15 = ifelse(sum(!is.na(student_teacher_ratio)) == 9, mean(student_teacher_ratio, na.rm = TRUE), NA_real_),
    mean_school_density_pop_age7_15 = ifelse(sum(!is.na(school_density_pop)) == 9, mean(school_density_pop, na.rm = TRUE), NA_real_),
    mean_teachers_per_1000_children_age7_15 = ifelse(sum(!is.na(teachers_per_1000_children)) == 9, mean(teachers_per_1000_children, na.rm = TRUE), NA_real_),
    .groups = "drop"
  )

analysis <- analysis %>% left_join(cum_exposure, by = "row_id")
saveRDS(analysis, "data/cleaned/hses_school_supply_exposure_manual.rds")

controls <- c("age", "age2", "female", "married", "urban")
controls <- controls[controls %in% names(analysis)]
region_available <- "region" %in% names(analysis) && n_distinct(na.omit(analysis$region)) > 1

iv_specs <- tibble::tribble(
  ~iv_name, ~iv_var, ~expected_sign, ~notes,
  "school density per 1000 students at age 12", "school_density_student_at_12", "positive", "",
  "school density per 1000 students at age 15", "school_density_student_at_15", "positive", "",
  "school density per 1000 students at age 17", "school_density_student_at_17", "positive", "",
  "students per school at age 12", "students_per_school_at_12", "negative", "",
  "students per school at age 15", "students_per_school_at_15", "negative", "",
  "students per school at age 17", "students_per_school_at_17", "negative", "",
  "teachers per student at age 12", "teachers_per_student_at_12", "positive", "",
  "teachers per student at age 15", "teachers_per_student_at_15", "positive", "",
  "teachers per student at age 17", "teachers_per_student_at_17", "positive", "",
  "student teacher ratio at age 12", "student_teacher_ratio_at_12", "negative", "",
  "student teacher ratio at age 15", "student_teacher_ratio_at_15", "negative", "",
  "student teacher ratio at age 17", "student_teacher_ratio_at_17", "negative", "",
  "school closure rate at age 12", "school_closure_rate_at_12", "negative", "",
  "school closure rate at age 15", "school_closure_rate_at_15", "negative", "",
  "school closure rate at age 17", "school_closure_rate_at_17", "negative", "",
  "school growth rate at age 12", "school_growth_rate_at_12", "positive", "",
  "school growth rate at age 15", "school_growth_rate_at_15", "positive", "",
  "school growth rate at age 17", "school_growth_rate_at_17", "positive", "",
  "cumulative school closure age 7-15", "cumulative_school_closure_age7_15", "negative", "requires complete age 7-15 panel",
  "cumulative school growth age 7-15", "cumulative_school_growth_age7_15", "positive", "requires complete age 7-15 panel",
  "mean school density per 1000 students age 7-15", "mean_school_density_student_age7_15", "positive", "requires complete age 7-15 panel",
  "mean teachers per student age 7-15", "mean_teachers_per_student_age7_15", "positive", "requires complete age 7-15 panel",
  "mean students per school age 7-15", "mean_students_per_school_age7_15", "negative", "requires complete age 7-15 panel",
  "mean student teacher ratio age 7-15", "mean_student_teacher_ratio_age7_15", "negative", "requires complete age 7-15 panel"
)

if (any(is.finite(panel$school_density_pop))) {
  iv_specs <- bind_rows(iv_specs, tibble::tribble(
    ~iv_name, ~iv_var, ~expected_sign, ~notes,
    "school density per school-age population at age 12", "school_density_pop_at_12", "positive", "",
    "school density per school-age population at age 15", "school_density_pop_at_15", "positive", "",
    "school density per school-age population at age 17", "school_density_pop_at_17", "positive", "",
    "teachers per 1000 children at age 12", "teachers_per_1000_children_at_12", "positive", "",
    "teachers per 1000 children at age 15", "teachers_per_1000_children_at_15", "positive", "",
    "teachers per 1000 children at age 17", "teachers_per_1000_children_at_17", "positive", "",
    "mean school density per school-age population age 7-15", "mean_school_density_pop_age7_15", "positive", "requires complete age 7-15 panel",
    "mean teachers per 1000 children age 7-15", "mean_teachers_per_1000_children_age7_15", "positive", "requires complete age 7-15 panel"
  ))
}
iv_specs <- iv_specs %>% filter(iv_var %in% names(analysis))

coef_row <- function(fit, term) {
  ct <- as.data.frame(coeftable(fit))
  ct$term <- rownames(ct)
  hit <- ct[ct$term == term, , drop = FALSE]
  if (nrow(hit) == 0) return(NULL)
  p_col <- grep("^Pr\\(", names(hit), value = TRUE)
  list(estimate = hit$Estimate[[1]], se = hit[["Std. Error"]][[1]], p = if (length(p_col) > 0) hit[[p_col[[1]]]][[1]] else NA_real_)
}

fit_safe <- function(fml, data) {
  args <- list(fml = fml, data = data, notes = FALSE)
  if ("hhweight" %in% names(data)) args$weights <- ~hhweight
  if ("birth_aimag" %in% names(data) && n_distinct(na.omit(data$birth_aimag)) > 1) {
    args$vcov <- ~birth_aimag
    fit <- tryCatch(do.call(feols, args), error = function(e) e)
    if (!inherits(fit, "error")) return(list(fit = fit, vcov = "cluster_birth_aimag"))
  }
  args$vcov <- "hetero"
  fit <- tryCatch(do.call(feols, args), error = function(e) e)
  if (inherits(fit, "error")) return(list(fit = NULL, vcov = "failed", error = conditionMessage(fit)))
  list(fit = fit, vcov = "hetero")
}

sign_ok_fun <- function(pi_hat, expected_sign) {
  if (is.na(pi_hat)) return(NA)
  if (expected_sign == "positive") pi_hat > 0 else pi_hat < 0
}

verdict_fun <- function(pi_hat, F_first, sign_ok, usable = TRUE) {
  if (!usable || is.na(pi_hat) || is.na(F_first) || is.na(sign_ok)) return("COLLINEAR_USELESS")
  if (!sign_ok) return("WRONG_SIGN")
  if (F_first >= 10) return("STRONG")
  if (F_first >= 5) return("MARGINAL")
  "WEAK"
}

run_iv <- function(iv_name, iv_var, expected_sign, notes, fe_formula = "birth_aimag + birth_cohort + wave", do_2sls = TRUE) {
  needed <- unique(c("educ_years", "lwage", iv_var, controls, trimws(unlist(strsplit(fe_formula, "\\+"))), "birth_aimag", "hhweight"))
  needed <- needed[needed %in% names(analysis)]
  df <- analysis %>%
    filter(if_all(all_of(needed), ~ !is.na(.x))) %>%
    filter(is.finite(educ_years), is.finite(.data[[iv_var]]))

  empty <- tibble(
    iv_name = iv_name, iv_var = iv_var, pi_hat = NA_real_, pi_p = NA_real_, F_first = NA_real_,
    beta_2sls = NA_real_, se_2sls = NA_real_, N = nrow(df), expected_sign = expected_sign,
    sign_ok = NA, verdict = "COLLINEAR_USELESS", notes = paste(notes, "no usable variation")
  )
  if (nrow(df) < 100 || n_distinct(df[[iv_var]]) < 2) return(empty)

  rhs <- paste(c(iv_var, controls), collapse = " + ")
  fs <- fit_safe(as.formula(paste0("educ_years ~ ", rhs, " | ", fe_formula)), df)
  if (is.null(fs$fit)) return(empty %>% mutate(notes = paste(notes, "first-stage failed", fs$error)))
  cr <- coef_row(fs$fit, iv_var)
  if (is.null(cr) || is.na(cr$se) || cr$se == 0) return(empty %>% mutate(notes = paste(notes, "IV collinear/dropped")))

  pi_hat <- cr$estimate
  F_first <- (pi_hat / cr$se)^2
  sign_ok <- sign_ok_fun(pi_hat, expected_sign)

  beta_2sls <- NA_real_
  se_2sls <- NA_real_
  if (do_2sls) {
    rhs_iv <- if (length(controls) == 0) "1" else paste(controls, collapse = " + ")
    ivfit <- fit_safe(as.formula(paste0("lwage ~ ", rhs_iv, " | ", fe_formula, " | educ_years ~ ", iv_var)), df)
    if (!is.null(ivfit$fit)) {
      endog <- names(coef(ivfit$fit))[grepl("educ_years", names(coef(ivfit$fit)))][1]
      if (!is.na(endog)) {
        ivcr <- coef_row(ivfit$fit, endog)
        if (!is.null(ivcr)) {
          beta_2sls <- ivcr$estimate
          se_2sls <- ivcr$se
        }
      }
    }
  }

  tibble(
    iv_name = iv_name,
    iv_var = iv_var,
    pi_hat = pi_hat,
    pi_p = cr$p,
    F_first = F_first,
    beta_2sls = beta_2sls,
    se_2sls = se_2sls,
    N = nobs(fs$fit),
    expected_sign = expected_sign,
    sign_ok = sign_ok,
    verdict = verdict_fun(pi_hat, F_first, sign_ok, usable = TRUE),
    notes = str_squish(paste(notes, "vcov:", fs$vcov))
  )
}

survey <- pmap_dfr(iv_specs, run_iv) %>% arrange(desc(F_first))
readr::write_csv(survey, "output/tables/T2d_school_supply_iv_survey_manual.csv")

top10 <- survey %>% filter(!is.na(F_first)) %>% arrange(desc(F_first)) %>% slice_head(n = 10)

diag_fe <- tibble::tribble(
  ~fe_design, ~fe_formula,
  "birth_aimag + wave", "birth_aimag + wave",
  "birth_aimag + birth_cohort + wave", "birth_aimag + birth_cohort + wave",
  "birth_aimag + birth_year + wave", "birth_aimag + birth_year + wave"
)
if (region_available) {
  diag_fe <- bind_rows(tibble(fe_design = "region + wave", fe_formula = "region + wave"), diag_fe)
}

run_diag <- function(iv_name, iv_var, expected_sign, notes, fe_design, fe_formula) {
  out <- run_iv(iv_name, iv_var, expected_sign, notes, fe_formula = fe_formula, do_2sls = FALSE)
  out %>% mutate(fe_design = fe_design, .before = pi_hat) %>% select(iv_name, iv_var, fe_design, pi_hat, pi_p, F_first, N, expected_sign, sign_ok, verdict, notes)
}

fe_diag <- top10 %>%
  select(iv_name, iv_var, expected_sign, notes) %>%
  crossing(diag_fe) %>%
  pmap_dfr(run_diag)
readr::write_csv(fe_diag, "output/tables/T2d_school_supply_fe_diagnostics_manual.csv")

variance_absorbed <- function(iv_var, fe_label, fe_formula) {
  fe_vars <- trimws(unlist(strsplit(fe_formula, "\\+")))
  needed <- unique(c(iv_var, fe_vars, "hhweight"))
  needed <- needed[needed %in% names(analysis)]
  df <- analysis %>% filter(if_all(all_of(needed), ~ !is.na(.x))) %>% filter(is.finite(.data[[iv_var]]))
  if (nrow(df) < 100 || n_distinct(df[[iv_var]]) < 2) {
    return(tibble(iv_var = iv_var, absorbed_by = fe_label, N = nrow(df), r2_absorbed = NA_real_))
  }
  args <- list(fml = as.formula(paste0(iv_var, " ~ 1 | ", fe_formula)), data = df, notes = FALSE)
  if ("hhweight" %in% names(df)) args$weights <- ~hhweight
  fit <- tryCatch(do.call(feols, args), error = function(e) NULL)
  if (is.null(fit)) return(tibble(iv_var = iv_var, absorbed_by = fe_label, N = nrow(df), r2_absorbed = NA_real_))
  y <- df[[iv_var]]
  w <- if ("hhweight" %in% names(df)) df$hhweight else rep(1, nrow(df))
  ybar <- weighted.mean(y, w, na.rm = TRUE)
  tss <- sum(w * (y - ybar)^2, na.rm = TRUE)
  rss <- sum(w * residuals(fit)^2, na.rm = TRUE)
  tibble(iv_var = iv_var, absorbed_by = fe_label, N = nobs(fit), r2_absorbed = ifelse(tss > 0, 1 - rss / tss, NA_real_))
}

decomp_fe <- tibble::tribble(
  ~absorbed_by, ~fe_formula,
  "birth_aimag FE", "birth_aimag",
  "birth_aimag + birth_cohort FE", "birth_aimag + birth_cohort"
)
if (region_available) decomp_fe <- bind_rows(decomp_fe, tibble(absorbed_by = "region + wave FE", fe_formula = "region + wave"))

variance_decomp <- crossing(iv_var = top10$iv_var, decomp_fe) %>%
  pmap_dfr(function(iv_var, absorbed_by, fe_formula) variance_absorbed(iv_var, absorbed_by, fe_formula))
readr::write_csv(variance_decomp, "output/tables/T2d_school_supply_variance_decomposition_manual.csv")

recommended <- survey %>% filter(verdict == "STRONG", sign_ok == TRUE) %>% arrange(desc(F_first))
recommended_iv <- if (nrow(recommended) > 0) recommended$iv_var[[1]] else NA_character_

verification_status <- if (file.exists("output/reports/manual_1212_excel_verification.md")) {
  "See output/reports/manual_1212_excel_verification.md"
} else {
  "Verification report not found."
}

coverage <- panel %>%
  summarise(
    panel_year_min = min(year, na.rm = TRUE),
    panel_year_max = max(year, na.rm = TRUE),
    schools_years = paste(range(year[!is.na(schools)], na.rm = TRUE), collapse = "-"),
    students_years = paste(range(year[!is.na(students)], na.rm = TRUE), collapse = "-"),
    teachers_years = paste(range(year[!is.na(teachers)], na.rm = TRUE), collapse = "-"),
    school_age_population_usable = any(is.finite(school_age_population))
  )
readr::write_csv(coverage, "output/logs/13a_school_supply_coverage.csv")

fmt <- function(x, digits = 3) ifelse(is.na(x), "NA", formatC(x, digits = digits, format = "f"))
top_md <- c(
  "| IV | pi_hat | p | F_first | beta_2SLS | se_2SLS | N | sign_ok | verdict |",
  "|---|---:|---:|---:|---:|---:|---:|---|---|",
  paste0(
    "| ", top10$iv_var,
    " | ", fmt(top10$pi_hat, 5),
    " | ", fmt(top10$pi_p, 4),
    " | ", fmt(top10$F_first, 3),
    " | ", fmt(top10$beta_2sls, 4),
    " | ", fmt(top10$se_2sls, 4),
    " | ", top10$N,
    " | ", top10$sign_ok,
    " | ", top10$verdict,
    " |"
  )
)

report <- c(
  "# School-Supply IV Survey Summary",
  "",
  "## Manual Excel Files Used",
  "- `data/ЕРӨНХИЙ БОЛОВСРОЛЫН СУРГУУЛИЙН ТОО, аймаг, нийслэл, жилээр.xlsx`",
  "- `data/ЕРӨНХИЙ БОЛОВСРОЛЫН СУРГУУЛЬД ӨДРӨӨР СУРАЛЦАГЧДЫН ТОО, аймаг, нийслэл, жилээр.xlsx`",
  "- `data/ЕРӨНХИЙ БОЛОВСРОЛЫН СУРГУУЛИЙН ҮНДСЭН БАГШ, аймаг, нийслэл, жилээр.xlsx`",
  "- `data/ХҮН АМЫН ТОО, хүйс, насны бүлэг, жилээр.xlsx`",
  "- `data/ЖИЛИЙН ДУНДАЖ ХҮН АМЫН ТОО, аймаг, нийслэл, жилээр.xlsx`",
  "",
  "## 1212 Verification Status",
  paste0("- ", verification_status),
  "",
  "## Year Coverage",
  paste0("- Schools: ", coverage$schools_years),
  paste0("- Students: ", coverage$students_years),
  paste0("- Teachers: ", coverage$teachers_years),
  paste0("- School-age population usable for aimag-level IV normalization: ", coverage$school_age_population_usable),
  "",
  "## HSES Sample Size After Merge",
  paste0("- Main wage sample rows before IV-specific missingness: ", nrow(hses)),
  paste0("- HSES source: `", hses_path, "`"),
  "",
  "## Top 10 IV Candidates Under Corrected FE",
  "- Corrected FE: birth_aimag + birth_cohort + wave",
  top_md,
  "",
  "## Recommended IV",
  if (!is.na(recommended_iv)) paste0("- Recommended: `", recommended_iv, "`") else "- No school-supply IV is viable under corrected FE.",
  "",
  "## Warnings And Limitations",
  "- Raw school, student, and teacher counts were not used as main IVs.",
  "- National age-group population is not aimag-level, so school-age population normalization was not used.",
  "- IV-specific N is limited by school-supply year coverage and birth-year exposure timing.",
  "- Do not recommend any IV with wrong corrected-FE sign or F driven only by region + wave."
)
writeLines(report, "output/reports/school_supply_iv_survey_manual_summary.md", useBytes = TRUE)

cat("Main HSES N:", nrow(hses), "\n")
cat("Survey rows:", nrow(survey), "\n")
cat("Top 10 corrected FE:\n")
print(top10, n = 10)
cat("Recommended IV:", ifelse(is.na(recommended_iv), "NONE", recommended_iv), "\n")
cat("13a complete.\n")
