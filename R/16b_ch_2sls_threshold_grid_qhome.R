# Stage 16B: Caner-Hansen-style residualized 2SLS threshold grid for gamma_hat.

options(warn = 1, encoding = "UTF-8")

source(here::here("R", "paths.R"))
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
  library(ggplot2)
})

dir.create(PATHS$out_tables, recursive = TRUE, showWarnings = FALSE)
dir.create(PATHS$out_figures, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(PATHS$out_root, "reports"), recursive = TRUE, showWarnings = FALSE)
dir.create(PATHS$out_logs, recursive = TRUE, showWarnings = FALSE)

log_path <- file.path(PATHS$out_logs, "16b_ch_2sls_threshold_grid_qschool_access.log")
sink(log_path, split = TRUE)
on.exit(sink(), add = TRUE)

cat("16b_ch_2sls_threshold_grid_qschool_access.R\n")
cat("Started:", as.character(Sys.time()), "\n\n")

input_path <- file.path(PATHS$data_proc, "ch_residualized_qschool_access_parent_mean.rds")
if (!file.exists(input_path)) stop("Missing ", input_path, ". Run Stage 16A first.")

df <- readRDS(input_path) |> as_tibble()
has_weight <- "hhweight" %in% names(df)

required <- c(
  "lwage_r", "educ_years_r", "parent_educ_mean_r", "q_school_access",
  "age_r", "age2_r", "female_r", "married_r", "urban_r",
  "birth_aimag"
)
missing_required <- setdiff(required, names(df))
if (length(missing_required) > 0) {
  stop("Missing required variable(s): ", paste(missing_required, collapse = ", "))
}

df <- df |>
  mutate(
    lwage_r = as.numeric(lwage_r),
    educ_years_r = as.numeric(educ_years_r),
    parent_educ_mean_r = as.numeric(parent_educ_mean_r),
    q_school_access = as.numeric(q_school_access),
    age_r = as.numeric(age_r),
    age2_r = as.numeric(age2_r),
    female_r = as.numeric(female_r),
    married_r = as.numeric(married_r),
    urban_r = as.numeric(urban_r),
    hhweight = if (has_weight) as.numeric(hhweight) else 1,
    birth_aimag = as.factor(birth_aimag)
  ) |>
  filter(
    is.finite(lwage_r),
    is.finite(educ_years_r),
    is.finite(parent_educ_mean_r),
    is.finite(q_school_access),
    is.finite(age_r),
    is.finite(age2_r),
    is.finite(female_r),
    is.finite(married_r),
    is.finite(urban_r),
    !is.na(birth_aimag)
  )

if (has_weight) {
  df <- df |> filter(is.finite(hhweight), hhweight > 0)
}

if (nrow(df) == 0) stop("No observations remain after loading residualized data.")

y <- as.numeric(df$lwage_r)
x <- as.numeric(df$educ_years_r)
z <- as.numeric(df$parent_educ_mean_r)
controls <- as.matrix(df |> select(age_r, age2_r, female_r, married_r, urban_r))
q <- as.numeric(df$q_school_access)
w <- if (has_weight) as.numeric(df$hhweight) else rep(1, nrow(df))
sqrt_w <- sqrt(w)

q10 <- as.numeric(quantile(q, 0.10, na.rm = TRUE, names = FALSE))
q90 <- as.numeric(quantile(q, 0.90, na.rm = TRUE, names = FALSE))
unique_trimmed <- sort(unique(q[q >= q10 & q <= q90]))
if (length(unique_trimmed) <= 300) {
  candidates <- unique_trimmed
} else {
  idx <- unique(round(seq(1, length(unique_trimmed), length.out = 300)))
  candidates <- unique_trimmed[idx]
}

cat("Candidate thresholds:", length(candidates), "\n")
cat("q_school_access p10:", q10, " p90:", q90, "\n\n")

weighted_2sls_gamma <- function(gamma) {
  low <- as.integer(q <= gamma)
  high <- as.integer(q > gamma)
  N_low <- sum(low)
  N_high <- sum(high)

  X <- cbind(
    educ_low = x * low,
    educ_high = x * high,
    controls
  )
  Z <- cbind(
    iv_low = z * low,
    iv_high = z * high,
    controls
  )

  Xw <- X * sqrt_w
  Zw <- Z * sqrt_w
  yw <- y * sqrt_w

  rank_X <- qr(Xw)$rank
  rank_Z <- qr(Zw)$rank
  warning_notes <- character()

  if (N_low == 0 || N_high == 0) {
    warning_notes <- c(warning_notes, "empty regime")
  }
  if (rank_X < ncol(Xw)) {
    warning_notes <- c(warning_notes, "rank_X deficient")
  }
  if (rank_Z < ncol(Zw)) {
    warning_notes <- c(warning_notes, "rank_Z deficient")
  }

  ZtZ_inv <- tryCatch(solve(crossprod(Zw)), error = function(e) e)
  if (inherits(ZtZ_inv, "error")) {
    return(tibble(
      gamma = gamma,
      N = length(y),
      N_low = N_low,
      N_high = N_high,
      beta_low_2sls = NA_real_,
      beta_high_2sls = NA_real_,
      SSR_2SLS = Inf,
      rank_X = rank_X,
      rank_Z = rank_Z,
      rank_XPZX = NA_integer_,
      condition_number_XPZX = NA_real_,
      warning_flag = TRUE,
      warning_note = paste(c(warning_notes, "Z'Z singular"), collapse = " | ")
    ))
  }

  PzX <- Zw %*% ZtZ_inv %*% crossprod(Zw, Xw)
  Pzy <- Zw %*% ZtZ_inv %*% crossprod(Zw, yw)
  XPZX <- crossprod(Xw, PzX)
  XPZy <- crossprod(Xw, Pzy)
  rank_XPZX <- qr(XPZX)$rank
  condition_number <- tryCatch(kappa(XPZX, exact = TRUE), error = function(e) NA_real_)

  if (rank_XPZX < ncol(XPZX)) {
    warning_notes <- c(warning_notes, "rank_XPZX deficient")
  }

  beta <- tryCatch(solve(XPZX, XPZy), error = function(e) e)
  if (inherits(beta, "error")) {
    return(tibble(
      gamma = gamma,
      N = length(y),
      N_low = N_low,
      N_high = N_high,
      beta_low_2sls = NA_real_,
      beta_high_2sls = NA_real_,
      SSR_2SLS = Inf,
      rank_X = rank_X,
      rank_Z = rank_Z,
      rank_XPZX = rank_XPZX,
      condition_number_XPZX = condition_number,
      warning_flag = TRUE,
      warning_note = paste(c(warning_notes, "X'PzX singular"), collapse = " | ")
    ))
  }

  beta <- as.numeric(beta)
  u <- as.numeric(y - X %*% beta)
  ssr <- sum(w * u^2, na.rm = TRUE)
  if (is.finite(condition_number) && condition_number > 1e8) {
    warning_notes <- c(warning_notes, "high condition number > 1e8")
  }

  tibble(
    gamma = gamma,
    N = length(y),
    N_low = N_low,
    N_high = N_high,
    beta_low_2sls = beta[1],
    beta_high_2sls = beta[2],
    SSR_2SLS = ssr,
    rank_X = rank_X,
    rank_Z = rank_Z,
    rank_XPZX = rank_XPZX,
    condition_number_XPZX = condition_number,
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
    rank_X == 7,
    rank_Z == 7,
    rank_XPZX == 7
  )

if (nrow(valid_grid) == 0) stop("No valid grid points found.")

gamma_row <- valid_grid |>
  arrange(SSR_2SLS) |>
  slice(1)

gamma_hat <- gamma_row$gamma

grid <- grid |>
  mutate(is_gamma_hat = isTRUE(abs(gamma - gamma_hat) < .Machine$double.eps^0.5))

write_csv(grid, file.path(PATHS$out_tables, "T5b_ch_threshold_grid.csv"))

warning_summary <- grid |>
  filter(warning_flag) |>
  count(warning_note, name = "n")

gamma_hat_table <- gamma_row |>
  mutate(
    n_candidates = length(candidates),
    n_valid_grid_points = nrow(valid_grid),
    n_skipped_or_invalid = length(candidates) - nrow(valid_grid),
    min_SSR_2SLS = SSR_2SLS,
    safe_for_stage16c = nrow(valid_grid) > 0 &&
      is.finite(SSR_2SLS) &&
      is.finite(condition_number_XPZX) &&
      condition_number_XPZX < 1e8
  ) |>
  select(
    gamma_hat = gamma,
    N, N_low, N_high,
    beta_low_2sls, beta_high_2sls,
    min_SSR_2SLS,
    rank_X, rank_Z, rank_XPZX,
    condition_number_XPZX,
    warning_flag, warning_note,
    n_candidates, n_valid_grid_points, n_skipped_or_invalid,
    safe_for_stage16c
  )

write_csv(gamma_hat_table, file.path(PATHS$out_tables, "T5b_ch_gamma_hat.csv"))

objective_plot <- valid_grid |>
  ggplot(aes(x = gamma, y = SSR_2SLS)) +
  geom_line(color = "#2f5d62", linewidth = 0.7) +
  geom_vline(xintercept = gamma_hat, color = "#b33939", linewidth = 0.7) +
  labs(
    x = "q_school_access threshold candidate",
    y = "Weighted 2SLS SSR",
    title = "Stage 16B q_school_access 2SLS threshold objective"
  ) +
  theme_minimal(base_size = 11)

ggsave(
  filename = file.path(PATHS$out_figures, "full_ch_stage16b_qschool_access_2sls_objective_grid.png"),
  plot = objective_plot,
  width = 7,
  height = 4.5,
  dpi = 300
)

safe_stage16c <- gamma_hat_table$safe_for_stage16c
decision <- if (safe_stage16c) {
  "Proceed to Stage 16C GMM slope estimation."
} else {
  "Stop before Stage 16C; numerical diagnostics require review."
}

fmt <- function(x, digits = 4) ifelse(is.na(x), "NA", formatC(x, format = "f", digits = digits))

report_lines <- c(
  "# Stage 16B: Caner-Hansen-style 2SLS Threshold Grid",
  "",
  paste0("Generated: ", Sys.time()),
  "",
  "## Design",
  "- Outcome: `lwage_r`.",
  "- Endogenous regressor: `educ_years_r`.",
  "- Instrument: `parent_educ_mean_r`.",
  "- Threshold variable: `q_school_access` in levels.",
  "- Controls: `age_r`, `age2_r`, `female_r`, `married_r`, `urban_r`.",
  paste0("- Weights: ", ifelse(has_weight, "hhweight", "none")),
  "",
  "## Accepted IV Diagnostics",
  "- `parent_educ_mean` is constructed from `father_educ_years` and `mother_educ_years` only.",
  "- No `educ_years` leakage.",
  "- IVTR-ready first-stage clustered Wald F = 558.45.",
  "- Weak-IV flag = FALSE.",
  "",
  "## Grid Diagnostics",
  paste0("- Candidate thresholds: ", length(candidates)),
  paste0("- Valid grid points: ", nrow(valid_grid)),
  paste0("- Skipped/invalid grid points: ", length(candidates) - nrow(valid_grid)),
  paste0("- Warning-flagged grid points: ", sum(grid$warning_flag)),
  "",
  "## gamma_hat",
  paste0("- gamma_hat: ", fmt(gamma_hat)),
  paste0("- N_low: ", gamma_hat_table$N_low),
  paste0("- N_high: ", gamma_hat_table$N_high),
  paste0("- beta_low_2SLS: ", fmt(gamma_hat_table$beta_low_2sls)),
  paste0("- beta_high_2SLS: ", fmt(gamma_hat_table$beta_high_2sls)),
  paste0("- Minimum SSR: ", fmt(gamma_hat_table$min_SSR_2SLS)),
  paste0("- rank_X: ", gamma_hat_table$rank_X),
  paste0("- rank_Z: ", gamma_hat_table$rank_Z),
  paste0("- rank_XPZX: ", gamma_hat_table$rank_XPZX),
  paste0("- condition_number_XPZX: ", fmt(gamma_hat_table$condition_number_XPZX)),
  "",
  "## Numerical Warnings",
  if (nrow(warning_summary) == 0) {
    "- No warning-flagged grid points."
  } else {
    paste0("- ", warning_summary$warning_note, ": ", warning_summary$n)
  },
  "",
  "## Decision",
  decision,
  "",
  "## Limitations",
  "- Stage 16B estimates gamma_hat by residualized 2SLS grid search only.",
  "- No final GMM slope estimation was run.",
  "- No bootstrap was run.",
  "- Stage 16C should keep monitoring condition numbers and rank failures."
)

writeLines(report_lines, file.path(PATHS$out_root, "reports", "ch_stage16b_2sls_threshold_grid.md"), useBytes = TRUE)

cat("Grid diagnostics:\n")
cat("Candidates:", length(candidates), "\n")
cat("Valid:", nrow(valid_grid), "\n")
cat("Skipped/invalid:", length(candidates) - nrow(valid_grid), "\n")
cat("Warning-flagged:", sum(grid$warning_flag), "\n\n")
cat("Gamma hat table:\n")
print(gamma_hat_table)
cat("\nWarning summary:\n")
print(warning_summary)
cat("\nDecision:", decision, "\n")
cat("\nCompleted:", as.character(Sys.time()), "\n")
