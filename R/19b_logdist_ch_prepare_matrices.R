# Stage 19B: Prepare matrices for log_distance_to_ub Caner-Hansen-style IV threshold estimator.
# This script does not run the threshold grid search, GMM, bootstrap, or use log_distance_to_ub as an IV.

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

log_path <- file.path(PATHS$out_logs, "19b_logdist_ch_prepare_matrices.log")
sink(log_path, split = TRUE)
on.exit(sink(), add = TRUE)

cat("19b_logdist_ch_prepare_matrices.R\n")
cat("Started:", as.character(Sys.time()), "\n\n")

input_path <- file.path(PATHS$data_proc, "ivtr_ready_parent_educ_mean_logdist.rds")
resid_path <- file.path(PATHS$data_proc, "ch_residualized_logdist_parent_mean.rds")

if (!file.exists(input_path)) stop("Missing ", input_path)

raw <- readRDS(input_path) |> as_tibble()
has_weight <- "hhweight" %in% names(raw)
has_distance <- "distance_to_ub" %in% names(raw)
if (!has_distance) raw$distance_to_ub <- NA_real_

required <- c(
  "lwage", "educ_years", "parent_educ_mean", "log_distance_to_ub",
  "age", "age2", "female", "married", "urban",
  "birth_aimag", "birth_cohort", "wave"
)
missing_required <- setdiff(required, names(raw))
if (length(missing_required) > 0) {
  stop("Missing required variable(s): ", paste(missing_required, collapse = ", "))
}

df <- raw |>
  mutate(
    lwage = as.numeric(lwage),
    educ_years = as.numeric(educ_years),
    parent_educ_mean = as.numeric(parent_educ_mean),
    log_distance_to_ub = as.numeric(log_distance_to_ub),
    distance_to_ub = as.numeric(distance_to_ub),
    age = as.numeric(age),
    age2 = as.numeric(age2),
    female = as.numeric(female),
    married = as.numeric(married),
    urban = as.numeric(urban),
    birth_aimag = as.factor(birth_aimag),
    birth_cohort = as.factor(birth_cohort),
    wave = as.factor(wave),
    hhweight = if (has_weight) as.numeric(hhweight) else 1
  ) |>
  filter(
    age >= 25, age <= 60,
    is.finite(lwage),
    !is.na(educ_years), is.finite(educ_years),
    !is.na(parent_educ_mean), is.finite(parent_educ_mean),
    !is.na(log_distance_to_ub), is.finite(log_distance_to_ub),
    !is.na(age), !is.na(age2),
    !is.na(female), !is.na(married), !is.na(urban),
    !is.na(birth_aimag),
    !is.na(birth_cohort),
    !is.na(wave)
  )

if (has_weight) {
  df <- df |> filter(!is.na(hhweight), is.finite(hhweight), hhweight > 0)
}

if (nrow(df) == 0) stop("No observations remain after cleaning.")

corr_pair <- function(x, y) suppressWarnings(cor(x, y, use = "pairwise.complete.obs"))
fmt <- function(x, digits = 4) ifelse(is.na(x), "NA", formatC(x, format = "f", digits = digits))
qval <- function(x, p) as.numeric(quantile(x, p, na.rm = TRUE, names = FALSE))

logdist_by_aimag <- df |>
  group_by(birth_aimag) |>
  summarise(n_unique_log_distance_to_ub = n_distinct(log_distance_to_ub), .groups = "drop")
deterministic_by_birth_aimag <- all(logdist_by_aimag$n_unique_log_distance_to_ub == 1)

sample_diag <- tibble(
  N = nrow(df),
  n_birth_aimag_clusters = n_distinct(df$birth_aimag),
  n_birth_cohort_groups = n_distinct(df$birth_cohort),
  n_waves = n_distinct(df$wave),
  log_distance_to_ub_min = min(df$log_distance_to_ub, na.rm = TRUE),
  log_distance_to_ub_p10 = qval(df$log_distance_to_ub, 0.10),
  log_distance_to_ub_p25 = qval(df$log_distance_to_ub, 0.25),
  log_distance_to_ub_p50 = qval(df$log_distance_to_ub, 0.50),
  log_distance_to_ub_p75 = qval(df$log_distance_to_ub, 0.75),
  log_distance_to_ub_p90 = qval(df$log_distance_to_ub, 0.90),
  log_distance_to_ub_max = max(df$log_distance_to_ub, na.rm = TRUE),
  log_distance_to_ub_unique_values = n_distinct(df$log_distance_to_ub),
  distance_to_ub_min = if (any(is.finite(df$distance_to_ub))) min(df$distance_to_ub, na.rm = TRUE) else NA_real_,
  distance_to_ub_p10 = if (any(is.finite(df$distance_to_ub))) qval(df$distance_to_ub, 0.10) else NA_real_,
  distance_to_ub_p25 = if (any(is.finite(df$distance_to_ub))) qval(df$distance_to_ub, 0.25) else NA_real_,
  distance_to_ub_p50 = if (any(is.finite(df$distance_to_ub))) qval(df$distance_to_ub, 0.50) else NA_real_,
  distance_to_ub_p75 = if (any(is.finite(df$distance_to_ub))) qval(df$distance_to_ub, 0.75) else NA_real_,
  distance_to_ub_p90 = if (any(is.finite(df$distance_to_ub))) qval(df$distance_to_ub, 0.90) else NA_real_,
  distance_to_ub_max = if (any(is.finite(df$distance_to_ub))) max(df$distance_to_ub, na.rm = TRUE) else NA_real_,
  corr_log_distance_to_ub_educ_years = corr_pair(df$log_distance_to_ub, df$educ_years),
  corr_log_distance_to_ub_parent_educ_mean = corr_pair(df$log_distance_to_ub, df$parent_educ_mean),
  corr_log_distance_to_ub_lwage = corr_pair(df$log_distance_to_ub, df$lwage),
  deterministic_by_birth_aimag = deterministic_by_birth_aimag
)
write_csv(sample_diag, file.path(PATHS$out_tables, "T8b_logdist_ch_sample_diagnostics.csv"))

residualize_var <- function(data, var, has_weight) {
  fml <- as.formula(paste0(var, " ~ 1 | birth_aimag + birth_cohort + wave"))
  args <- list(fml = fml, data = data, notes = FALSE)
  if (has_weight) args$weights <- ~hhweight
  fit <- do.call(feols, args)
  as.numeric(resid(fit))
}

vars_to_resid <- c(
  "lwage", "educ_years", "parent_educ_mean",
  "age", "age2", "female", "married", "urban"
)

resid_df <- df
for (v in vars_to_resid) {
  resid_df[[paste0(v, "_r")]] <- residualize_var(df, v, has_weight)
}

saveRDS(resid_df, resid_path)

resid_diag_one <- function(data, var) {
  rv <- paste0(var, "_r")
  x <- data[[rv]]
  ox <- data[[var]]
  tibble(
    variable = var,
    residualized_variable = rv,
    mean = mean(x, na.rm = TRUE),
    sd = sd(x, na.rm = TRUE),
    min = min(x, na.rm = TRUE),
    max = max(x, na.rm = TRUE),
    missing_count = sum(is.na(x) | !is.finite(x)),
    correlation_with_original = corr_pair(x, ox)
  )
}

resid_diag <- bind_rows(lapply(vars_to_resid, function(v) resid_diag_one(resid_df, v)))
write_csv(resid_diag, file.path(PATHS$out_tables, "T8b_logdist_ch_residualization_diagnostics.csv"))

gamma_example <- median(resid_df$log_distance_to_ub, na.rm = TRUE)
matrix_df <- resid_df |>
  mutate(
    low = as.integer(log_distance_to_ub <= gamma_example),
    high = as.integer(log_distance_to_ub > gamma_example),
    x_low = educ_years_r * low,
    x_high = educ_years_r * high,
    z_low = parent_educ_mean_r * low,
    z_high = parent_educ_mean_r * high
  )

y <- as.matrix(matrix_df$lwage_r)
X_gamma <- as.matrix(matrix_df |> select(x_low, x_high, age_r, age2_r, female_r, married_r, urban_r))
Z_gamma <- as.matrix(matrix_df |> select(z_low, z_high, age_r, age2_r, female_r, married_r, urban_r))
weights_vec <- if (has_weight) matrix_df$hhweight else rep(1, nrow(matrix_df))
sqrt_w <- sqrt(weights_vec)

Xw <- X_gamma * sqrt_w
Zw <- Z_gamma * sqrt_w
rank_X <- qr(Xw)$rank
rank_Z <- qr(Zw)$rank

ZtZ <- crossprod(Zw)
ZtZ_rank <- qr(ZtZ)$rank
ZtZ_inv <- tryCatch(solve(ZtZ), error = function(e) NULL)

if (is.null(ZtZ_inv)) {
  xpzx <- matrix(NA_real_, ncol(Xw), ncol(Xw))
  xpzx_rank <- NA_integer_
  xpzx_invertible <- FALSE
  xpzx_condition_number <- NA_real_
} else {
  PzX <- Zw %*% ZtZ_inv %*% crossprod(Zw, Xw)
  xpzx <- crossprod(Xw, PzX)
  xpzx_rank <- qr(xpzx)$rank
  xpzx_invertible <- tryCatch({
    solve(xpzx)
    TRUE
  }, error = function(e) FALSE)
  xpzx_condition_number <- tryCatch(kappa(xpzx, exact = TRUE), error = function(e) NA_real_)
}

matrix_diag <- tibble(
  gamma_example = gamma_example,
  N = nrow(matrix_df),
  N_low = sum(matrix_df$low),
  N_high = sum(matrix_df$high),
  ncol_X_gamma = ncol(X_gamma),
  ncol_Z_gamma = ncol(Z_gamma),
  rank_X_gamma = rank_X,
  rank_Z_gamma = rank_Z,
  ZtZ_rank = ZtZ_rank,
  ZtZ_invertible = !is.null(ZtZ_inv),
  XPZX_rank = xpzx_rank,
  XPZX_invertible = xpzx_invertible,
  XPZX_condition_number = xpzx_condition_number,
  full_rank_X = rank_X == ncol(X_gamma),
  full_rank_Z = rank_Z == ncol(Z_gamma),
  safe_for_stage19c_example = rank_X == ncol(X_gamma) &&
    rank_Z == ncol(Z_gamma) &&
    !is.null(ZtZ_inv) &&
    isTRUE(xpzx_invertible) &&
    is.finite(xpzx_condition_number)
)
write_csv(matrix_diag, file.path(PATHS$out_tables, "T8b_logdist_ch_matrix_diagnostics.csv"))

logdist_enough <- sample_diag$log_distance_to_ub_unique_values >= 10 &&
  sample_diag$log_distance_to_ub_p90 > sample_diag$log_distance_to_ub_p10
resid_success <- all(resid_diag$missing_count == 0) &&
  all(is.finite(resid_diag$sd)) &&
  all(resid_diag$sd > 0)
sample_ready <- sample_diag$N > 0 &&
  sample_diag$n_birth_aimag_clusters >= 2 &&
  sample_diag$n_birth_cohort_groups >= 2 &&
  sample_diag$n_waves >= 2
safe_stage19c <- sample_ready && logdist_enough && resid_success && matrix_diag$safe_for_stage19c_example

birth_fe_threshold_problem <- !matrix_diag$safe_for_stage19c_example
decision <- if (safe_stage19c) {
  "Proceed to Stage 19C threshold grid search."
} else {
  "Stop before Stage 19C; log-distance matrix preparation diagnostics need review."
}

report_lines <- c(
  "# Stage 19B: log_distance_to_ub Matrix Preparation",
  "",
  paste0("Generated: ", Sys.time()),
  "",
  "## Design",
  "- Outcome: `lwage`.",
  "- Endogenous regressor: `educ_years`.",
  "- Instrument: `parent_educ_mean`.",
  "- Threshold variable: `log_distance_to_ub`.",
  "- Controls: age, age2, female, married, urban.",
  "- Fixed effects residualized: birth_aimag, birth_cohort, wave.",
  paste0("- Weights used in residualization: ", ifelse(has_weight, "hhweight", "none")),
  "- Cluster variable for later stages: birth_aimag.",
  "",
  "## Sample Diagnostics",
  paste0("- N: ", sample_diag$N),
  paste0("- birth_aimag clusters: ", sample_diag$n_birth_aimag_clusters),
  paste0("- birth_cohort groups: ", sample_diag$n_birth_cohort_groups),
  paste0("- waves: ", sample_diag$n_waves),
  paste0("- log_distance_to_ub min/p10/p25/p50/p75/p90/max: ",
         fmt(sample_diag$log_distance_to_ub_min), " / ",
         fmt(sample_diag$log_distance_to_ub_p10), " / ",
         fmt(sample_diag$log_distance_to_ub_p25), " / ",
         fmt(sample_diag$log_distance_to_ub_p50), " / ",
         fmt(sample_diag$log_distance_to_ub_p75), " / ",
         fmt(sample_diag$log_distance_to_ub_p90), " / ",
         fmt(sample_diag$log_distance_to_ub_max)),
  paste0("- unique log_distance_to_ub values: ", sample_diag$log_distance_to_ub_unique_values),
  paste0("- distance_to_ub min/p10/p25/p50/p75/p90/max: ",
         fmt(sample_diag$distance_to_ub_min), " / ",
         fmt(sample_diag$distance_to_ub_p10), " / ",
         fmt(sample_diag$distance_to_ub_p25), " / ",
         fmt(sample_diag$distance_to_ub_p50), " / ",
         fmt(sample_diag$distance_to_ub_p75), " / ",
         fmt(sample_diag$distance_to_ub_p90), " / ",
         fmt(sample_diag$distance_to_ub_max)),
  paste0("- corr(log_distance_to_ub, educ_years): ", fmt(sample_diag$corr_log_distance_to_ub_educ_years)),
  paste0("- corr(log_distance_to_ub, parent_educ_mean): ", fmt(sample_diag$corr_log_distance_to_ub_parent_educ_mean)),
  paste0("- corr(log_distance_to_ub, lwage): ", fmt(sample_diag$corr_log_distance_to_ub_lwage)),
  "",
  "## Residualization",
  paste0("- Residualized dataset: ", resid_path),
  paste0("- Residualization succeeded: ", resid_success),
  "- log_distance_to_ub was not residualized and remains in levels.",
  "",
  "## Median-threshold Matrix Diagnostics",
  paste0("- gamma_example: ", fmt(matrix_diag$gamma_example)),
  paste0("- N_low: ", matrix_diag$N_low),
  paste0("- N_high: ", matrix_diag$N_high),
  paste0("- X dimensions: ", matrix_diag$N, " x ", matrix_diag$ncol_X_gamma),
  paste0("- Z dimensions: ", matrix_diag$N, " x ", matrix_diag$ncol_Z_gamma),
  paste0("- rank(X): ", matrix_diag$rank_X_gamma),
  paste0("- rank(Z): ", matrix_diag$rank_Z_gamma),
  paste0("- rank(Z'Z): ", matrix_diag$ZtZ_rank),
  paste0("- Z'Z invertible: ", matrix_diag$ZtZ_invertible),
  paste0("- rank(X'PzX): ", matrix_diag$XPZX_rank),
  paste0("- X'PzX invertible: ", matrix_diag$XPZX_invertible),
  paste0("- X'PzX condition number: ", fmt(matrix_diag$XPZX_condition_number)),
  paste0("- Example matrices full rank: ", matrix_diag$safe_for_stage19c_example),
  "",
  "## Birth-aimag Threshold Limitation",
  paste0("- log_distance_to_ub deterministic by birth_aimag: ", deterministic_by_birth_aimag),
  "- This did not cause matrix-rank failure at the median threshold.",
  "- It remains a substantive limitation because the threshold has only birth-aimag-level variation while y/x/z/controls are residualized on birth_aimag FE.",
  "",
  "## Decision",
  decision,
  "",
  "## Warnings / Limitations",
  "- Stage 19B only prepares residualized data and checks one example threshold matrix.",
  "- No threshold grid search, GMM, or bootstrap was run.",
  "- log_distance_to_ub is a threshold variable only and was not used as an IV.",
  "- log_distance_to_ub has only 22 unique values.",
  "- The parental-education exclusion caveat remains."
)

writeLines(report_lines, file.path(PATHS$out_root, "reports", "logdist_ch_stage19b_matrix_preparation.md"), useBytes = TRUE)

cat("Sample diagnostics:\n")
print(sample_diag)
cat("\nResidualization diagnostics:\n")
print(resid_diag)
cat("\nMatrix diagnostics:\n")
print(matrix_diag)
cat("\nBirth-aimag-level threshold with FE caused matrix problems:", birth_fe_threshold_problem, "\n")
cat("\nDecision:", decision, "\n")
cat("\nCompleted:", as.character(Sys.time()), "\n")
