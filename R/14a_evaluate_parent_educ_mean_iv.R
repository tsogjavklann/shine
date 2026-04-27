# Evaluate parent_educ_mean as the standalone just-identified IV before IVTR.

options(warn = 1, encoding = "UTF-8")

source(here::here("R", "paths.R"))
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
  library(fixest)
})

setFixest_estimation(panel.id = NULL)

dir.create(PATHS$out_tables, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(PATHS$out_root, "reports"), recursive = TRUE, showWarnings = FALSE)
dir.create(PATHS$out_logs, recursive = TRUE, showWarnings = FALSE)

log_path <- file.path(PATHS$out_logs, "14a_evaluate_parent_educ_mean_iv.log")
sink(log_path, split = TRUE)
on.exit(sink(), add = TRUE)

cat("14a_evaluate_parent_educ_mean_iv.R\n")
cat("Started:", as.character(Sys.time()), "\n\n")

analysis_path <- file.path(PATHS$data_proc, "analysis_sample.rds")
if (!file.exists(analysis_path)) {
  processed <- list.files(PATHS$data_proc, pattern = "\\.rds$", full.names = TRUE)
  if (length(processed) == 0) stop("No processed .rds files found.")
  analysis_path <- processed[grepl("analysis|sample", basename(processed), ignore.case = TRUE)][1]
  if (is.na(analysis_path)) analysis_path <- processed[1]
}

analysis <- readRDS(analysis_path) |> as_tibble()
dat <- analysis

family_path <- file.path(PATHS$data_proc, "family_structure.rds")
if (file.exists(family_path)) {
  family <- readRDS(family_path) |>
    as_tibble() |>
    select(
      id,
      father_educ_years, mother_educ_years,
      father_educ_level, mother_educ_level
    ) |>
    distinct(id, .keep_all = TRUE) |>
    rename(
      father_educ_years_family = father_educ_years,
      mother_educ_years_family = mother_educ_years,
      father_educ_level_family = father_educ_level,
      mother_educ_level_family = mother_educ_level
    )
  dat <- dat |>
    left_join(family, by = "id")
  if (!"father_educ_years" %in% names(dat)) dat$father_educ_years <- NA_real_
  if (!"mother_educ_years" %in% names(dat)) dat$mother_educ_years <- NA_real_
  if (!"father_educ_level" %in% names(dat)) dat$father_educ_level <- NA_real_
  if (!"mother_educ_level" %in% names(dat)) dat$mother_educ_level <- NA_real_
  dat <- dat |>
    mutate(
      father_educ_years = coalesce(.data$father_educ_years, .data$father_educ_years_family),
      mother_educ_years = coalesce(.data$mother_educ_years, .data$mother_educ_years_family),
      father_educ_level = coalesce(.data$father_educ_level, .data$father_educ_level_family),
      mother_educ_level = coalesce(.data$mother_educ_level, .data$mother_educ_level_family)
    ) |>
    select(-ends_with("_family"))
}

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

parent_iv_basis <- "years-based"
if (!"parent_educ_mean" %in% names(dat)) {
  if (all(c("father_educ_years", "mother_educ_years") %in% names(dat))) {
    parent_mean <- rowMeans(
      cbind(as.numeric(dat$father_educ_years), as.numeric(dat$mother_educ_years)),
      na.rm = TRUE
    )
    parent_mean[is.nan(parent_mean)] <- NA_real_
    dat$parent_educ_mean <- parent_mean
  } else if (all(c("father_educ_level", "mother_educ_level") %in% names(dat))) {
    parent_iv_basis <- "level-based"
    parent_mean <- rowMeans(
      cbind(as.numeric(dat$father_educ_level), as.numeric(dat$mother_educ_level)),
      na.rm = TRUE
    )
    parent_mean[is.nan(parent_mean)] <- NA_real_
    dat$parent_educ_mean <- parent_mean
  } else {
    stop("No parent_educ_mean and no usable father/mother education variables found.")
  }
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
  "lwage", "educ_years", "parent_educ_mean",
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
    parent_educ_mean = as.numeric(parent_educ_mean),
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

m1_sample <- dat |>
  filter(
    age >= 25, age <= 60,
    is.finite(lwage),
    !is.na(educ_years), is.finite(educ_years),
    !is.na(parent_educ_mean), is.finite(parent_educ_mean),
    !is.na(age), !is.na(age2),
    !is.na(female), !is.na(married), !is.na(urban),
    !is.na(birth_aimag),
    !is.na(birth_cohort),
    !is.na(wave)
  )

if (has_weight) {
  m1_sample <- m1_sample |> filter(!is.na(hhweight), is.finite(hhweight), hhweight > 0)
}

if (nrow(m1_sample) == 0) stop("No observations remain in the parent_educ_mean IV sample.")

cat("Input sample:", analysis_path, "\n")
cat("Family source:", ifelse(file.exists(family_path), family_path, "not used"), "\n")
cat("Parent IV basis:", parent_iv_basis, "\n")
cat("M1 sample N:", nrow(m1_sample), "\n")
cat("q_school_access available:", has_q_school_access, "\n")
cat("Weights used:", has_weight, "\n")
cat("Birth aimag clusters:", n_distinct(m1_sample$birth_aimag), "\n\n")

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
  educ_years ~ parent_educ_mean
fs_fml <- educ_years ~ parent_educ_mean + age + age2 + female + married + urban |
  birth_aimag + birth_cohort + wave

ols_fit <- fit_feols(ols_fml, m1_sample, vc_main)
iv_fit <- fit_feols(iv_fml, m1_sample, vc_main)
fs_fit <- fit_feols(fs_fml, m1_sample, vc_main)

twoway_warning_notes <- character()
iv_2way <- tryCatch(
  fit_feols(iv_fml, m1_sample, vc_2way),
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
fs_row <- extract_row(fs_fit$value, "parent_educ_mean")

first_stage <- tryCatch(
  fitstat(iv_fit$value, "ivf1")[[1]],
  error = function(e) NULL
)
first_stage_F <- if (is.null(first_stage)) NA_real_ else as.numeric(first_stage$stat)
first_stage_p <- if (is.null(first_stage)) NA_real_ else as.numeric(first_stage$p)
weak_iv_flag <- ifelse(is.na(first_stage_F), NA, first_stage_F < 10)

iv_table <- tibble(
  model = c("M0_OLS", "M1_parent_educ_mean_IV"),
  iv_basis = parent_iv_basis,
  N = c(nobs(ols_fit$value), nobs(iv_fit$value)),
  beta_educ_years = c(ols_row$estimate, iv_row$estimate),
  se = c(ols_row$se, iv_row$se),
  p_value = c(ols_row$p_value, iv_row$p_value),
  first_stage_F = c(NA_real_, first_stage_F),
  first_stage_p_value = c(NA_real_, first_stage_p),
  weak_iv_flag = c(NA, weak_iv_flag),
  just_identified = c(NA, TRUE),
  interpretation_note = c(
    "OLS association conditional on controls and fixed effects.",
    "Just-identified parent_educ_mean IV; overidentification does not apply. Parent education may affect wages through family background, networks, and unobserved ability channels."
  ),
  cluster = "birth_aimag",
  weights = ifelse(has_weight, "hhweight", "none")
)

first_stage_table <- tibble(
  model = "First stage: educ_years",
  iv = "parent_educ_mean",
  iv_basis = parent_iv_basis,
  N = nobs(fs_fit$value),
  estimate = fs_row$estimate,
  se = fs_row$se,
  p_value = fs_row$p_value,
  first_stage_F = first_stage_F,
  first_stage_p_value = first_stage_p,
  weak_iv_flag = weak_iv_flag,
  cluster = "birth_aimag",
  weights = ifelse(has_weight, "hhweight", "none")
)

if (has_q_school_access) {
  q <- as.numeric(m1_sample$q_school_access)
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
    unique_values = n_distinct(q, na.rm = TRUE),
    cor_q_school_access_educ_years = suppressWarnings(cor(q, m1_sample$educ_years, use = "pairwise.complete.obs")),
    cor_q_school_access_parent_educ_mean = suppressWarnings(cor(q, m1_sample$parent_educ_mean, use = "pairwise.complete.obs"))
  )
} else {
  q_school_access_diag <- tibble(
    N_nonmissing = NA_integer_,
    mean = NA_real_, sd = NA_real_, min = NA_real_,
    p10 = NA_real_, p25 = NA_real_, p50 = NA_real_, p75 = NA_real_,
    p90 = NA_real_, max = NA_real_, unique_values = NA_integer_,
    cor_q_school_access_educ_years = NA_real_,
    cor_q_school_access_parent_educ_mean = NA_real_
  )
}

write_csv(iv_table, file.path(PATHS$out_tables, "T3a_parent_educ_mean_iv.csv"))
write_csv(first_stage_table, file.path(PATHS$out_tables, "T3a_parent_educ_mean_first_stage.csv"))
write_csv(q_school_access_diag, file.path(PATHS$out_tables, "T3a_parent_educ_mean_qschool_access_diagnostics.csv"))

q_school_access_enough <- has_q_school_access &&
  !is.na(q_school_access_diag$N_nonmissing) &&
  q_school_access_diag$N_nonmissing > 0 &&
  !is.na(q_school_access_diag$sd) &&
  q_school_access_diag$sd > 0 &&
  !is.na(q_school_access_diag$unique_values) &&
  q_school_access_diag$unique_values >= 10

ivtr_created <- FALSE
ivtr_path <- file.path(PATHS$data_proc, "ivtr_ready_parent_educ_mean_qschool_access.rds")
if (!is.na(first_stage_F) && first_stage_F >= 10) {
  ivtr_vars <- c(
    "lwage", "educ_years", "parent_educ_mean",
    "age", "age2", "female", "married", "urban",
    "birth_aimag", "birth_cohort", "wave"
  )
  if (has_q_school_access) ivtr_vars <- c(ivtr_vars, "q_school_access")
  if (has_weight) ivtr_vars <- c(ivtr_vars, "hhweight")
  ivtr_ready <- if (has_q_school_access) {
    m1_sample |> filter(!is.na(q_school_access), is.finite(as.numeric(q_school_access)))
  } else {
    m1_sample
  }
  ivtr_ready <- ivtr_ready |> select(all_of(ivtr_vars))
  saveRDS(ivtr_ready, ivtr_path)
  ivtr_created <- TRUE
}

decision <- if (is.na(first_stage_F) || first_stage_F < 10) {
  "Do not proceed to IVTR; parent_educ_mean is weak."
} else if (!q_school_access_enough) {
  "Do not proceed to q_school_access IVTR until q_school_access is fixed."
} else {
  "Proceed to IVTR with parent_educ_mean and q_school_access."
}

fmt <- function(x, digits = 4) ifelse(is.na(x), "NA", formatC(x, format = "f", digits = digits))
warning_lines <- unique(c(ols_fit$warnings, iv_fit$warnings, fs_fit$warnings, twoway_warning_notes))
if (length(warning_lines) == 0) warning_lines <- "No model warnings captured."

summary_lines <- c(
  "# parent_educ_mean IV Evaluation",
  "",
  paste0("Generated: ", Sys.time()),
  paste0("Input sample: ", analysis_path),
  paste0("Family source: ", ifelse(file.exists(family_path), family_path, "not used")),
  paste0("IV basis: ", parent_iv_basis),
  paste0("Weights: ", ifelse(has_weight, "hhweight", "none")),
  paste0("Cluster: birth_aimag"),
  "",
  "## OLS",
  paste0("- N: ", nobs(ols_fit$value)),
  paste0("- beta_OLS: ", fmt(ols_row$estimate), ", SE: ", fmt(ols_row$se), ", p-value: ", fmt(ols_row$p_value)),
  "",
  "## parent_educ_mean IV",
  paste0("- N: ", nobs(iv_fit$value)),
  paste0("- beta_2SLS: ", fmt(iv_row$estimate), ", SE: ", fmt(iv_row$se), ", p-value: ", fmt(iv_row$p_value)),
  paste0("- First-stage coefficient: ", fmt(fs_row$estimate), ", SE: ", fmt(fs_row$se), ", p-value: ", fmt(fs_row$p_value)),
  paste0("- First-stage F: ", fmt(first_stage_F), ", weak-IV flag: ", weak_iv_flag),
  "- Just-identified model: overidentification does not apply.",
  "- Parent education may affect wages through family background, networks, and unobserved ability channels.",
  "",
  "## q_school_access Diagnostics",
  paste0("- N nonmissing: ", q_school_access_diag$N_nonmissing),
  paste0("- Mean: ", fmt(q_school_access_diag$mean), ", SD: ", fmt(q_school_access_diag$sd), ", Min: ", fmt(q_school_access_diag$min), ", Max: ", fmt(q_school_access_diag$max)),
  paste0("- p10: ", fmt(q_school_access_diag$p10), ", p25: ", fmt(q_school_access_diag$p25), ", p50: ", fmt(q_school_access_diag$p50), ", p75: ", fmt(q_school_access_diag$p75), ", p90: ", fmt(q_school_access_diag$p90)),
  paste0("- Unique values: ", q_school_access_diag$unique_values),
  paste0("- corr(q_school_access, educ_years): ", fmt(q_school_access_diag$cor_q_school_access_educ_years)),
  paste0("- corr(q_school_access, parent_educ_mean): ", fmt(q_school_access_diag$cor_q_school_access_parent_educ_mean)),
  "",
  "## Decision",
  decision,
  paste0("IVTR-ready dataset created: ", ivtr_created),
  if (ivtr_created) paste0("IVTR-ready dataset: ", ivtr_path) else "IVTR-ready dataset: not created",
  "",
  "## Warnings",
  paste0("- ", warning_lines),
  if (twoway_npdef) "- Two-way cluster warning detected; main table uses one-way birth_aimag clustering." else "- Main table uses one-way birth_aimag clustering."
)

writeLines(summary_lines, file.path(PATHS$out_root, "reports", "parent_educ_mean_iv_evaluation.md"), useBytes = TRUE)

cat("OLS result:\n")
print(iv_table[1, ])
cat("\nparent_educ_mean IV result:\n")
print(iv_table[2, ])
cat("\nFirst stage:\n")
print(first_stage_table)
cat("\nq_school_access diagnostics:\n")
print(q_school_access_diag)
cat("\nDecision:", decision, "\n")
cat("IVTR-ready dataset created:", ivtr_created, "\n")
if (ivtr_created) cat("Saved IVTR-ready dataset:", ivtr_path, "\n")
cat("\nCompleted:", as.character(Sys.time()), "\n")
