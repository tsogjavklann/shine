# Prepare parent_educ_mean IV-ready sample with log_distance_to_ub as threshold.
# This script does not run IVTR and does not use log_distance_to_ub as an IV.

options(warn = 1, encoding = "UTF-8")

source(here::here("R", "paths.R"))
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
})

dir.create(PATHS$out_tables, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(PATHS$out_root, "reports"), recursive = TRUE, showWarnings = FALSE)
dir.create(PATHS$out_logs, recursive = TRUE, showWarnings = FALSE)

log_path <- file.path(PATHS$out_logs, "19a_prepare_logdist_threshold_sample.log")
sink(log_path, split = TRUE)
on.exit(sink(), add = TRUE)

cat("19a_prepare_logdist_threshold_sample.R\n")
cat("Started:", as.character(Sys.time()), "\n\n")

iv_ready_path <- file.path(PATHS$data_proc, "ivtr_ready_parent_educ_mean_qschool_access.rds")
distance_path <- file.path(PATHS$data_aux, "aimag_distance_to_ub.csv")
out_path <- file.path(PATHS$data_proc, "ivtr_ready_parent_educ_mean_logdist.rds")

if (!file.exists(iv_ready_path)) stop("Missing ", iv_ready_path)
if (!file.exists(distance_path)) stop("Missing ", distance_path)

dat <- readRDS(iv_ready_path) |> as_tibble()
logdist_existed <- "log_distance_to_ub" %in% names(dat)
distance_existed <- "distance_to_ub" %in% names(dat)
if (!distance_existed) dat$distance_to_ub <- NA_real_
if (!logdist_existed) dat$log_distance_to_ub <- NA_real_
source_note <- if (logdist_existed) {
  "log_distance_to_ub existed in IV-ready sample"
} else {
  "log_distance_to_ub reconstructed from data/auxiliary/aimag_distance_to_ub.csv using birth_aimag"
}

if (!logdist_existed || !distance_existed) {
  dist <- read_csv(distance_path, show_col_types = FALSE) |>
    transmute(
      birth_aimag = as.numeric(aimag),
      distance_to_ub_join = as.numeric(distance_to_ub),
      log_distance_to_ub_join = log(pmax(as.numeric(distance_to_ub), 1))
    )
  dat <- dat |>
    mutate(birth_aimag_num = as.numeric(as.character(birth_aimag))) |>
    left_join(dist, by = c("birth_aimag_num" = "birth_aimag")) |>
    mutate(
      distance_to_ub = coalesce(as.numeric(distance_to_ub), distance_to_ub_join),
      log_distance_to_ub = coalesce(as.numeric(log_distance_to_ub), log_distance_to_ub_join)
    ) |>
    select(-birth_aimag_num, -distance_to_ub_join, -log_distance_to_ub_join)
}

required <- c(
  "lwage", "educ_years", "parent_educ_mean", "log_distance_to_ub",
  "age", "age2", "female", "married", "urban",
  "birth_aimag", "birth_cohort", "wave"
)
missing_required <- setdiff(required, names(dat))
if (length(missing_required) > 0) {
  stop("Missing required variable(s): ", paste(missing_required, collapse = ", "))
}

has_weight <- "hhweight" %in% names(dat)

sample <- dat |>
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
  sample <- sample |> filter(!is.na(hhweight), is.finite(hhweight), hhweight > 0)
}

if (nrow(sample) == 0) stop("No observations remain after log-distance threshold sample cleaning.")

qstats <- function(x, prefix) {
  x <- as.numeric(x)
  tibble(
    "{prefix}_min" := min(x, na.rm = TRUE),
    "{prefix}_p10" := as.numeric(quantile(x, 0.10, na.rm = TRUE, names = FALSE)),
    "{prefix}_p25" := as.numeric(quantile(x, 0.25, na.rm = TRUE, names = FALSE)),
    "{prefix}_p50" := as.numeric(quantile(x, 0.50, na.rm = TRUE, names = FALSE)),
    "{prefix}_p75" := as.numeric(quantile(x, 0.75, na.rm = TRUE, names = FALSE)),
    "{prefix}_p90" := as.numeric(quantile(x, 0.90, na.rm = TRUE, names = FALSE)),
    "{prefix}_max" := max(x, na.rm = TRUE)
  )
}

corr_pair <- function(x, y) suppressWarnings(cor(x, y, use = "pairwise.complete.obs"))

logdist_stats <- qstats(sample$log_distance_to_ub, "log_distance_to_ub")
dist_stats <- if ("distance_to_ub" %in% names(sample) && any(is.finite(sample$distance_to_ub))) {
  qstats(sample$distance_to_ub, "distance_to_ub")
} else {
  tibble(
    distance_to_ub_min = NA_real_, distance_to_ub_p10 = NA_real_,
    distance_to_ub_p25 = NA_real_, distance_to_ub_p50 = NA_real_,
    distance_to_ub_p75 = NA_real_, distance_to_ub_p90 = NA_real_,
    distance_to_ub_max = NA_real_
  )
}

by_aimag <- sample |>
  group_by(birth_aimag) |>
  summarise(
    N = n(),
    distance_to_ub = if (all(is.na(distance_to_ub))) NA_real_ else unique(distance_to_ub[is.finite(distance_to_ub)])[1],
    log_distance_to_ub = unique(log_distance_to_ub[is.finite(log_distance_to_ub)])[1],
    n_unique_log_distance_to_ub = n_distinct(log_distance_to_ub),
    mean_lwage = mean(lwage, na.rm = TRUE),
    mean_educ_years = mean(educ_years, na.rm = TRUE),
    mean_parent_educ_mean = mean(parent_educ_mean, na.rm = TRUE),
    .groups = "drop"
  ) |>
  arrange(log_distance_to_ub, birth_aimag)

deterministic_by_birth_aimag <- all(by_aimag$n_unique_log_distance_to_ub == 1)

diagnostics <- bind_cols(
  tibble(
    N = nrow(sample),
    n_birth_aimag_clusters = n_distinct(sample$birth_aimag),
    n_birth_cohort_groups = n_distinct(sample$birth_cohort),
    n_waves = n_distinct(sample$wave),
    log_distance_to_ub_unique_values = n_distinct(sample$log_distance_to_ub),
    distance_to_ub_unique_values = if ("distance_to_ub" %in% names(sample)) n_distinct(sample$distance_to_ub) else NA_integer_,
    corr_log_distance_to_ub_educ_years = corr_pair(sample$log_distance_to_ub, sample$educ_years),
    corr_log_distance_to_ub_parent_educ_mean = corr_pair(sample$log_distance_to_ub, sample$parent_educ_mean),
    corr_log_distance_to_ub_lwage = corr_pair(sample$log_distance_to_ub, sample$lwage),
    deterministic_by_birth_aimag = deterministic_by_birth_aimag,
    log_distance_to_ub_role = "threshold variable only; not used as IV",
    source_note = source_note
  ),
  logdist_stats,
  dist_stats
)

saveRDS(sample, out_path)
write_csv(diagnostics, file.path(PATHS$out_tables, "T8a_logdist_threshold_sample_diagnostics.csv"))
write_csv(by_aimag, file.path(PATHS$out_tables, "T8a_logdist_by_birth_aimag.csv"))

safe_stage19b <- diagnostics$N > 0 &&
  diagnostics$n_birth_aimag_clusters >= 2 &&
  diagnostics$log_distance_to_ub_unique_values >= 10 &&
  deterministic_by_birth_aimag

decision <- if (safe_stage19b) {
  "Safe to proceed to Stage 19B log_distance_to_ub threshold preparation/estimation."
} else {
  "Do not proceed to Stage 19B until log_distance_to_ub diagnostics are reviewed."
}

fmt <- function(x, digits = 4) ifelse(is.na(x), "NA", formatC(x, format = "f", digits = digits))

report_lines <- c(
  "# log_distance_to_ub Threshold Sample Preparation",
  "",
  paste0("Generated: ", Sys.time()),
  "",
  "## Design Going Forward",
  "- Outcome: `lwage`.",
  "- Endogenous regressor: `educ_years`.",
  "- IV: `parent_educ_mean`.",
  "- Threshold variable: `log_distance_to_ub`.",
  "- Controls: age, age2, female, married, urban.",
  "- Fixed effects: birth_aimag, birth_cohort, wave.",
  paste0("- Weights: ", ifelse(has_weight, "hhweight", "none")),
  "- Cluster: birth_aimag.",
  "",
  "## Source",
  paste0("- ", source_note),
  "- `log_distance_to_ub` is a threshold variable only; it is not used as an IV.",
  "",
  "## Sample Diagnostics",
  paste0("- N: ", diagnostics$N),
  paste0("- birth_aimag clusters: ", diagnostics$n_birth_aimag_clusters),
  paste0("- birth_cohort groups: ", diagnostics$n_birth_cohort_groups),
  paste0("- waves: ", diagnostics$n_waves),
  paste0("- log_distance_to_ub min/p10/p25/p50/p75/p90/max: ",
         fmt(diagnostics$log_distance_to_ub_min), " / ",
         fmt(diagnostics$log_distance_to_ub_p10), " / ",
         fmt(diagnostics$log_distance_to_ub_p25), " / ",
         fmt(diagnostics$log_distance_to_ub_p50), " / ",
         fmt(diagnostics$log_distance_to_ub_p75), " / ",
         fmt(diagnostics$log_distance_to_ub_p90), " / ",
         fmt(diagnostics$log_distance_to_ub_max)),
  paste0("- unique log_distance_to_ub values: ", diagnostics$log_distance_to_ub_unique_values),
  paste0("- distance_to_ub min/p10/p25/p50/p75/p90/max: ",
         fmt(diagnostics$distance_to_ub_min), " / ",
         fmt(diagnostics$distance_to_ub_p10), " / ",
         fmt(diagnostics$distance_to_ub_p25), " / ",
         fmt(diagnostics$distance_to_ub_p50), " / ",
         fmt(diagnostics$distance_to_ub_p75), " / ",
         fmt(diagnostics$distance_to_ub_p90), " / ",
         fmt(diagnostics$distance_to_ub_max)),
  "",
  "## Correlations",
  paste0("- corr(log_distance_to_ub, educ_years): ", fmt(diagnostics$corr_log_distance_to_ub_educ_years)),
  paste0("- corr(log_distance_to_ub, parent_educ_mean): ", fmt(diagnostics$corr_log_distance_to_ub_parent_educ_mean)),
  paste0("- corr(log_distance_to_ub, lwage): ", fmt(diagnostics$corr_log_distance_to_ub_lwage)),
  "",
  "## Birth-aimag Diagnostics",
  paste0("- deterministic by birth_aimag: ", deterministic_by_birth_aimag),
  "- Aimag-level threshold means there are limited unique values; this is a limitation, not an error.",
  "",
  "## Decision",
  decision,
  "",
  "## Warnings / Limitations",
  "- `log_distance_to_ub` has birth-aimag-level variation only.",
  "- It has limited unique values relative to individual-level q_school_access.",
  "- It may capture broad regional/remoteness differences rather than a narrow school-access channel.",
  "- It must not be used as an instrument in this design."
)

writeLines(report_lines, file.path(PATHS$out_root, "reports", "logdist_threshold_sample_preparation.md"), useBytes = TRUE)

cat("Diagnostics:\n")
print(diagnostics)
cat("\nBirth aimag table:\n")
print(by_aimag, n = Inf)
cat("\nDecision:", decision, "\n")
cat("\nSaved:", out_path, "\n")
cat("\nCompleted:", as.character(Sys.time()), "\n")


