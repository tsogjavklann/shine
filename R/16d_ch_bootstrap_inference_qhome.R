# Stage 16D: Cluster bootstrap inference for q_school_access CH-style IV threshold model.

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

log_path <- file.path(PATHS$out_logs, "16d_ch_bootstrap_inference_qschool_access.log")
sink(log_path, split = TRUE)
on.exit(sink(), add = TRUE)

cat("16d_ch_bootstrap_inference_qschool_access.R\n")
cat("Started:", as.character(Sys.time()), "\n\n")

set.seed(20260426)

data_path <- file.path(PATHS$data_proc, "ch_residualized_qschool_access_parent_mean.rds")
gamma_path <- file.path(PATHS$out_tables, "T5b_ch_gamma_hat.csv")
gmm_path <- file.path(PATHS$out_tables, "T5c_ch_gmm_final_results.csv")
wald_path <- file.path(PATHS$out_tables, "T5c_ch_gmm_wald_test.csv")

if (!file.exists(data_path)) stop("Missing ", data_path)
if (!file.exists(gamma_path)) stop("Missing ", gamma_path)
if (!file.exists(gmm_path)) stop("Missing ", gmm_path)
if (!file.exists(wald_path)) stop("Missing ", wald_path)

df <- readRDS(data_path) |> as_tibble()
gamma_tbl <- read_csv(gamma_path, show_col_types = FALSE)
gmm_tbl <- read_csv(gmm_path, show_col_types = FALSE)
wald_tbl <- read_csv(wald_path, show_col_types = FALSE)

gamma_observed <- as.numeric(gamma_tbl$gamma_hat[1])
beta_low_observed <- gmm_tbl$estimate[gmm_tbl$term == "educ_low"][1]
beta_high_observed <- gmm_tbl$estimate[gmm_tbl$term == "educ_high"][1]
beta_diff_observed <- beta_high_observed - beta_low_observed
asymptotic_p <- as.numeric(wald_tbl$p_value[1])

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
    birth_aimag = as.factor(birth_aimag),
    hhweight = if (has_weight) as.numeric(hhweight) else 1
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

safe_solve <- function(M) {
  tryCatch(solve(M), error = function(e) NULL)
}

make_design <- function(gamma, data) {
  low <- as.integer(data$q_school_access <= gamma)
  high <- as.integer(data$q_school_access > gamma)
  controls <- as.matrix(data |> select(age_r, age2_r, female_r, married_r, urban_r))
  X <- cbind(
    educ_low = data$educ_years_r * low,
    educ_high = data$educ_years_r * high,
    controls
  )
  Z <- cbind(
    iv_low = data$parent_educ_mean_r * low,
    iv_high = data$parent_educ_mean_r * high,
    controls
  )
  clusters <- if ("boot_cluster" %in% names(data)) data$boot_cluster else data$birth_aimag
  list(
    X = X,
    Z = Z,
    y = as.numeric(data$lwage_r),
    weights = if ("hhweight" %in% names(data)) as.numeric(data$hhweight) else rep(1, nrow(data)),
    clusters = as.factor(clusters),
    N_low = sum(low),
    N_high = sum(high)
  )
}

estimate_2sls_at_gamma <- function(data, gamma) {
  dsgn <- make_design(gamma, data)
  X <- dsgn$X
  Z <- dsgn$Z
  y <- dsgn$y
  w <- dsgn$weights
  sqrt_w <- sqrt(w)
  Xw <- X * sqrt_w
  Zw <- Z * sqrt_w
  yw <- y * sqrt_w
  k <- ncol(Xw)
  l <- ncol(Zw)
  rank_X <- qr(Xw)$rank
  rank_Z <- qr(Zw)$rank
  if (dsgn$N_low == 0 || dsgn$N_high == 0 || rank_X < k || rank_Z < l) {
    return(NULL)
  }
  ZtZ_inv <- safe_solve(crossprod(Zw))
  if (is.null(ZtZ_inv)) return(NULL)
  XPZX <- crossprod(Xw, Zw) %*% ZtZ_inv %*% crossprod(Zw, Xw)
  XPZy <- crossprod(Xw, Zw) %*% ZtZ_inv %*% crossprod(Zw, yw)
  rank_XPZX <- qr(XPZX)$rank
  if (rank_XPZX < k) return(NULL)
  beta <- safe_solve(XPZX)
  if (is.null(beta)) return(NULL)
  beta <- as.numeric(beta %*% XPZy)
  u <- as.numeric(y - X %*% beta)
  ssr <- sum(w * u^2, na.rm = TRUE)
  list(
    gamma = gamma,
    beta = beta,
    SSR = ssr,
    N_low = dsgn$N_low,
    N_high = dsgn$N_high,
    rank_X = rank_X,
    rank_Z = rank_Z,
    rank_XPZX = rank_XPZX,
    condition_XPZX = tryCatch(kappa(XPZX, exact = TRUE), error = function(e) NA_real_)
  )
}

gamma_candidates_for <- function(data) {
  q <- data$q_school_access
  q10 <- as.numeric(quantile(q, 0.10, na.rm = TRUE, names = FALSE))
  q90 <- as.numeric(quantile(q, 0.90, na.rm = TRUE, names = FALSE))
  vals <- sort(unique(q[q >= q10 & q <= q90]))
  if (length(vals) <= 300) {
    vals
  } else {
    vals[unique(round(seq(1, length(vals), length.out = 300)))]
  }
}

estimate_2sls_grid <- function(data, gamma_grid = NULL) {
  if (is.null(gamma_grid)) gamma_grid <- gamma_candidates_for(data)
  fits <- lapply(gamma_grid, function(g) estimate_2sls_at_gamma(data, g))
  ok <- !vapply(fits, is.null, logical(1))
  if (!any(ok)) return(NULL)
  tbl <- bind_rows(lapply(fits[ok], function(obj) {
    tibble(
      gamma = obj$gamma,
      beta_low_2sls = obj$beta[1],
      beta_high_2sls = obj$beta[2],
      SSR_2SLS = obj$SSR,
      N_low = obj$N_low,
      N_high = obj$N_high,
      condition_XPZX = obj$condition_XPZX
    )
  }))
  tbl |> arrange(SSR_2SLS) |> slice(1)
}

estimate_gmm_at_gamma <- function(data, gamma) {
  dsgn <- make_design(gamma, data)
  X <- dsgn$X
  Z <- dsgn$Z
  y <- dsgn$y
  w <- dsgn$weights
  clusters <- dsgn$clusters
  n <- length(y)
  k <- ncol(X)
  sqrt_w <- sqrt(w)
  Xw <- X * sqrt_w
  Zw <- Z * sqrt_w
  yw <- y * sqrt_w

  if (dsgn$N_low == 0 || dsgn$N_high == 0 || qr(Xw)$rank < k || qr(Zw)$rank < ncol(Zw)) {
    return(NULL)
  }

  W0 <- safe_solve(crossprod(Zw) / n)
  if (is.null(W0)) return(NULL)

  gmm_est <- function(W) {
    left <- crossprod(Xw, Zw) %*% W %*% crossprod(Zw, Xw)
    right <- crossprod(Xw, Zw) %*% W %*% crossprod(Zw, yw)
    inv <- safe_solve(left)
    if (is.null(inv)) return(NULL)
    as.numeric(inv %*% right)
  }

  beta1 <- gmm_est(W0)
  if (is.null(beta1)) return(NULL)
  u1 <- as.numeric(yw - Xw %*% beta1)
  moment_i <- Zw * u1

  cl <- levels(droplevels(clusters))
  cluster_moments <- matrix(0, nrow = length(cl), ncol = ncol(Zw))
  for (j in seq_along(cl)) {
    idx <- clusters == cl[j]
    cluster_moments[j, ] <- colSums(moment_i[idx, , drop = FALSE])
  }
  S_cluster <- crossprod(cluster_moments) / n
  S_robust <- crossprod(moment_i) / n
  S_cluster_inv <- safe_solve(S_cluster)
  S_robust_inv <- safe_solve(S_robust)
  cond_cluster <- tryCatch(kappa(S_cluster, exact = TRUE), error = function(e) NA_real_)
  warning_note <- character()
  if (!is.null(S_cluster_inv) && is.finite(cond_cluster) && cond_cluster > 1e10) {
    warning_note <- c(warning_note, "S_cluster high condition number > 1e10; used robust S")
    S_cluster_inv <- NULL
  }
  if (!is.null(S_cluster_inv)) {
    W1 <- S_cluster_inv
    S_main <- S_cluster
    weighting <- "cluster"
  } else if (!is.null(S_robust_inv)) {
    W1 <- S_robust_inv
    S_main <- S_robust
    weighting <- "robust"
    warning_note <- c(warning_note, "S_cluster unavailable; used robust S")
  } else {
    return(NULL)
  }

  beta2 <- gmm_est(W1)
  if (is.null(beta2)) return(NULL)
  A <- crossprod(Zw, Xw) / n
  Bmat <- t(A) %*% W1 %*% A
  B_inv <- safe_solve(Bmat)
  if (is.null(B_inv)) return(NULL)
  V <- B_inv %*% t(A) %*% W1 %*% S_main %*% W1 %*% A %*% B_inv / n
  se <- sqrt(pmax(diag(V), 0))
  list(
    beta_low = beta2[1],
    beta_high = beta2[2],
    beta_diff = beta2[2] - beta2[1],
    N_low = dsgn$N_low,
    N_high = dsgn$N_high,
    weighting = weighting,
    se_low = se[1],
    se_high = se[2],
    warning_note = paste(unique(warning_note), collapse = " | ")
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
cat("Observed gamma:", gamma_observed, "\n")
cat("Observed beta diff:", beta_diff_observed, "\n\n")

draws <- vector("list", B)
for (b in seq_len(B)) {
  if (b %% 25 == 0) cat("Bootstrap draw", b, "of", B, "\n")
  boot <- cluster_boot_sample(df)
  warning_note <- character()
  failed <- FALSE
  grid_fit <- tryCatch(estimate_2sls_grid(boot), error = function(e) e)
  if (inherits(grid_fit, "error") || is.null(grid_fit)) {
    failed <- TRUE
    warning_note <- c(warning_note, if (inherits(grid_fit, "error")) conditionMessage(grid_fit) else "grid failed")
    draws[[b]] <- tibble(
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
    )
    next
  }

  gmm_fit <- tryCatch(estimate_gmm_at_gamma(boot, grid_fit$gamma), error = function(e) e)
  if (inherits(gmm_fit, "error") || is.null(gmm_fit)) {
    failed <- TRUE
    warning_note <- c(warning_note, if (inherits(gmm_fit, "error")) conditionMessage(gmm_fit) else "gmm failed")
    draws[[b]] <- tibble(
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
    )
    next
  }

  warning_note <- c(warning_note, gmm_fit$warning_note)
  warning_note <- warning_note[nzchar(warning_note)]
  draws[[b]] <- tibble(
    b = b,
    gamma_boot = grid_fit$gamma,
    beta_low_boot = gmm_fit$beta_low,
    beta_high_boot = gmm_fit$beta_high,
    beta_diff_boot = gmm_fit$beta_diff,
    N_boot = nrow(boot),
    N_low_boot = gmm_fit$N_low,
    N_high_boot = gmm_fit$N_high,
    warning_flag = length(warning_note) > 0,
    failed_flag = failed,
    warning_note = paste(unique(warning_note), collapse = " | ")
  )
}

boot_draws <- bind_rows(draws)
write_csv(boot_draws, file.path(PATHS$out_tables, "T5d_ch_bootstrap_draws.csv"))

success <- boot_draws |> filter(!failed_flag, is.finite(beta_diff_boot), is.finite(gamma_boot))
n_success <- nrow(success)
n_failed <- sum(boot_draws$failed_flag)
if (n_success == 0) stop("No successful bootstrap draws.")

qfun <- function(x, p) as.numeric(quantile(x, p, na.rm = TRUE, names = FALSE))
beta_diff_centered <- success$beta_diff_boot - mean(success$beta_diff_boot, na.rm = TRUE)
p_boot <- mean(abs(beta_diff_centered) >= abs(beta_diff_observed), na.rm = TRUE)

inference <- tibble(
  B_requested = B,
  n_success = n_success,
  n_failed = n_failed,
  n_warning = sum(boot_draws$warning_flag, na.rm = TRUE),
  n_clusters = n_distinct(df$birth_aimag),
  gamma_observed = gamma_observed,
  gamma_q025 = qfun(success$gamma_boot, 0.025),
  gamma_q05 = qfun(success$gamma_boot, 0.05),
  gamma_q50 = qfun(success$gamma_boot, 0.50),
  gamma_q95 = qfun(success$gamma_boot, 0.95),
  gamma_q975 = qfun(success$gamma_boot, 0.975),
  beta_low_observed = beta_low_observed,
  beta_low_q025 = qfun(success$beta_low_boot, 0.025),
  beta_low_q975 = qfun(success$beta_low_boot, 0.975),
  beta_high_observed = beta_high_observed,
  beta_high_q025 = qfun(success$beta_high_boot, 0.025),
  beta_high_q975 = qfun(success$beta_high_boot, 0.975),
  beta_diff_observed = beta_diff_observed,
  beta_diff_q025 = qfun(success$beta_diff_boot, 0.025),
  beta_diff_q975 = qfun(success$beta_diff_boot, 0.975),
  beta_diff_ci_contains_zero = beta_diff_q025 <= 0 & beta_diff_q975 >= 0,
  bootstrap_p_value = p_boot
)
write_csv(inference, file.path(PATHS$out_tables, "T5d_ch_bootstrap_inference.csv"))

comparison <- tibble(
  beta_diff_observed = beta_diff_observed,
  asymptotic_wald_p_value = asymptotic_p,
  bootstrap_p_value = p_boot,
  beta_diff_boot_ci_low = inference$beta_diff_q025,
  beta_diff_boot_ci_high = inference$beta_diff_q975,
  beta_diff_ci_contains_zero = inference$beta_diff_ci_contains_zero,
  conclusion = ifelse(
    p_boot < 0.05 && !inference$beta_diff_ci_contains_zero,
    "Bootstrap supports threshold heterogeneity at 5%.",
    "Bootstrap does not strongly support threshold heterogeneity at 5%."
  )
)
write_csv(comparison, file.path(PATHS$out_tables, "T5d_ch_asymptotic_vs_bootstrap.csv"))

gamma_plot <- ggplot(success, aes(x = gamma_boot)) +
  geom_histogram(bins = 35, fill = "#2f5d62", color = "white") +
  geom_vline(xintercept = gamma_observed, color = "#b33939", linewidth = 0.8) +
  labs(
    x = "Bootstrap gamma",
    y = "Draws",
    title = "Stage 16D bootstrap distribution of gamma"
  ) +
  theme_minimal(base_size = 11)

ggsave(
  filename = file.path(PATHS$out_figures, "full_ch_stage16d_gamma_bootstrap_distribution.png"),
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
    title = "Stage 16D bootstrap distribution of regime difference"
  ) +
  theme_minimal(base_size = 11)

ggsave(
  filename = file.path(PATHS$out_figures, "full_ch_stage16d_beta_diff_bootstrap_distribution.png"),
  plot = diff_plot,
  width = 7,
  height = 4.5,
  dpi = 300
)

heterogeneity_supported <- p_boot < 0.05 && !inference$beta_diff_ci_contains_zero
interpretation <- if (heterogeneity_supported) {
  "Bootstrap inference supports education returns differing across q_school_access regimes at the 5% level."
} else {
  "Bootstrap inference does not strongly support threshold heterogeneity in education returns across q_school_access regimes at the 5% level."
}

fmt <- function(x, digits = 4) ifelse(is.na(x), "NA", formatC(x, format = "f", digits = digits))

report_lines <- c(
  "# Stage 16D: Bootstrap Inference for q_school_access CH-style IV Threshold Model",
  "",
  paste0("Generated: ", Sys.time()),
  "",
  "## 1. Bootstrap Method",
  "- Cluster bootstrap by `birth_aimag`.",
  "- Each draw resamples birth_aimag clusters with replacement and stacks all observations from selected clusters.",
  "- The 2SLS threshold grid search is recomputed within each bootstrap draw.",
  "- GMM slopes are estimated at each draw-specific threshold.",
  "- Seed: 20260426.",
  "",
  "## 2. Clusters and Replications",
  paste0("- Number of clusters: ", n_distinct(df$birth_aimag)),
  paste0("- Requested bootstrap replications: ", B),
  paste0("- Successful draws: ", n_success),
  paste0("- Failed draws: ", n_failed),
  paste0("- Warning-flagged draws: ", inference$n_warning),
  "",
  "## 3. Observed gamma_hat and Bootstrap CI",
  paste0("- Observed gamma_hat: ", fmt(gamma_observed)),
  paste0("- gamma 2.5% / 5% / 50% / 95% / 97.5%: ",
         fmt(inference$gamma_q025), " / ",
         fmt(inference$gamma_q05), " / ",
         fmt(inference$gamma_q50), " / ",
         fmt(inference$gamma_q95), " / ",
         fmt(inference$gamma_q975)),
  "",
  "## 4. Observed Regime Slopes and Bootstrap CIs",
  paste0("- beta_low observed: ", fmt(beta_low_observed), "; percentile CI: [", fmt(inference$beta_low_q025), ", ", fmt(inference$beta_low_q975), "]"),
  paste0("- beta_high observed: ", fmt(beta_high_observed), "; percentile CI: [", fmt(inference$beta_high_q025), ", ", fmt(inference$beta_high_q975), "]"),
  paste0("- beta_diff observed: ", fmt(beta_diff_observed), "; percentile CI: [", fmt(inference$beta_diff_q025), ", ", fmt(inference$beta_diff_q975), "]"),
  "",
  "## 5. Bootstrap Threshold-Effect p-value",
  paste0("- bootstrap p-value: ", fmt(p_boot)),
  paste0("- beta_diff CI contains zero: ", inference$beta_diff_ci_contains_zero),
  "",
  "## 6. Asymptotic vs Bootstrap",
  paste0("- Stage 16C asymptotic/Wald p-value: ", fmt(asymptotic_p)),
  paste0("- Stage 16D bootstrap p-value: ", fmt(p_boot)),
  "",
  "## 7. Inference Conclusion",
  interpretation,
  "Do not interpret q_school_access as causing wage returns.",
  "",
  "## 8. Caveats",
  "- Only 22 clusters are available, so cluster bootstrap inference may be noisy.",
  "- Matrix condition numbers are high in prior stages.",
  "- Parental education may affect wages through family background, networks, and unobserved ability channels.",
  "- q_school_access threshold exogeneity remains an identifying assumption.",
  "- FE residualization is an approximation to the high-dimensional fixed-effects threshold model."
)

writeLines(report_lines, file.path(PATHS$out_root, "reports", "ch_stage16d_bootstrap_inference.md"), useBytes = TRUE)

cat("Bootstrap inference:\n")
print(inference)
cat("\nAsymptotic vs bootstrap:\n")
print(comparison)
cat("\nConclusion:", interpretation, "\n")
cat("\nCompleted:", as.character(Sys.time()), "\n")
