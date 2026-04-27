# Final Pastore-style parental education IV validation before IVTR.

options(warn = 1, encoding = "UTF-8")

source(here::here("R", "paths.R"))
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
  library(fixest)
  library(ivreg)
})

setFixest_estimation(panel.id = NULL)

dir.create(PATHS$out_tables, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(PATHS$out_root, "reports"), recursive = TRUE, showWarnings = FALSE)
dir.create(PATHS$out_logs, recursive = TRUE, showWarnings = FALSE)

log_path <- file.path(PATHS$out_logs, "14_final_pastore_parental_iv.log")
sink(log_path, split = TRUE)
on.exit(sink(), add = TRUE)

cat("14_final_pastore_parental_iv.R\n")
cat("Started:", as.character(Sys.time()), "\n\n")

analysis_path <- file.path(PATHS$data_proc, "analysis_sample.rds")
family_path <- file.path(PATHS$data_proc, "family_structure.rds")
if (!file.exists(analysis_path)) stop("Missing ", analysis_path)
if (!file.exists(family_path)) stop("Missing ", family_path)

analysis <- readRDS(analysis_path) |> as_tibble()
family <- readRDS(family_path) |>
  as_tibble() |>
  select(
    id,
    father_educ_years, mother_educ_years,
    father_educ_level, mother_educ_level
  ) |>
  distinct(id, .keep_all = TRUE)

dat <- analysis |>
  left_join(family, by = "id")

if (!"lwage" %in% names(dat)) {
  if ("ln_wage" %in% names(dat)) {
    dat <- dat |> mutate(lwage = as.numeric(ln_wage))
  } else if ("wage" %in% names(dat)) {
    dat <- dat |> mutate(lwage = if_else(as.numeric(wage) > 0, log(as.numeric(wage)), NA_real_))
  } else {
    stop("No lwage, ln_wage, or wage variable found.")
  }
}

if (!"age2" %in% names(dat)) {
  dat <- dat |> mutate(age2 = as.numeric(age)^2)
}

if (!"female" %in% names(dat)) {
  if ("is_female" %in% names(dat)) {
    dat <- dat |> mutate(female = as.numeric(is_female))
  } else if ("sex" %in% names(dat)) {
    dat <- dat |> mutate(female = if_else(as.numeric(sex) == 2, 1, 0, missing = NA_real_))
  } else {
    stop("No female, is_female, or sex variable found.")
  }
}

if (!"married" %in% names(dat)) {
  if ("is_married" %in% names(dat)) {
    dat <- dat |> mutate(married = as.numeric(is_married))
  } else if ("marital" %in% names(dat)) {
    dat <- dat |> mutate(married = if_else(as.numeric(marital) == 2, 1, 0, missing = NA_real_))
  } else {
    stop("No married, is_married, or marital variable found.")
  }
}

if (!all(c("father_educ_years", "mother_educ_years") %in% names(dat))) {
  if (all(c("father_educ_level", "mother_educ_level") %in% names(dat))) {
    dat <- dat |>
      mutate(
        father_educ_years = as.numeric(father_educ_level),
        mother_educ_years = as.numeric(mother_educ_level)
      )
    parent_iv_basis <- "level-based"
  } else {
    stop("No father/mother education year variables or level variables found.")
  }
} else {
  parent_iv_basis <- "years-based"
}

# Reuse the documented cohort bins from R/13d_unexplored_variables.R.
if (!"birth_cohort" %in% names(dat)) {
  if (!"birth_year" %in% names(dat)) stop("birth_cohort is missing and birth_year is unavailable.")
  dat <- dat |>
    mutate(
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
}

required <- c(
  "lwage", "educ_years", "father_educ_years", "mother_educ_years",
  "age", "age2", "female", "married", "urban",
  "birth_aimag", "birth_cohort", "wave"
)
missing_required <- setdiff(required, names(dat))
if (length(missing_required) > 0) {
  stop("Missing required variable(s): ", paste(missing_required, collapse = ", "))
}

has_weight <- "hhweight" %in% names(dat)
has_q_school_access <- "q_school_access" %in% names(dat)

dat <- dat |>
  mutate(
    lwage = as.numeric(lwage),
    educ_years = as.numeric(educ_years),
    father_educ_years = as.numeric(father_educ_years),
    mother_educ_years = as.numeric(mother_educ_years),
    age = as.numeric(age),
    age2 = as.numeric(age2),
    female = as.numeric(female),
    married = as.numeric(married),
    urban = as.numeric(urban),
    birth_aimag = as.factor(birth_aimag),
    birth_cohort = as.factor(birth_cohort),
    wave = as.factor(wave),
    hhweight = if (has_weight) as.numeric(hhweight) else 1
  )

base_filter <- dat |>
  filter(
    age >= 25, age <= 60,
    is.finite(lwage),
    !is.na(educ_years),
    !is.na(father_educ_years), is.finite(father_educ_years),
    !is.na(mother_educ_years), is.finite(mother_educ_years),
    !is.na(age), !is.na(age2),
    !is.na(female), !is.na(married), !is.na(urban),
    !is.na(birth_aimag),
    !is.na(birth_cohort),
    !is.na(wave)
  )

if (has_q_school_access) {
  main <- base_filter |>
    filter(!is.na(q_school_access), is.finite(as.numeric(q_school_access)))
} else {
  main <- base_filter
}

if (has_weight) {
  main <- main |> filter(!is.na(hhweight), is.finite(hhweight), hhweight > 0)
}

if (nrow(main) == 0) stop("No observations remain in the final parental-IV sample.")

cat("Parent IV basis:", parent_iv_basis, "\n")
cat("Complete parental-IV sample N:", nrow(main), "\n")
cat("q_school_access required:", has_q_school_access, "\n")
cat("Weights used:", has_weight, "\n")
cat("Birth aimag clusters:", n_distinct(main$birth_aimag), "\n\n")

wts <- if (has_weight) ~hhweight else NULL
vc_main <- ~birth_aimag
vc_2way <- ~birth_aimag + wave

capture_warnings <- function(expr) {
  notes <- character()
  value <- withCallingHandlers(
    expr,
    warning = function(w) {
      notes <<- c(notes, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  list(value = value, warnings = notes)
}

fit_feols <- function(fml, data, vcov) {
  args <- list(fml = fml, data = data, weights = wts, vcov = vcov, notes = FALSE)
  capture_warnings(do.call(feols, args))
}

ols_fml <- lwage ~ educ_years + age + age2 + female + married + urban |
  birth_aimag + birth_cohort + wave
iv_fml <- lwage ~ age + age2 + female + married + urban |
  birth_aimag + birth_cohort + wave |
  educ_years ~ father_educ_years + mother_educ_years
fs_fml <- educ_years ~ father_educ_years + mother_educ_years +
  age + age2 + female + married + urban |
  birth_aimag + birth_cohort + wave

ols_fit <- fit_feols(ols_fml, main, vc_main)
iv_fit <- fit_feols(iv_fml, main, vc_main)
fs_fit <- fit_feols(fs_fml, main, vc_main)

twoway_warning_notes <- character()
iv_2way <- tryCatch(
  fit_feols(iv_fml, main, vc_2way),
  error = function(e) {
    twoway_warning_notes <<- c(twoway_warning_notes, paste("Two-way cluster failed:", conditionMessage(e)))
    NULL
  }
)
if (!is.null(iv_2way)) {
  twoway_warning_notes <- c(twoway_warning_notes, iv_2way$warnings)
}
twoway_npdef <- any(grepl("positive|definite|fixed", twoway_warning_notes, ignore.case = TRUE))

extract_row <- function(fit, term) {
  ct <- coeftable(fit)
  if (!term %in% rownames(ct)) {
    term <- rownames(ct)[grepl(term, rownames(ct), fixed = TRUE)][1]
  }
  if (is.na(term) || length(term) == 0) {
    return(tibble(term = NA_character_, estimate = NA_real_, se = NA_real_, p_value = NA_real_))
  }
  tibble(
    term = term,
    estimate = unname(ct[term, "Estimate"]),
    se = unname(ct[term, "Std. Error"]),
    p_value = unname(ct[term, "Pr(>|t|)"])
  )
}

ols_row <- extract_row(ols_fit$value, "educ_years")
iv_row <- extract_row(iv_fit$value, "fit_educ_years")
fs_father <- extract_row(fs_fit$value, "father_educ_years")
fs_mother <- extract_row(fs_fit$value, "mother_educ_years")

first_stage_joint <- tryCatch(
  fitstat(iv_fit$value, "ivf1")[[1]],
  error = function(e) NULL
)
first_stage_F <- if (is.null(first_stage_joint)) NA_real_ else as.numeric(first_stage_joint$stat)
first_stage_p <- if (is.null(first_stage_joint)) NA_real_ else as.numeric(first_stage_joint$p)
weak_iv_flag <- ifelse(is.na(first_stage_F), NA, first_stage_F < 10)

overid_source <- "ivreg weighted FE-factor Sargan"
overid_fit <- tryCatch({
  overid_args <- list(
    formula = lwage ~ educ_years + age + age2 + female + married + urban +
      birth_aimag + birth_cohort + wave |
      father_educ_years + mother_educ_years + age + age2 + female + married + urban +
      birth_aimag + birth_cohort + wave,
    data = main
  )
  if (has_weight) overid_args$weights <- main$hhweight
  do.call(ivreg::ivreg, overid_args)
}, error = function(e) e)

if (inherits(overid_fit, "error")) {
  overid_stat <- NA_real_
  overid_p <- NA_real_
  overid_df <- NA_real_
  overid_source <- paste("not available:", conditionMessage(overid_fit))
} else {
  overid_diag <- tryCatch(summary(overid_fit, diagnostics = TRUE)$diagnostics, error = function(e) NULL)
  if (!is.null(overid_diag) && "Sargan" %in% rownames(overid_diag)) {
    overid_stat <- as.numeric(overid_diag["Sargan", "statistic"])
    overid_p <- as.numeric(overid_diag["Sargan", "p-value"])
    overid_df <- as.numeric(overid_diag["Sargan", "df1"])
  } else {
    overid_stat <- NA_real_
    overid_p <- NA_real_
    overid_df <- NA_real_
    overid_source <- "not available from ivreg diagnostics"
  }
}
overid_result <- case_when(
  is.na(overid_p) ~ "not available",
  overid_p < 0.05 ~ "The overidentifying restrictions are rejected.",
  TRUE ~ "The overidentifying restrictions are not rejected."
)

iv_table <- tibble(
  model = c("M0_OLS", "M1_Pastore_parental_IV"),
  iv_basis = parent_iv_basis,
  N = c(nobs(ols_fit$value), nobs(iv_fit$value)),
  beta_educ_years = c(ols_row$estimate, iv_row$estimate),
  se = c(ols_row$se, iv_row$se),
  p_value = c(ols_row$p_value, iv_row$p_value),
  first_stage_joint_F = c(NA_real_, first_stage_F),
  first_stage_joint_p = c(NA_real_, first_stage_p),
  weak_iv_flag = c(NA, weak_iv_flag),
  overid_stat = c(NA_real_, overid_stat),
  overid_df = c(NA_real_, overid_df),
  overid_p_value = c(NA_real_, overid_p),
  cluster = "birth_aimag",
  weights = ifelse(has_weight, "hhweight", "none")
)

first_stage_table <- tibble(
  model = "First stage: educ_years",
  N = nobs(fs_fit$value),
  joint_F_father_mother = first_stage_F,
  joint_F_p_value = first_stage_p,
  weak_iv_flag = weak_iv_flag,
  term = c("father_educ_years", "mother_educ_years"),
  estimate = c(fs_father$estimate, fs_mother$estimate),
  se = c(fs_father$se, fs_mother$se),
  p_value = c(fs_father$p_value, fs_mother$p_value),
  cluster = "birth_aimag",
  weights = ifelse(has_weight, "hhweight", "none")
)

overid_table <- tibble(
  test = "Sargan overidentification test",
  source = overid_source,
  statistic = overid_stat,
  df = overid_df,
  p_value = overid_p,
  result = overid_result,
  caveat = "Parental education may affect wages through family background, networks, and unobserved ability channels."
)

ivtr_vars <- c(
  "lwage", "educ_years", "father_educ_years", "mother_educ_years", "q_school_access",
  "age", "age2", "female", "married", "urban",
  "birth_aimag", "birth_cohort", "wave"
)
if (has_weight) ivtr_vars <- c(ivtr_vars, "hhweight")
if (!has_q_school_access) {
  stop("q_school_access is unavailable; cannot create the requested IVTR-ready q_school_access dataset.")
}
ivtr_ready <- main |>
  select(all_of(ivtr_vars))

ivtr_path <- file.path(PATHS$data_proc, "ivtr_ready_pastore_parental_qschool_access.rds")
saveRDS(ivtr_ready, ivtr_path)

q <- as.numeric(ivtr_ready$q_school_access)
q_school_access_diag <- tibble(
  N_nonmissing = sum(!is.na(q) & is.finite(q)),
  mean = mean(q, na.rm = TRUE),
  sd = sd(q, na.rm = TRUE),
  min = min(q, na.rm = TRUE),
  p10 = as.numeric(quantile(q, 0.10, na.rm = TRUE, names = FALSE)),
  p25 = as.numeric(quantile(q, 0.25, na.rm = TRUE, names = FALSE)),
  p50 = as.numeric(quantile(q, 0.50, na.rm = TRUE, names = FALSE)),
  p75 = as.numeric(quantile(q, 0.75, na.rm = TRUE, names = FALSE)),
  p90 = as.numeric(quantile(q, 0.90, na.rm = TRUE, names = FALSE)),
  max = max(q, na.rm = TRUE),
  n_unique = n_distinct(q, na.rm = TRUE),
  cor_educ_years = suppressWarnings(cor(q, ivtr_ready$educ_years, use = "pairwise.complete.obs")),
  cor_father_educ_years = suppressWarnings(cor(q, ivtr_ready$father_educ_years, use = "pairwise.complete.obs")),
  cor_mother_educ_years = suppressWarnings(cor(q, ivtr_ready$mother_educ_years, use = "pairwise.complete.obs"))
)

write_csv(iv_table, file.path(PATHS$out_tables, "T3_final_pastore_parental_iv.csv"))
write_csv(first_stage_table, file.path(PATHS$out_tables, "T3_final_pastore_parental_first_stage.csv"))
write_csv(overid_table, file.path(PATHS$out_tables, "T3_final_pastore_parental_overid.csv"))

fmt <- function(x, digits = 4) ifelse(is.na(x), "NA", formatC(x, format = "f", digits = digits))
decision <- if (!is.na(first_stage_F) && first_stage_F >= 10 && !is.na(overid_p) && overid_p >= 0.05) {
  "Proceed to IVTR as a caveated next step."
} else if (!is.na(first_stage_F) && first_stage_F >= 10 && is.na(overid_p)) {
  "Proceed to IVTR cautiously; overidentification test is unavailable."
} else {
  "Do not proceed to IVTR as the main causal design without revisiting IV strength/validity."
}

summary_lines <- c(
  "# Final Pastore-Style Parental Education IV",
  "",
  paste0("Generated: ", Sys.time()),
  paste0("Input sample: ", analysis_path),
  paste0("Parental education source: ", family_path),
  paste0("IV basis: ", parent_iv_basis),
  paste0("Weights: ", ifelse(has_weight, "hhweight", "none")),
  paste0("Cluster: birth_aimag"),
  "",
  "## Results",
  paste0("- N: ", nobs(iv_fit$value)),
  paste0("- OLS beta: ", fmt(ols_row$estimate), ", SE: ", fmt(ols_row$se), ", p-value: ", fmt(ols_row$p_value)),
  paste0("- 2SLS beta: ", fmt(iv_row$estimate), ", SE: ", fmt(iv_row$se), ", p-value: ", fmt(iv_row$p_value)),
  paste0("- First-stage joint F, father + mother instruments: ", fmt(first_stage_F), ", p-value: ", fmt(first_stage_p)),
  paste0("- father_educ_years first-stage coefficient: ", fmt(fs_father$estimate), ", SE: ", fmt(fs_father$se), ", p-value: ", fmt(fs_father$p_value)),
  paste0("- mother_educ_years first-stage coefficient: ", fmt(fs_mother$estimate), ", SE: ", fmt(fs_mother$se), ", p-value: ", fmt(fs_mother$p_value)),
  paste0("- Weak-IV flag: ", weak_iv_flag),
  paste0("- Overidentification test: ", overid_result),
  paste0("- Overid statistic: ", fmt(overid_stat), ", df: ", fmt(overid_df, 0), ", p-value: ", fmt(overid_p)),
  "",
  "## q_school_access Diagnostics",
  paste0("- N nonmissing: ", q_school_access_diag$N_nonmissing),
  paste0("- Mean: ", fmt(q_school_access_diag$mean), ", SD: ", fmt(q_school_access_diag$sd), ", Min: ", fmt(q_school_access_diag$min), ", Max: ", fmt(q_school_access_diag$max)),
  paste0("- p10: ", fmt(q_school_access_diag$p10), ", p25: ", fmt(q_school_access_diag$p25), ", p50: ", fmt(q_school_access_diag$p50), ", p75: ", fmt(q_school_access_diag$p75), ", p90: ", fmt(q_school_access_diag$p90)),
  paste0("- Unique values: ", q_school_access_diag$n_unique),
  paste0("- Correlation with educ_years: ", fmt(q_school_access_diag$cor_educ_years)),
  paste0("- Correlation with father_educ_years: ", fmt(q_school_access_diag$cor_father_educ_years)),
  paste0("- Correlation with mother_educ_years: ", fmt(q_school_access_diag$cor_mother_educ_years)),
  "",
  "## Interpretation",
  overid_result,
  "Parental education may affect wages through family background, networks, and unobserved ability channels.",
  paste0("Decision: ", decision),
  "",
  "## Warnings",
  if (length(c(ols_fit$warnings, iv_fit$warnings, fs_fit$warnings, twoway_warning_notes)) == 0) {
    "- No model warnings captured."
  } else {
    paste0("- ", unique(c(ols_fit$warnings, iv_fit$warnings, fs_fit$warnings, twoway_warning_notes)))
  },
  if (twoway_npdef) "- Two-way cluster warning detected; main table uses one-way birth_aimag clustering." else "- Main table uses one-way birth_aimag clustering.",
  "",
  paste0("IVTR-ready dataset: ", ivtr_path)
)

writeLines(summary_lines, file.path(PATHS$out_root, "reports", "final_pastore_parental_iv_summary.md"), useBytes = TRUE)

cat("OLS result:\n")
print(ols_row)
cat("\nIV result:\n")
print(iv_row)
cat("\nFirst stage:\n")
print(first_stage_table)
cat("\nOveridentification:\n")
print(overid_table)
cat("\nq_school_access diagnostics:\n")
print(q_school_access_diag)
cat("\nDecision:", decision, "\n")
cat("Saved IVTR-ready dataset:", ivtr_path, "\n")
cat("\nCompleted:", as.character(Sys.time()), "\n")
