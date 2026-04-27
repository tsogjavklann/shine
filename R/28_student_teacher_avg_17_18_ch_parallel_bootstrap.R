# =============================================================================
# 28_student_teacher_avg_17_18_ch_parallel_bootstrap.R
# -----------------------------------------------------------------------------
# Purpose:
#   Run a Caner-Hansen-style IV threshold pipeline using
#   student_teacher_ratio_avg_17_18 as the threshold variable.
#
# Design:
#   Outcome: lwage
#   Endogenous regressor: educ_years
#   IV: parent_educ_mean
#   Threshold: student_teacher_ratio_avg_17_18
#   Controls: age, age2, female, married, urban
#   FE residualized: birth_aimag + birth_cohort + wave
#   Weights: hhweight if available
#   Cluster: birth_aimag
#
# Important:
#   - This script does not search for new IVs.
#   - student_teacher_ratio_avg_17_18 is a threshold variable only, not an IV.
#   - parent_educ_mean remains the IV.
#   - Higher student_teacher_ratio_avg_17_18 means more students per teacher.
# =============================================================================

options(warn = 1, encoding = "UTF-8")

source(here::here("R", "paths.R"))

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
  library(fixest)
  library(ggplot2)
})

setFixest_estimation(panel.id = NULL)

dir.create(PATHS$out_tables, recursive = TRUE, showWarnings = FALSE)
dir.create(PATHS$out_figures, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(PATHS$out_root, "reports"), recursive = TRUE, showWarnings = FALSE)
dir.create(PATHS$out_logs, recursive = TRUE, showWarnings = FALSE)

log_path <- file.path(PATHS$out_logs, "28_student_teacher_avg_17_18_ch_parallel_bootstrap.log")
sink(log_path, split = TRUE)
on.exit(sink(), add = TRUE)

cat("28_student_teacher_avg_17_18_ch_parallel_bootstrap.R\n")
cat("Started:", as.character(Sys.time()), "\n\n")

set.seed(20260426)

fmt <- function(x, digits = 4) {
  ifelse(is.na(x), "NA", formatC(x, format = "f", digits = digits))
}

qval <- function(x, p) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  as.numeric(quantile(x, p, na.rm = TRUE, names = FALSE))
}

corr_pair <- function(x, y) {
  x <- suppressWarnings(as.numeric(x))
  y <- suppressWarnings(as.numeric(y))
  ok <- is.finite(x) & is.finite(y)
  if (sum(ok) < 10) return(NA_real_)
  suppressWarnings(cor(x[ok], y[ok]))
}

safe_solve <- function(M) {
  tryCatch(solve(M), error = function(e) NULL)
}

condition_number <- function(M) {
  tryCatch(kappa(M, exact = TRUE), error = function(e) NA_real_)
}

cohort_from_birth_year <- function(birth_year) {
  dplyr::case_when(
    birth_year < 1970 ~ "pre1970",
    birth_year >= 1970 & birth_year <= 1974 ~ "1970_1974",
    birth_year >= 1975 & birth_year <= 1979 ~ "1975_1979",
    birth_year >= 1980 & birth_year <= 1984 ~ "1980_1984",
    birth_year >= 1985 & birth_year <= 1989 ~ "1985_1989",
    birth_year >= 1990 & birth_year <= 1994 ~ "1990_1994",
    birth_year >= 1995 ~ "post1995",
    TRUE ~ NA_character_
  )
}

school_quality_label <- function(gamma, side = c("low", "high")) {
  side <- match.arg(side)
  if (side == "low") {
    paste0("Lower crowding (STR <= ", round(gamma, 2), ")")
  } else {
    paste0("Higher crowding (STR > ", round(gamma, 2), ")")
  }
}

# -----------------------------------------------------------------------------
# Stage 28A: Load, construct threshold sample, and run baseline diagnostics
# -----------------------------------------------------------------------------

analysis_path <- file.path(PATHS$data_proc, "analysis_sample.rds")
family_path <- file.path(PATHS$data_proc, "family_structure.rds")
panel_path <- file.path(PATHS$data_root, "cleaned", "school_supply_panel.rds")

if (!file.exists(analysis_path)) stop("Missing ", analysis_path)
if (!file.exists(family_path)) stop("Missing ", family_path)
if (!file.exists(panel_path)) stop("Missing ", panel_path)

analysis <- readRDS(analysis_path) |> as_tibble()
family <- readRDS(family_path) |>
  as_tibble() |>
  mutate(
    parent_educ_mean_family = rowMeans(cbind(father_educ_years, mother_educ_years), na.rm = TRUE),
    parent_educ_mean_family = if_else(is.nan(parent_educ_mean_family), NA_real_, parent_educ_mean_family)
  ) |>
  select(
    id,
    parent_educ_mean_family,
    father_educ_years,
    mother_educ_years
  )

dat <- analysis |>
  left_join(family, by = "id")

panel <- readRDS(panel_path) |>
  as_tibble() |>
  transmute(
    aimag_code = as.numeric(aimag_code),
    year = as.numeric(year),
    student_teacher_ratio = as.numeric(student_teacher_ratio),
    teachers_per_student = as.numeric(teachers_per_student)
  )

join_school_point <- function(data, age_num) {
  point <- panel |>
    transmute(
      birth_aimag_join = aimag_code,
      year_join = year,
      !!paste0("student_teacher_ratio_at_", age_num) := student_teacher_ratio,
      !!paste0("teachers_per_student_at_", age_num) := teachers_per_student
    )
  join_by <- setNames(
    c("birth_aimag_join", "year_join"),
    c("birth_aimag", paste0("year_at_", age_num))
  )
  data |>
    mutate("{paste0('year_at_', age_num)}" := as.numeric(birth_year) + age_num) |>
    left_join(
      point,
      by = join_by
    )
}

dat <- dat |>
  join_school_point(17) |>
  join_school_point(18) |>
  mutate(
    n_years_student_teacher_ratio_17_18 = rowSums(
      cbind(
        is.finite(student_teacher_ratio_at_17),
        is.finite(student_teacher_ratio_at_18)
      )
    ),
    student_teacher_ratio_avg_17_18 = if_else(
      n_years_student_teacher_ratio_17_18 == 2L,
      rowMeans(cbind(student_teacher_ratio_at_17, student_teacher_ratio_at_18), na.rm = FALSE),
      NA_real_
    ),
    teachers_per_student_avg_17_18 = if_else(
      n_years_student_teacher_ratio_17_18 == 2L,
      rowMeans(cbind(teachers_per_student_at_17, teachers_per_student_at_18), na.rm = FALSE),
      NA_real_
    ),
    year_at_17_18 = as.numeric(birth_year) + 18
  )

if ("parent_educ_mean" %in% names(dat)) {
  dat <- dat |>
    mutate(parent_educ_mean = coalesce(as.numeric(parent_educ_mean), parent_educ_mean_family))
} else {
  dat <- dat |>
    mutate(parent_educ_mean = parent_educ_mean_family)
}

if (!"lwage" %in% names(dat)) {
  if ("ln_wage" %in% names(dat)) {
    dat$lwage <- as.numeric(dat$ln_wage)
  } else if ("wage" %in% names(dat)) {
    dat$lwage <- if_else(as.numeric(dat$wage) > 0, log(as.numeric(dat$wage)), NA_real_)
  } else {
    stop("No lwage, ln_wage, or wage variable found.")
  }
}

if (!"age2" %in% names(dat)) dat$age2 <- as.numeric(dat$age)^2

if (!"female" %in% names(dat)) {
  if ("is_female" %in% names(dat)) {
    dat$female <- dat$is_female
  } else if ("sex" %in% names(dat)) {
    dat$female <- as.integer(dat$sex == 2)
  } else {
    stop("No female/is_female/sex variable found.")
  }
}

if (!"married" %in% names(dat)) {
  if ("is_married" %in% names(dat)) {
    dat$married <- dat$is_married
  } else if ("marital" %in% names(dat)) {
    dat$married <- as.integer(dat$marital %in% c(1, "married", "Married"))
  } else {
    stop("No married/is_married/marital variable found.")
  }
}

if (!"birth_cohort" %in% names(dat)) {
  if (!"birth_year" %in% names(dat)) stop("birth_cohort and birth_year are both missing.")
  dat$birth_cohort <- cohort_from_birth_year(as.numeric(dat$birth_year))
}

if (!"hhweight" %in% names(dat)) dat$hhweight <- 1

required_Stage28a <- c(
  "lwage", "educ_years", "parent_educ_mean", "student_teacher_ratio_avg_17_18",
  "age", "age2", "female", "married", "urban",
  "birth_aimag", "birth_cohort", "wave", "hhweight"
)
missing_23a <- setdiff(required_Stage28a, names(dat))
if (length(missing_23a) > 0) {
  stop("Missing required variable(s): ", paste(missing_23a, collapse = ", "))
}

sample <- dat |>
  mutate(
    lwage = as.numeric(lwage),
    educ_years = as.numeric(educ_years),
    parent_educ_mean = as.numeric(parent_educ_mean),
    student_teacher_ratio_avg_17_18 = as.numeric(student_teacher_ratio_avg_17_18),
    teachers_per_student_avg_17_18 = if ("teachers_per_student_avg_17_18" %in% names(dat)) as.numeric(teachers_per_student_avg_17_18) else NA_real_,
    school_density_student_at_17 = if ("school_density_student_at_17" %in% names(dat)) as.numeric(school_density_student_at_17) else NA_real_,
    students_per_school_at_17 = if ("students_per_school_at_17" %in% names(dat)) as.numeric(students_per_school_at_17) else NA_real_,
    year_at_17_18 = if ("year_at_17_18" %in% names(dat)) as.numeric(year_at_17_18) else NA_real_,
    age = as.numeric(age),
    age2 = as.numeric(age2),
    female = as.numeric(female),
    married = as.numeric(married),
    urban = as.numeric(urban),
    birth_aimag = as.factor(birth_aimag),
    birth_cohort = as.factor(birth_cohort),
    wave = as.factor(wave),
    hhweight = as.numeric(hhweight)
  ) |>
  filter(
    age >= 25, age <= 60,
    is.finite(lwage),
    !is.na(educ_years), is.finite(educ_years),
    !is.na(parent_educ_mean), is.finite(parent_educ_mean),
    !is.na(student_teacher_ratio_avg_17_18), is.finite(student_teacher_ratio_avg_17_18),
    !is.na(age), is.finite(age),
    !is.na(age2), is.finite(age2),
    !is.na(female), is.finite(female),
    !is.na(married), is.finite(married),
    !is.na(urban), is.finite(urban),
    !is.na(birth_aimag),
    !is.na(birth_cohort),
    !is.na(wave),
    !is.na(hhweight), is.finite(hhweight), hhweight > 0
  )

if (nrow(sample) == 0) stop("No observations remain in student-teacher threshold sample.")

iv_ready_path <- file.path(PATHS$data_proc, "ivtr_ready_parent_educ_mean_student_teacher_avg_17_18.rds")
saveRDS(sample, iv_ready_path)

q_by_aimag <- sample |>
  group_by(birth_aimag) |>
  summarise(n_unique_student_teacher_ratio_avg_17_18 = n_distinct(student_teacher_ratio_avg_17_18), .groups = "drop")
q_by_aimag_year <- sample |>
  group_by(birth_aimag, year_at_17_18) |>
  summarise(n_unique_student_teacher_ratio_avg_17_18 = n_distinct(student_teacher_ratio_avg_17_18), .groups = "drop")

deterministic_by_birth_aimag <- all(q_by_aimag$n_unique_student_teacher_ratio_avg_17_18 == 1)
deterministic_by_birth_aimag_year <- all(q_by_aimag_year$n_unique_student_teacher_ratio_avg_17_18 == 1)

sample_diag <- tibble(
  N = nrow(sample),
  n_birth_aimag_clusters = n_distinct(sample$birth_aimag),
  n_birth_cohort_groups = n_distinct(sample$birth_cohort),
  n_waves = n_distinct(sample$wave),
  age_min = min(sample$age),
  age_max = max(sample$age),
  birth_year_min = if ("birth_year" %in% names(sample)) min(as.numeric(sample$birth_year), na.rm = TRUE) else NA_real_,
  birth_year_max = if ("birth_year" %in% names(sample)) max(as.numeric(sample$birth_year), na.rm = TRUE) else NA_real_,
  year_at_17_18_min = if (any(is.finite(sample$year_at_17_18))) min(sample$year_at_17_18, na.rm = TRUE) else NA_real_,
  year_at_17_18_max = if (any(is.finite(sample$year_at_17_18))) max(sample$year_at_17_18, na.rm = TRUE) else NA_real_,
  student_teacher_ratio_avg_17_18_min = min(sample$student_teacher_ratio_avg_17_18, na.rm = TRUE),
  student_teacher_ratio_avg_17_18_p10 = qval(sample$student_teacher_ratio_avg_17_18, 0.10),
  student_teacher_ratio_avg_17_18_p25 = qval(sample$student_teacher_ratio_avg_17_18, 0.25),
  student_teacher_ratio_avg_17_18_p50 = qval(sample$student_teacher_ratio_avg_17_18, 0.50),
  student_teacher_ratio_avg_17_18_p75 = qval(sample$student_teacher_ratio_avg_17_18, 0.75),
  student_teacher_ratio_avg_17_18_p90 = qval(sample$student_teacher_ratio_avg_17_18, 0.90),
  student_teacher_ratio_avg_17_18_max = max(sample$student_teacher_ratio_avg_17_18, na.rm = TRUE),
  student_teacher_ratio_avg_17_18_unique_values = n_distinct(sample$student_teacher_ratio_avg_17_18),
  corr_student_teacher_ratio_avg_17_18_educ_years = corr_pair(sample$student_teacher_ratio_avg_17_18, sample$educ_years),
  corr_student_teacher_ratio_avg_17_18_parent_educ_mean = corr_pair(sample$student_teacher_ratio_avg_17_18, sample$parent_educ_mean),
  corr_student_teacher_ratio_avg_17_18_lwage = corr_pair(sample$student_teacher_ratio_avg_17_18, sample$lwage),
  deterministic_by_birth_aimag = deterministic_by_birth_aimag,
  deterministic_by_birth_aimag_year_at_17_18 = deterministic_by_birth_aimag_year,
  threshold_role = "threshold variable only; not used as IV",
  higher_value_interpretation = "more students per teacher / more crowded school environment"
)
write_csv(sample_diag, file.path(PATHS$out_tables, "T14a_student_teacher_avg_17_18_threshold_sample_diagnostics.csv"))

q_by_aimag_out <- sample |>
  group_by(birth_aimag) |>
  summarise(
    N = n(),
    n_unique_student_teacher_ratio_avg_17_18 = n_distinct(student_teacher_ratio_avg_17_18),
    mean_student_teacher_ratio_avg_17_18 = mean(student_teacher_ratio_avg_17_18, na.rm = TRUE),
    min_student_teacher_ratio_avg_17_18 = min(student_teacher_ratio_avg_17_18, na.rm = TRUE),
    max_student_teacher_ratio_avg_17_18 = max(student_teacher_ratio_avg_17_18, na.rm = TRUE),
    .groups = "drop"
  ) |>
  arrange(birth_aimag)
write_csv(q_by_aimag_out, file.path(PATHS$out_tables, "T14a_student_teacher_avg_17_18_by_birth_aimag.csv"))

q_by_cohort_out <- sample |>
  group_by(birth_cohort) |>
  summarise(
    N = n(),
    n_unique_student_teacher_ratio_avg_17_18 = n_distinct(student_teacher_ratio_avg_17_18),
    mean_student_teacher_ratio_avg_17_18 = mean(student_teacher_ratio_avg_17_18, na.rm = TRUE),
    min_birth_year = if ("birth_year" %in% names(sample)) min(as.numeric(birth_year), na.rm = TRUE) else NA_real_,
    max_birth_year = if ("birth_year" %in% names(sample)) max(as.numeric(birth_year), na.rm = TRUE) else NA_real_,
    .groups = "drop"
  ) |>
  arrange(birth_cohort)
write_csv(q_by_cohort_out, file.path(PATHS$out_tables, "T14a_student_teacher_avg_17_18_by_birth_cohort.csv"))

base_controls <- "age + age2 + female + married + urban"
fe_part <- "birth_aimag + birth_cohort + wave"

ols_args <- list(
  fml = as.formula(paste0("lwage ~ educ_years + ", base_controls, " | ", fe_part)),
  data = sample,
  vcov = ~birth_aimag,
  notes = FALSE
)
iv_args <- list(
  fml = as.formula(paste0("lwage ~ ", base_controls, " | ", fe_part, " | educ_years ~ parent_educ_mean")),
  data = sample,
  vcov = ~birth_aimag,
  notes = FALSE
)
fs_args <- list(
  fml = as.formula(paste0("educ_years ~ parent_educ_mean + ", base_controls, " | ", fe_part)),
  data = sample,
  vcov = ~birth_aimag,
  notes = FALSE
)
if ("hhweight" %in% names(sample)) {
  ols_args$weights <- ~hhweight
  iv_args$weights <- ~hhweight
  fs_args$weights <- ~hhweight
}

ols_fit <- do.call(feols, ols_args)
iv_fit <- do.call(feols, iv_args)
fs_fit <- do.call(feols, fs_args)

coef_extract <- function(fit, term) {
  ct <- coeftable(fit)
  if (!term %in% rownames(ct)) {
    return(tibble(term = term, estimate = NA_real_, se = NA_real_, p_value = NA_real_))
  }
  p_col <- grep("Pr\\(", colnames(ct), value = TRUE)[1]
  tibble(
    term = term,
    estimate = unname(ct[term, "Estimate"]),
    se = unname(ct[term, "Std. Error"]),
    p_value = unname(ct[term, p_col])
  )
}

ols_row <- coef_extract(ols_fit, "educ_years") |>
  mutate(model = "OLS baseline", N = nobs(ols_fit), .before = 1)
iv_row <- coef_extract(iv_fit, "fit_educ_years") |>
  mutate(model = "2SLS parent_educ_mean IV", N = nobs(iv_fit), .before = 1)
baseline_results <- bind_rows(ols_row, iv_row)
write_csv(baseline_results, file.path(PATHS$out_tables, "T14a_student_teacher_avg_17_18_baseline_ols_2sls.csv"))

fs_row <- coef_extract(fs_fit, "parent_educ_mean")
first_stage <- fs_row |>
  mutate(
    model = "first stage on student_teacher_ratio_avg_17_18 sample",
    N = nobs(fs_fit),
    t_stat = estimate / se,
    first_stage_F = t_stat^2,
    weak_iv_flag_F_lt_10 = first_stage_F < 10,
    .before = 1
  )
write_csv(first_stage, file.path(PATHS$out_tables, "T14a_student_teacher_avg_17_18_parent_iv_first_stage.csv"))

# -----------------------------------------------------------------------------
# Stage 28B: FE residualization and median-threshold matrix diagnostics
# -----------------------------------------------------------------------------

resid_path <- file.path(PATHS$data_proc, "ch_residualized_student_teacher_avg_17_18_parent_mean.rds")

residualize_var <- function(data, var) {
  fml <- as.formula(paste0(var, " ~ 1 | birth_aimag + birth_cohort + wave"))
  fit <- feols(fml, data = data, weights = ~hhweight, notes = FALSE)
  as.numeric(resid(fit))
}

vars_to_resid <- c(
  "lwage", "educ_years", "parent_educ_mean",
  "age", "age2", "female", "married", "urban"
)

resid_df <- sample
for (v in vars_to_resid) {
  resid_df[[paste0(v, "_r")]] <- residualize_var(sample, v)
}

saveRDS(resid_df, resid_path)

resid_diag <- bind_rows(lapply(vars_to_resid, function(v) {
  rv <- paste0(v, "_r")
  tibble(
    variable = v,
    residualized_variable = rv,
    mean = mean(resid_df[[rv]], na.rm = TRUE),
    sd = sd(resid_df[[rv]], na.rm = TRUE),
    min = min(resid_df[[rv]], na.rm = TRUE),
    max = max(resid_df[[rv]], na.rm = TRUE),
    missing_count = sum(is.na(resid_df[[rv]]) | !is.finite(resid_df[[rv]])),
    correlation_with_original = corr_pair(resid_df[[rv]], resid_df[[v]])
  )
}))
write_csv(resid_diag, file.path(PATHS$out_tables, "T14b_student_teacher_avg_17_18_ch_residualization_diagnostics.csv"))

make_matrix_diagnostics <- function(data, gamma) {
  low <- as.integer(data$student_teacher_ratio_avg_17_18 <= gamma)
  high <- as.integer(data$student_teacher_ratio_avg_17_18 > gamma)
  X <- cbind(
    educ_low = data$educ_years_r * low,
    educ_high = data$educ_years_r * high,
    as.matrix(data |> select(age_r, age2_r, female_r, married_r, urban_r))
  )
  Z <- cbind(
    iv_low = data$parent_educ_mean_r * low,
    iv_high = data$parent_educ_mean_r * high,
    as.matrix(data |> select(age_r, age2_r, female_r, married_r, urban_r))
  )
  y <- as.numeric(data$lwage_r)
  sqrt_w <- sqrt(as.numeric(data$hhweight))
  Xw <- X * sqrt_w
  Zw <- Z * sqrt_w
  yw <- y * sqrt_w
  ZtZ <- crossprod(Zw)
  ZtZ_inv <- safe_solve(ZtZ)
  XPZX <- if (is.null(ZtZ_inv)) {
    matrix(NA_real_, ncol(Xw), ncol(Xw))
  } else {
    crossprod(Xw, Zw) %*% ZtZ_inv %*% crossprod(Zw, Xw)
  }
  list(
    gamma = gamma,
    N = nrow(data),
    N_low = sum(low),
    N_high = sum(high),
    ncol_X = ncol(X),
    ncol_Z = ncol(Z),
    rank_X = qr(Xw)$rank,
    rank_Z = qr(Zw)$rank,
    rank_ZtZ = qr(ZtZ)$rank,
    ZtZ_invertible = !is.null(ZtZ_inv),
    rank_XPZX = if (all(is.finite(XPZX))) qr(XPZX)$rank else NA_integer_,
    XPZX_invertible = if (all(is.finite(XPZX))) !is.null(safe_solve(XPZX)) else FALSE,
    condition_number_XPZX = if (all(is.finite(XPZX))) condition_number(XPZX) else NA_real_,
    X = X,
    Z = Z,
    yw = yw,
    Xw = Xw,
    Zw = Zw
  )
}

gamma_example <- median(resid_df$student_teacher_ratio_avg_17_18, na.rm = TRUE)
mx <- make_matrix_diagnostics(resid_df, gamma_example)
matrix_diag <- tibble(
  gamma_example = mx$gamma,
  N = mx$N,
  N_low = mx$N_low,
  N_high = mx$N_high,
  ncol_X_gamma = mx$ncol_X,
  ncol_Z_gamma = mx$ncol_Z,
  rank_X_gamma = mx$rank_X,
  rank_Z_gamma = mx$rank_Z,
  ZtZ_rank = mx$rank_ZtZ,
  ZtZ_invertible = mx$ZtZ_invertible,
  XPZX_rank = mx$rank_XPZX,
  XPZX_invertible = mx$XPZX_invertible,
  XPZX_condition_number = mx$condition_number_XPZX,
  full_rank_X = mx$rank_X == mx$ncol_X,
  full_rank_Z = mx$rank_Z == mx$ncol_Z,
  safe_for_grid = mx$rank_X == mx$ncol_X &&
    mx$rank_Z == mx$ncol_Z &&
    isTRUE(mx$ZtZ_invertible) &&
    isTRUE(mx$XPZX_invertible)
)
write_csv(matrix_diag, file.path(PATHS$out_tables, "T14b_student_teacher_avg_17_18_ch_matrix_diagnostics.csv"))

# -----------------------------------------------------------------------------
# Stage 28C: 2SLS threshold grid search
# -----------------------------------------------------------------------------

y <- as.numeric(resid_df$lwage_r)
x <- as.numeric(resid_df$educ_years_r)
z <- as.numeric(resid_df$parent_educ_mean_r)
controls <- as.matrix(resid_df |> select(age_r, age2_r, female_r, married_r, urban_r))
q <- as.numeric(resid_df$student_teacher_ratio_avg_17_18)
w <- as.numeric(resid_df$hhweight)
n_regressors <- 7L
min_regime_n <- max(30L, n_regressors + 1L)

q10 <- qval(q, 0.10)
q90 <- qval(q, 0.90)
unique_trimmed <- sort(unique(q[q >= q10 & q <= q90]))
if (length(unique_trimmed) > 300L) {
  idx <- unique(round(seq(1, length(unique_trimmed), length.out = 300L)))
  candidates <- unique_trimmed[idx]
} else {
  candidates <- unique_trimmed
}

weighted_2sls_gamma <- function(gamma, data = resid_df) {
  y <- as.numeric(data$lwage_r)
  x <- as.numeric(data$educ_years_r)
  z <- as.numeric(data$parent_educ_mean_r)
  controls <- as.matrix(data |> select(age_r, age2_r, female_r, married_r, urban_r))
  q <- as.numeric(data$student_teacher_ratio_avg_17_18)
  w <- as.numeric(data$hhweight)
  sqrt_w <- sqrt(w)
  low <- as.integer(q <= gamma)
  high <- as.integer(q > gamma)
  warning_notes <- character()

  X <- cbind(educ_low = x * low, educ_high = x * high, controls)
  Z <- cbind(iv_low = z * low, iv_high = z * high, controls)
  Xw <- X * sqrt_w
  Zw <- Z * sqrt_w
  yw <- y * sqrt_w
  rank_X <- qr(Xw)$rank
  rank_Z <- qr(Zw)$rank

  if (sum(low) < min_regime_n || sum(high) < min_regime_n) {
    warning_notes <- c(warning_notes, paste0("too few observations in regime; minimum required ", min_regime_n))
  }
  if (rank_X < ncol(Xw)) warning_notes <- c(warning_notes, "rank_X deficient")
  if (rank_Z < ncol(Zw)) warning_notes <- c(warning_notes, "rank_Z deficient")

  if (length(warning_notes) > 0) {
    return(tibble(
      gamma = gamma,
      N = length(y),
      N_low = sum(low),
      N_high = sum(high),
      beta_low_2sls = NA_real_,
      beta_high_2sls = NA_real_,
      SSR_2SLS = Inf,
      rank_X = rank_X,
      rank_Z = rank_Z,
      rank_XPZX = NA_integer_,
      condition_number_XPZX = NA_real_,
      warning_flag = TRUE,
      warning_note = paste(unique(warning_notes), collapse = " | ")
    ))
  }

  ZtZ_inv <- safe_solve(crossprod(Zw))
  if (is.null(ZtZ_inv)) {
    return(tibble(
      gamma = gamma,
      N = length(y),
      N_low = sum(low),
      N_high = sum(high),
      beta_low_2sls = NA_real_,
      beta_high_2sls = NA_real_,
      SSR_2SLS = Inf,
      rank_X = rank_X,
      rank_Z = rank_Z,
      rank_XPZX = NA_integer_,
      condition_number_XPZX = NA_real_,
      warning_flag = TRUE,
      warning_note = "Z'Z singular"
    ))
  }

  XPZX <- crossprod(Xw, Zw) %*% ZtZ_inv %*% crossprod(Zw, Xw)
  XPZy <- crossprod(Xw, Zw) %*% ZtZ_inv %*% crossprod(Zw, yw)
  rank_XPZX <- qr(XPZX)$rank
  cond <- condition_number(XPZX)
  if (rank_XPZX < ncol(XPZX)) warning_notes <- c(warning_notes, "rank_XPZX deficient")
  if (is.finite(cond) && cond > 1e8) warning_notes <- c(warning_notes, "high condition number > 1e8")

  beta <- tryCatch(solve(XPZX, XPZy), error = function(e) e)
  if (inherits(beta, "error")) {
    return(tibble(
      gamma = gamma,
      N = length(y),
      N_low = sum(low),
      N_high = sum(high),
      beta_low_2sls = NA_real_,
      beta_high_2sls = NA_real_,
      SSR_2SLS = Inf,
      rank_X = rank_X,
      rank_Z = rank_Z,
      rank_XPZX = rank_XPZX,
      condition_number_XPZX = cond,
      warning_flag = TRUE,
      warning_note = paste(unique(c(warning_notes, "X'PzX singular")), collapse = " | ")
    ))
  }

  beta <- as.numeric(beta)
  u <- as.numeric(y - X %*% beta)
  ssr <- sum(w * u^2, na.rm = TRUE)
  tibble(
    gamma = gamma,
    N = length(y),
    N_low = sum(low),
    N_high = sum(high),
    beta_low_2sls = beta[1],
    beta_high_2sls = beta[2],
    SSR_2SLS = ssr,
    rank_X = rank_X,
    rank_Z = rank_Z,
    rank_XPZX = rank_XPZX,
    condition_number_XPZX = cond,
    warning_flag = length(warning_notes) > 0,
    warning_note = paste(unique(warning_notes), collapse = " | ")
  )
}

grid <- bind_rows(lapply(candidates, weighted_2sls_gamma))
valid_grid <- grid |>
  filter(
    is.finite(SSR_2SLS),
    !is.na(beta_low_2sls),
    !is.na(beta_high_2sls),
    rank_X == n_regressors,
    rank_Z == n_regressors,
    rank_XPZX == n_regressors
  )

if (nrow(valid_grid) == 0) stop("No valid student-teacher threshold grid points found.")

gamma_row <- valid_grid |>
  arrange(SSR_2SLS) |>
  slice(1)
gamma_hat <- gamma_row$gamma[1]

grid <- grid |>
  mutate(is_gamma_hat = abs(gamma - gamma_hat) < .Machine$double.eps^0.5)
write_csv(grid, file.path(PATHS$out_tables, "T14c_student_teacher_avg_17_18_ch_threshold_grid.csv"))

warning_summary <- grid |>
  filter(warning_flag) |>
  count(warning_note, name = "n")

gamma_hat_table <- gamma_row |>
  mutate(
    threshold_variable = "student_teacher_ratio_avg_17_18",
    threshold_interpretation = "students per teacher at ages 17-18; higher means more crowded/lower teacher intensity",
    n_candidates = length(candidates),
    n_valid_grid_points = nrow(valid_grid),
    n_skipped_or_invalid = length(candidates) - nrow(valid_grid),
    n_warning_flagged = sum(grid$warning_flag),
    min_SSR_2SLS = SSR_2SLS,
    safe_for_gmm = nrow(valid_grid) > 0 &&
      is.finite(SSR_2SLS) &&
      is.finite(condition_number_XPZX)
  ) |>
  select(
    threshold_variable,
    gamma_hat = gamma,
    threshold_interpretation,
    N, N_low, N_high,
    beta_low_2sls, beta_high_2sls,
    min_SSR_2SLS,
    rank_X, rank_Z, rank_XPZX,
    condition_number_XPZX,
    warning_flag, warning_note,
    n_candidates, n_valid_grid_points, n_skipped_or_invalid, n_warning_flagged,
    safe_for_gmm
  )
write_csv(gamma_hat_table, file.path(PATHS$out_tables, "T14c_student_teacher_avg_17_18_ch_gamma_hat.csv"))

objective_plot <- valid_grid |>
  ggplot(aes(x = gamma, y = SSR_2SLS)) +
  geom_line(color = "#2f5d62", linewidth = 0.7) +
  geom_point(color = "#2f5d62", size = 1.4) +
  geom_vline(xintercept = gamma_hat, color = "#b33939", linewidth = 0.7) +
  labs(
    x = "student_teacher_ratio_avg_17_18 threshold candidate",
    y = "Weighted 2SLS SSR",
    title = "Student-teacher ratio threshold objective",
    subtitle = paste0("gamma_hat = ", round(gamma_hat, 4),
                      " students per teacher")
  ) +
  theme_minimal(base_size = 11)
ggsave(
  filename = file.path(PATHS$out_figures, "student_teacher_avg_17_18_stage28c_2sls_objective_grid.png"),
  plot = objective_plot,
  width = 7,
  height = 4.5,
  dpi = 300
)

# -----------------------------------------------------------------------------
# Stage 28D: Two-step GMM slopes at gamma_hat
# -----------------------------------------------------------------------------

estimate_gmm_with_inference <- function(data, gamma) {
  data <- data |>
    mutate(
      low = as.integer(student_teacher_ratio_avg_17_18 <= gamma),
      high = as.integer(student_teacher_ratio_avg_17_18 > gamma)
    )
  y <- as.numeric(data$lwage_r)
  x <- as.numeric(data$educ_years_r)
  z <- as.numeric(data$parent_educ_mean_r)
  controls <- as.matrix(data |> select(age_r, age2_r, female_r, married_r, urban_r))
  X <- cbind(educ_low = x * data$low, educ_high = x * data$high, controls)
  Z <- cbind(iv_low = z * data$low, iv_high = z * data$high, controls)
  n <- nrow(data)
  k <- ncol(X)
  clusters <- if ("boot_cluster" %in% names(data)) as.factor(data$boot_cluster) else as.factor(data$birth_aimag)
  n_clusters <- n_distinct(clusters)
  sqrt_w <- sqrt(as.numeric(data$hhweight))
  yw <- y * sqrt_w
  Xw <- X * sqrt_w
  Zw <- Z * sqrt_w

  rank_X <- qr(Xw)$rank
  rank_Z <- qr(Zw)$rank
  ZtZ <- crossprod(Zw)
  rank_ZtZ <- qr(ZtZ)$rank
  rank_XZ <- qr(crossprod(Xw, Zw))$rank
  cond_ZtZ <- condition_number(ZtZ)

  if (rank_X < k || rank_Z < ncol(Z) || rank_ZtZ < ncol(Z)) return(NULL)
  W0 <- safe_solve(ZtZ / n)
  if (is.null(W0)) return(NULL)

  gmm_estimate <- function(W) {
    left <- crossprod(Xw, Zw) %*% W %*% crossprod(Zw, Xw)
    right <- crossprod(Xw, Zw) %*% W %*% crossprod(Zw, yw)
    inv <- safe_solve(left)
    if (is.null(inv)) return(NULL)
    as.numeric(inv %*% right)
  }

  beta1 <- gmm_estimate(W0)
  if (is.null(beta1)) return(NULL)
  u1 <- as.numeric(yw - Xw %*% beta1)
  moment_i <- Zw * u1

  S_robust <- crossprod(moment_i) / n
  cluster_levels <- levels(droplevels(clusters))
  cluster_moments <- matrix(0, nrow = length(cluster_levels), ncol = ncol(Zw))
  for (j in seq_along(cluster_levels)) {
    idx <- clusters == cluster_levels[j]
    cluster_moments[j, ] <- colSums(moment_i[idx, , drop = FALSE])
  }
  S_cluster <- crossprod(cluster_moments) / n

  S_robust_inv <- safe_solve(S_robust)
  S_cluster_inv_raw <- safe_solve(S_cluster)
  cond_S_robust <- condition_number(S_robust)
  cond_S_cluster <- condition_number(S_cluster)
  warning_notes <- character()
  S_cluster_inv <- S_cluster_inv_raw

  if (is.null(S_cluster_inv)) {
    warning_notes <- c(warning_notes, "S_cluster singular; using heteroskedastic-robust S")
  }
  if (!is.null(S_cluster_inv) && is.finite(cond_S_cluster) && cond_S_cluster > 1e10) {
    warning_notes <- c(warning_notes, "S_cluster high condition number > 1e10; using heteroskedastic-robust S")
    S_cluster_inv <- NULL
  }
  if (is.null(S_robust_inv)) warning_notes <- c(warning_notes, "S_robust singular")

  if (!is.null(S_cluster_inv)) {
    S_main <- S_cluster
    W1 <- S_cluster_inv
    weighting_matrix_used <- "cluster-robust S by birth_aimag"
    inference_reference <- paste0("t distribution with df=", n_clusters - 1)
    p_fun <- function(t) 2 * pt(abs(t), df = n_clusters - 1, lower.tail = FALSE)
  } else if (!is.null(S_robust_inv)) {
    S_main <- S_robust
    W1 <- S_robust_inv
    weighting_matrix_used <- "heteroskedastic-robust S"
    inference_reference <- "normal approximation"
    p_fun <- function(t) 2 * pnorm(abs(t), lower.tail = FALSE)
  } else {
    return(NULL)
  }

  beta2 <- gmm_estimate(W1)
  if (is.null(beta2)) return(NULL)

  A <- crossprod(Zw, Xw) / n
  B <- t(A) %*% W1 %*% A
  rank_XZWZX <- qr(B)$rank
  cond_XZWZX <- condition_number(B)
  B_inv <- safe_solve(B)
  if (is.null(B_inv)) return(NULL)

  V <- B_inv %*% t(A) %*% W1 %*% S_main %*% W1 %*% A %*% B_inv / n
  se <- sqrt(pmax(diag(V), 0))
  t_stats <- beta2 / se
  p_values <- p_fun(t_stats)
  coef_names <- colnames(X)

  beta_low <- beta2[1]
  beta_high <- beta2[2]
  beta_diff <- beta_high - beta_low
  R <- matrix(0, nrow = 1, ncol = k)
  colnames(R) <- coef_names
  R[1, "educ_high"] <- 1
  R[1, "educ_low"] <- -1
  var_diff <- as.numeric(R %*% V %*% t(R))
  se_diff <- sqrt(max(var_diff, 0))
  t_diff <- beta_diff / se_diff
  wald_stat <- t_diff^2
  wald_p <- if (weighting_matrix_used == "cluster-robust S by birth_aimag") {
    pf(wald_stat, df1 = 1, df2 = n_clusters - 1, lower.tail = FALSE)
  } else {
    pchisq(wald_stat, df = 1, lower.tail = FALSE)
  }

  near_singular_warning <- any(c(
    rank_X < k,
    rank_Z < ncol(Z),
    rank_ZtZ < ncol(Z),
    rank_XZ < k,
    rank_XZWZX < k,
    is.finite(cond_ZtZ) && cond_ZtZ > 1e8,
    is.finite(cond_XZWZX) && cond_XZWZX > 1e8,
    is.finite(cond_S_robust) && cond_S_robust > 1e10,
    is.finite(cond_S_cluster) && cond_S_cluster > 1e10
  ))
  if (near_singular_warning) {
    warning_notes <- c(warning_notes, "high condition number or rank warning in GMM matrices")
  }

  list(
    gamma = gamma,
    N = n,
    N_low = sum(data$low),
    N_high = sum(data$high),
    n_clusters = n_clusters,
    coef_table = tibble(
      term = coef_names,
      estimate = beta2,
      se = se,
      t_stat = t_stats,
      p_value = p_values,
      inference_reference = inference_reference,
      weighting_matrix_used = weighting_matrix_used
    ),
    matrix_diag = tibble(
      gamma_hat = gamma,
      N = n,
      N_low = sum(data$low),
      N_high = sum(data$high),
      rank_X = rank_X,
      rank_Z = rank_Z,
      rank_ZtZ = rank_ZtZ,
      rank_XZ = rank_XZ,
      rank_XZ_W_ZX = rank_XZWZX,
      condition_number_ZtZ = cond_ZtZ,
      condition_number_S_robust = cond_S_robust,
      condition_number_S_cluster = cond_S_cluster,
      condition_number_XZ_W_ZX = cond_XZWZX,
      S_cluster_invertible = !is.null(S_cluster_inv_raw),
      S_robust_invertible = !is.null(S_robust_inv),
      near_singular_warning = near_singular_warning,
      warning_note = paste(unique(warning_notes), collapse = " | ")
    ),
    wald_test = tibble(
      gamma_hat = gamma,
      test = "beta_low_GMM = beta_high_GMM",
      beta_difference_high_minus_low = beta_diff,
      se_difference = se_diff,
      t_stat = t_diff,
      wald_statistic = wald_stat,
      p_value = wald_p,
      df1 = 1,
      df2 = ifelse(weighting_matrix_used == "cluster-robust S by birth_aimag", n_clusters - 1, NA_real_),
      inference_reference = ifelse(weighting_matrix_used == "cluster-robust S by birth_aimag", "F(1, G-1)", "chi-square(1)"),
      weighting_matrix_used = weighting_matrix_used
    ),
    beta_low = beta_low,
    beta_high = beta_high,
    beta_diff = beta_diff,
    weighting_matrix_used = weighting_matrix_used,
    inference_reference = inference_reference,
    warning_note = paste(unique(warning_notes), collapse = " | ")
  )
}

gmm_fit <- estimate_gmm_with_inference(resid_df, gamma_hat)
if (is.null(gmm_fit)) stop("Two-step GMM failed at student-teacher gamma_hat.")

matrix_gmm_diag <- gmm_fit$matrix_diag
final_results <- gmm_fit$coef_table |>
  filter(term %in% c("educ_low", "educ_high")) |>
  transmute(
    threshold_variable = "student_teacher_ratio_avg_17_18",
    gamma_hat = gamma_hat,
    term,
    estimate,
    se,
    t_stat,
    p_value,
    N = gmm_fit$N,
    N_low = gmm_fit$N_low,
    N_high = gmm_fit$N_high,
    weighting_matrix_used,
    inference_reference,
    beta_difference_high_minus_low = gmm_fit$beta_diff,
    warning_note = gmm_fit$warning_note
  )
wald_test <- gmm_fit$wald_test
comparison <- gamma_hat_table |>
  transmute(
    threshold_variable,
    gamma_hat,
    beta_low_2sls,
    beta_high_2sls
  ) |>
  mutate(
    beta_low_GMM = gmm_fit$beta_low,
    beta_high_GMM = gmm_fit$beta_high,
    beta_diff_GMM_high_minus_low = gmm_fit$beta_diff,
    inference_method = paste0("two-step GMM, ", gmm_fit$weighting_matrix_used, ", ", gmm_fit$inference_reference)
  )

write_csv(matrix_gmm_diag, file.path(PATHS$out_tables, "T14d_student_teacher_avg_17_18_ch_gmm_matrix_diagnostics.csv"))
write_csv(final_results, file.path(PATHS$out_tables, "T14d_student_teacher_avg_17_18_ch_gmm_final_results.csv"))
write_csv(wald_test, file.path(PATHS$out_tables, "T14d_student_teacher_avg_17_18_ch_gmm_wald_test.csv"))
write_csv(comparison, file.path(PATHS$out_tables, "T14d_student_teacher_avg_17_18_ch_2sls_vs_gmm_comparison.csv"))

crit <- if (gmm_fit$weighting_matrix_used == "cluster-robust S by birth_aimag") {
  qt(0.975, df = gmm_fit$n_clusters - 1)
} else {
  qnorm(0.975)
}
low_regime_label <- school_quality_label(as.numeric(gamma_hat[1]), "low")
high_regime_label <- school_quality_label(as.numeric(gamma_hat[1]), "high")
plot_data <- final_results |>
  mutate(
    regime = case_when(
      term == "educ_low" ~ low_regime_label,
      term == "educ_high" ~ high_regime_label,
      TRUE ~ as.character(term)
    ),
    ci_low = estimate - crit * se,
    ci_high = estimate + crit * se,
    regime = factor(regime, levels = c(low_regime_label, high_regime_label))
  )

gmm_plot <- ggplot(plot_data, aes(x = regime, y = estimate)) +
  geom_hline(yintercept = 0, color = "grey70", linewidth = 0.4) +
  geom_pointrange(aes(ymin = ci_low, ymax = ci_high), color = "#2f5d62", linewidth = 0.8) +
  labs(
    x = NULL,
    y = "Two-step GMM return to education",
    title = "Student-teacher ratio regime-specific returns",
    subtitle = paste0("Threshold: ", round(gamma_hat, 2), " students per teacher at ages 17-18")
  ) +
  theme_minimal(base_size = 11)
ggsave(
  filename = file.path(PATHS$out_figures, "student_teacher_avg_17_18_stage28d_gmm_regime_returns.png"),
  plot = gmm_plot,
  width = 7,
  height = 4.5,
  dpi = 300
)

# -----------------------------------------------------------------------------
# Stage 28E: Cluster bootstrap inference
# -----------------------------------------------------------------------------

gamma_candidates_for <- function(data) {
  q <- as.numeric(data$student_teacher_ratio_avg_17_18)
  q10 <- qval(q, 0.10)
  q90 <- qval(q, 0.90)
  u <- sort(unique(q[q >= q10 & q <= q90]))
  if (length(u) > 300L) {
    idx <- unique(round(seq(1, length(u), length.out = 300L)))
    u[idx]
  } else {
    u
  }
}

estimate_2sls_grid_boot <- function(data, gamma_grid = NULL) {
  if (is.null(gamma_grid)) gamma_grid <- gamma_candidates_for(data)
  if (length(gamma_grid) == 0) return(NULL)
  fits <- lapply(gamma_grid, function(g) weighted_2sls_gamma(g, data = data))
  tbl <- bind_rows(fits)
  valid <- tbl |>
    filter(
      is.finite(SSR_2SLS),
      !is.na(beta_low_2sls),
      !is.na(beta_high_2sls),
      rank_X == n_regressors,
      rank_Z == n_regressors,
      rank_XPZX == n_regressors
    )
  if (nrow(valid) == 0) return(NULL)
  valid |> arrange(SSR_2SLS) |> slice(1)
}

estimate_gmm_boot <- function(data, gamma) {
  fit <- estimate_gmm_with_inference(data, gamma)
  if (is.null(fit)) return(NULL)
  list(
    beta_low = fit$beta_low,
    beta_high = fit$beta_high,
    beta_diff = fit$beta_diff,
    N_low = fit$N_low,
    N_high = fit$N_high,
    weighting = fit$weighting_matrix_used,
    warning_note = fit$warning_note
  )
}

cluster_boot_sample <- function(data, cluster_var = "birth_aimag") {
  cl <- levels(droplevels(as.factor(data[[cluster_var]])))
  sampled <- sample(cl, size = length(cl), replace = TRUE)
  pieces <- vector("list", length(sampled))
  for (j in seq_along(sampled)) {
    pieces[[j]] <- data |>
      filter(.data[[cluster_var]] == sampled[j]) |>
      mutate(boot_cluster = paste0("boot_cluster_", j))
  }
  bind_rows(pieces)
}

B_default <- 399L
B_env <- Sys.getenv("CH_BOOT_B", unset = "")
B <- if (nzchar(B_env)) as.integer(B_env) else B_default
if (is.na(B) || B <= 0) B <- B_default
if (B < B_default) {
  cat("WARNING: bootstrap replications reduced to B =", B, "\n")
}

cat("Bootstrap replications:", B, "\n")
cat("Observed gamma:", gamma_hat, "\n")
cat("Observed beta diff:", gmm_fit$beta_diff, "\n\n")

run_boot_draw <- function(b) {
  boot <- cluster_boot_sample(resid_df)
  warning_note <- character()
  failed <- FALSE

  grid_fit <- tryCatch(estimate_2sls_grid_boot(boot), error = function(e) e)
  if (inherits(grid_fit, "error") || is.null(grid_fit)) {
    failed <- TRUE
    warning_note <- c(warning_note, if (inherits(grid_fit, "error")) conditionMessage(grid_fit) else "grid failed")
    return(tibble(
      b = b,
      gamma_boot = NA_real_,
      beta_low_boot = NA_real_,
      beta_high_boot = NA_real_,
      beta_diff_boot = NA_real_,
      N_boot = nrow(boot),
      N_low_boot = NA_integer_,
      N_high_boot = NA_integer_,
      warning_flag = TRUE,
      failed_flag = TRUE,
      warning_note = paste(warning_note, collapse = " | ")
    ))
  }

  gmm_boot <- tryCatch(estimate_gmm_boot(boot, grid_fit$gamma), error = function(e) e)
  if (inherits(gmm_boot, "error") || is.null(gmm_boot)) {
    failed <- TRUE
    warning_note <- c(warning_note, if (inherits(gmm_boot, "error")) conditionMessage(gmm_boot) else "gmm failed")
    return(tibble(
      b = b,
      gamma_boot = grid_fit$gamma,
      beta_low_boot = NA_real_,
      beta_high_boot = NA_real_,
      beta_diff_boot = NA_real_,
      N_boot = nrow(boot),
      N_low_boot = grid_fit$N_low,
      N_high_boot = grid_fit$N_high,
      warning_flag = TRUE,
      failed_flag = TRUE,
      warning_note = paste(warning_note, collapse = " | ")
    ))
  }

  warning_note <- c(warning_note, gmm_boot$warning_note)
  warning_note <- warning_note[nzchar(warning_note)]
  tibble(
    b = b,
    gamma_boot = grid_fit$gamma,
    beta_low_boot = gmm_boot$beta_low,
    beta_high_boot = gmm_boot$beta_high,
    beta_diff_boot = gmm_boot$beta_diff,
    N_boot = nrow(boot),
    N_low_boot = gmm_boot$N_low,
    N_high_boot = gmm_boot$N_high,
    warning_flag = length(warning_note) > 0,
    failed_flag = failed,
    warning_note = paste(unique(warning_note), collapse = " | ")
  )
}

cores_available <- parallel::detectCores(logical = TRUE)
cores_default <- max(1L, min(cores_available - 1L, 8L))
cores_env <- Sys.getenv("CH_BOOT_CORES", unset = "")
n_cores <- if (nzchar(cores_env)) as.integer(cores_env) else cores_default
if (is.na(n_cores) || n_cores < 1L) n_cores <- 1L
n_cores <- min(n_cores, B)

cat("Bootstrap parallel cores:", n_cores, "of", cores_available, "available logical cores\n")

if (n_cores > 1L) {
  cl <- parallel::makeCluster(n_cores)
  on.exit(try(parallel::stopCluster(cl), silent = TRUE), add = TRUE)
  parallel::clusterSetRNGStream(cl, 20260426)
  parallel::clusterEvalQ(cl, {
    suppressPackageStartupMessages({
      library(dplyr)
      library(tibble)
    })
    NULL
  })
  parallel::clusterExport(
    cl,
    varlist = c(
      "resid_df", "cluster_boot_sample", "estimate_2sls_grid_boot",
      "estimate_gmm_boot", "run_boot_draw", "weighted_2sls_gamma",
      "estimate_gmm_with_inference", "gamma_candidates_for",
      "safe_solve", "condition_number", "qval", "n_regressors", "min_regime_n"
    ),
    envir = environment()
  )
  draws <- parallel::parLapply(cl, seq_len(B), run_boot_draw)
} else {
  draws <- vector("list", B)
  for (b in seq_len(B)) {
    if (b %% 25 == 0) cat("Bootstrap draw", b, "of", B, "\n")
    draws[[b]] <- run_boot_draw(b)
  }
}

boot_draws <- bind_rows(draws)
write_csv(boot_draws, file.path(PATHS$out_tables, "T14e_student_teacher_avg_17_18_ch_bootstrap_draws.csv"))

success <- boot_draws |>
  filter(!failed_flag, is.finite(beta_diff_boot), is.finite(gamma_boot))
n_success <- nrow(success)
n_failed <- sum(boot_draws$failed_flag)
if (n_success == 0) stop("No successful bootstrap draws.")

qfun <- function(x, p) as.numeric(quantile(x, p, na.rm = TRUE, names = FALSE))
beta_diff_observed <- gmm_fit$beta_diff
beta_diff_centered <- success$beta_diff_boot - mean(success$beta_diff_boot, na.rm = TRUE)
p_boot <- mean(abs(beta_diff_centered) >= abs(beta_diff_observed), na.rm = TRUE)

bootstrap_inference <- tibble(
  B_requested = B,
  n_success = n_success,
  n_failed = n_failed,
  n_warning = sum(boot_draws$warning_flag, na.rm = TRUE),
  n_clusters = n_distinct(resid_df$birth_aimag),
  gamma_observed = gamma_hat,
  gamma_q025 = qfun(success$gamma_boot, 0.025),
  gamma_q05 = qfun(success$gamma_boot, 0.05),
  gamma_q50 = qfun(success$gamma_boot, 0.50),
  gamma_q95 = qfun(success$gamma_boot, 0.95),
  gamma_q975 = qfun(success$gamma_boot, 0.975),
  beta_low_observed = gmm_fit$beta_low,
  beta_low_q025 = qfun(success$beta_low_boot, 0.025),
  beta_low_q975 = qfun(success$beta_low_boot, 0.975),
  beta_high_observed = gmm_fit$beta_high,
  beta_high_q025 = qfun(success$beta_high_boot, 0.025),
  beta_high_q975 = qfun(success$beta_high_boot, 0.975),
  beta_diff_observed = beta_diff_observed,
  beta_diff_q025 = qfun(success$beta_diff_boot, 0.025),
  beta_diff_q975 = qfun(success$beta_diff_boot, 0.975),
  beta_diff_ci_contains_zero = beta_diff_q025 <= 0 & beta_diff_q975 >= 0,
  bootstrap_p_value = p_boot
)
write_csv(bootstrap_inference, file.path(PATHS$out_tables, "T14e_student_teacher_avg_17_18_ch_bootstrap_inference.csv"))

asymptotic_vs_bootstrap <- tibble(
  beta_diff_observed = beta_diff_observed,
  asymptotic_wald_p_value = wald_test$p_value[1],
  bootstrap_p_value = p_boot,
  beta_diff_boot_ci_low = bootstrap_inference$beta_diff_q025,
  beta_diff_boot_ci_high = bootstrap_inference$beta_diff_q975,
  beta_diff_ci_contains_zero = bootstrap_inference$beta_diff_ci_contains_zero,
  conclusion = ifelse(
    p_boot < 0.05 && !bootstrap_inference$beta_diff_ci_contains_zero,
    "Bootstrap supports student-teacher-ratio threshold heterogeneity at 5%.",
    "Bootstrap does not strongly support student-teacher-ratio threshold heterogeneity at 5%."
  )
)
write_csv(asymptotic_vs_bootstrap, file.path(PATHS$out_tables, "T14e_student_teacher_avg_17_18_ch_asymptotic_vs_bootstrap.csv"))

gamma_plot <- ggplot(success, aes(x = gamma_boot)) +
  geom_histogram(bins = 25, fill = "#2f5d62", color = "white") +
  geom_vline(xintercept = gamma_hat, color = "#b33939", linewidth = 0.8) +
  labs(
    x = "Bootstrap gamma",
    y = "Draws",
    title = "Bootstrap distribution of student-teacher threshold"
  ) +
  theme_minimal(base_size = 11)
ggsave(
  filename = file.path(PATHS$out_figures, "student_teacher_avg_17_18_stage28e_gamma_bootstrap_distribution.png"),
  plot = gamma_plot,
  width = 7,
  height = 4.5,
  dpi = 300
)

diff_plot <- ggplot(success, aes(x = beta_diff_boot)) +
  geom_histogram(bins = 35, fill = "#2f5d62", color = "white") +
  geom_vline(xintercept = beta_diff_observed, color = "#b33939", linewidth = 0.8) +
  geom_vline(xintercept = 0, color = "grey35", linewidth = 0.6, linetype = "dashed") +
  labs(
    x = "Bootstrap beta_high - beta_low",
    y = "Draws",
    title = "Bootstrap distribution of student-teacher regime difference"
  ) +
  theme_minimal(base_size = 11)
ggsave(
  filename = file.path(PATHS$out_figures, "student_teacher_avg_17_18_stage28e_beta_diff_bootstrap_distribution.png"),
  plot = diff_plot,
  width = 7,
  height = 4.5,
  dpi = 300
)

heterogeneity_supported <- p_boot < 0.05 && !bootstrap_inference$beta_diff_ci_contains_zero
interpretation <- if (heterogeneity_supported) {
  "Bootstrap inference supports education returns differing across student-teacher-ratio regimes at the 5% level."
} else {
  "Bootstrap inference does not strongly support student-teacher-ratio threshold heterogeneity in education returns at the 5% level."
}

# -----------------------------------------------------------------------------
# Final report
# -----------------------------------------------------------------------------

report_lines <- c(
  "# Student-teacher Ratio at ages 17-18 IV Threshold Pipeline",
  "",
  paste0("Generated: ", Sys.time()),
  "",
  "## 1. Empirical Design",
  "- Outcome: `lwage`.",
  "- Endogenous regressor: `educ_years`.",
  "- IV: `parent_educ_mean`.",
  "- Threshold variable: `student_teacher_ratio_avg_17_18`.",
  "- Controls: age, age2, female, married, urban.",
  "- Fixed effects residualized: birth_aimag, birth_cohort, wave.",
  "- Weights: hhweight.",
  "- Cluster/bootstrap unit: birth_aimag.",
  "- Higher threshold values mean more students per teacher, i.e. more crowded/lower teacher-intensity school environment.",
  "- `student_teacher_ratio_avg_17_18` is not used as an IV.",
  "",
  "## 2. Sample Diagnostics",
  paste0("- N: ", sample_diag$N),
  paste0("- birth_aimag clusters: ", sample_diag$n_birth_aimag_clusters),
  paste0("- birth_cohort groups: ", sample_diag$n_birth_cohort_groups),
  paste0("- waves: ", sample_diag$n_waves),
  paste0("- birth_year range: ", fmt(sample_diag$birth_year_min, 0), " to ", fmt(sample_diag$birth_year_max, 0)),
  paste0("- year_at_17_18 range: ", fmt(sample_diag$year_at_17_18_min, 0), " to ", fmt(sample_diag$year_at_17_18_max, 0)),
  paste0("- student_teacher_ratio_avg_17_18 min/p10/p25/p50/p75/p90/max: ",
         fmt(sample_diag$student_teacher_ratio_avg_17_18_min), " / ",
         fmt(sample_diag$student_teacher_ratio_avg_17_18_p10), " / ",
         fmt(sample_diag$student_teacher_ratio_avg_17_18_p25), " / ",
         fmt(sample_diag$student_teacher_ratio_avg_17_18_p50), " / ",
         fmt(sample_diag$student_teacher_ratio_avg_17_18_p75), " / ",
         fmt(sample_diag$student_teacher_ratio_avg_17_18_p90), " / ",
         fmt(sample_diag$student_teacher_ratio_avg_17_18_max)),
  paste0("- unique threshold values: ", sample_diag$student_teacher_ratio_avg_17_18_unique_values),
  paste0("- corr(threshold, educ_years): ", fmt(sample_diag$corr_student_teacher_ratio_avg_17_18_educ_years)),
  paste0("- corr(threshold, parent_educ_mean): ", fmt(sample_diag$corr_student_teacher_ratio_avg_17_18_parent_educ_mean)),
  paste0("- corr(threshold, lwage): ", fmt(sample_diag$corr_student_teacher_ratio_avg_17_18_lwage)),
  paste0("- deterministic by birth_aimag: ", sample_diag$deterministic_by_birth_aimag),
  paste0("- deterministic by birth_aimag + year_at_17_18: ", sample_diag$deterministic_by_birth_aimag_year_at_17_18),
  "",
  "## 3. Baseline OLS and 2SLS on This Sample",
  paste0("- OLS beta: ", fmt(ols_row$estimate), ", SE: ", fmt(ols_row$se), ", p-value: ", fmt(ols_row$p_value)),
  paste0("- 2SLS beta: ", fmt(iv_row$estimate), ", SE: ", fmt(iv_row$se), ", p-value: ", fmt(iv_row$p_value)),
  paste0("- First-stage parent_educ_mean coefficient: ", fmt(first_stage$estimate), ", SE: ", fmt(first_stage$se), ", F: ", fmt(first_stage$first_stage_F)),
  paste0("- Weak-IV flag F < 10: ", first_stage$weak_iv_flag_F_lt_10),
  "",
  "## 4. Residualization and Matrix Diagnostics",
  paste0("- Residualized dataset: ", resid_path),
  paste0("- Residualization succeeded: ", all(resid_diag$missing_count == 0)),
  paste0("- Median threshold example gamma: ", fmt(matrix_diag$gamma_example)),
  paste0("- Median example N_low/N_high: ", matrix_diag$N_low, " / ", matrix_diag$N_high),
  paste0("- Median example rank(X)/rank(Z)/rank(X'PzX): ",
         matrix_diag$rank_X_gamma, " / ", matrix_diag$rank_Z_gamma, " / ", matrix_diag$XPZX_rank),
  paste0("- Median example X'PzX condition number: ", fmt(matrix_diag$XPZX_condition_number)),
  "",
  "## 5. 2SLS Threshold Grid",
  paste0("- Candidate thresholds: ", gamma_hat_table$n_candidates),
  paste0("- Valid grid points: ", gamma_hat_table$n_valid_grid_points),
  paste0("- Skipped/invalid grid points: ", gamma_hat_table$n_skipped_or_invalid),
  paste0("- Warning-flagged grid points: ", gamma_hat_table$n_warning_flagged),
  paste0("- gamma_hat: ", fmt(gamma_hat)),
  paste0("- N_low/N_high at gamma_hat: ", gamma_hat_table$N_low, " / ", gamma_hat_table$N_high),
  paste0("- beta_low_2SLS: ", fmt(gamma_hat_table$beta_low_2sls)),
  paste0("- beta_high_2SLS: ", fmt(gamma_hat_table$beta_high_2sls)),
  paste0("- minimum SSR: ", fmt(gamma_hat_table$min_SSR_2SLS)),
  "",
  "## 6. GMM Slopes at gamma_hat",
  paste0("- Weighting matrix: ", gmm_fit$weighting_matrix_used),
  paste0("- beta_low_GMM: ", fmt(gmm_fit$beta_low), ", SE: ", fmt(final_results$se[final_results$term == "educ_low"]), ", p-value: ", fmt(final_results$p_value[final_results$term == "educ_low"])),
  paste0("- beta_high_GMM: ", fmt(gmm_fit$beta_high), ", SE: ", fmt(final_results$se[final_results$term == "educ_high"]), ", p-value: ", fmt(final_results$p_value[final_results$term == "educ_high"])),
  paste0("- beta_high - beta_low: ", fmt(gmm_fit$beta_diff)),
  paste0("- Wald p-value: ", fmt(wald_test$p_value)),
  "",
  "## 7. Bootstrap Inference",
  paste0("- Requested bootstrap replications: ", B),
  paste0("- Successful draws: ", bootstrap_inference$n_success),
  paste0("- Failed draws: ", bootstrap_inference$n_failed),
  paste0("- Warning-flagged draws: ", bootstrap_inference$n_warning),
  paste0("- gamma 2.5% / 5% / 50% / 95% / 97.5%: ",
         fmt(bootstrap_inference$gamma_q025), " / ",
         fmt(bootstrap_inference$gamma_q05), " / ",
         fmt(bootstrap_inference$gamma_q50), " / ",
         fmt(bootstrap_inference$gamma_q95), " / ",
         fmt(bootstrap_inference$gamma_q975)),
  paste0("- beta_low percentile CI: [", fmt(bootstrap_inference$beta_low_q025), ", ", fmt(bootstrap_inference$beta_low_q975), "]"),
  paste0("- beta_high percentile CI: [", fmt(bootstrap_inference$beta_high_q025), ", ", fmt(bootstrap_inference$beta_high_q975), "]"),
  paste0("- beta_diff percentile CI: [", fmt(bootstrap_inference$beta_diff_q025), ", ", fmt(bootstrap_inference$beta_diff_q975), "]"),
  paste0("- beta_diff CI contains zero: ", bootstrap_inference$beta_diff_ci_contains_zero),
  paste0("- bootstrap p-value: ", fmt(bootstrap_inference$bootstrap_p_value)),
  "",
  "## 8. Inference Conclusion",
  interpretation,
  "Do not interpret student_teacher_ratio_avg_17_18 as causing wage returns.",
  "",
  "## 9. Caveats",
  "- `student_teacher_ratio_avg_17_18` is a school-quality/crowding proxy, not a home-environment proxy.",
  "- The threshold sample is much smaller because complete school-supply data at ages 17 and 18 is available only for cohorts whose late-school exposure falls in the observed school-supply panel.",
  "- Only 22 birth_aimag clusters are available; cluster bootstrap inference can be noisy.",
  "- The threshold is tied to birth_aimag and year_at_17_18, so it is not individual-level random variation.",
  "- High condition numbers should be monitored when comparing with prior threshold results.",
  "- Parental education may affect wages through family background, networks, and unobserved ability channels.",
  "- FE residualization is an approximation to a high-dimensional fixed-effects threshold model.",
  "- This is a Caner-Hansen-style IV threshold implementation, not a claim that threshold placement is causal."
)

writeLines(report_lines, file.path(PATHS$out_root, "reports", "student_teacher_avg_17_18_ch_full_pipeline_summary.md"), useBytes = TRUE)

cat("Stage 28A sample diagnostics:\n")
print(sample_diag)
cat("\nBaseline results:\n")
print(baseline_results)
cat("\nFirst stage:\n")
print(first_stage)
cat("\nStage 28B matrix diagnostics:\n")
print(matrix_diag)
cat("\nStage 28C gamma_hat:\n")
print(gamma_hat_table)
cat("\nStage 28D GMM final results:\n")
print(final_results)
cat("\nStage 28D Wald test:\n")
print(wald_test)
cat("\nStage 28E bootstrap inference:\n")
print(bootstrap_inference)
cat("\nConclusion:", interpretation, "\n")
cat("\nCompleted:", as.character(Sys.time()), "\n")

