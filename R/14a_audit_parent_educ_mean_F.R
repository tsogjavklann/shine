# Audit whether the parent_educ_mean first-stage F is genuine or an extraction artifact.

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

log_path <- file.path(PATHS$out_logs, "14a_audit_parent_educ_mean_F.log")
sink(log_path, split = TRUE)
on.exit(sink(), add = TRUE)

cat("14a_audit_parent_educ_mean_F.R\n")
cat("Started:", as.character(Sys.time()), "\n\n")

analysis_path <- file.path(PATHS$data_proc, "analysis_sample.rds")
family_path <- file.path(PATHS$data_proc, "family_structure.rds")
ivtr_path <- file.path(PATHS$data_proc, "ivtr_ready_parent_educ_mean_qschool_access.rds")

if (!file.exists(analysis_path)) stop("Missing ", analysis_path)
if (!file.exists(family_path)) stop("Missing ", family_path)
if (!file.exists(ivtr_path)) stop("Missing ", ivtr_path)

analysis <- readRDS(analysis_path) |> as_tibble()
family <- readRDS(family_path) |>
  as_tibble() |>
  select(id, father_educ_years, mother_educ_years) |>
  distinct(id, .keep_all = TRUE)
ivtr_ready <- readRDS(ivtr_path) |> as_tibble()

joined <- analysis |>
  left_join(family, by = "id")

if (!"female" %in% names(joined)) joined$female <- as.numeric(joined$is_female)
if (!"married" %in% names(joined)) joined$married <- as.numeric(joined$is_married)
if (!"birth_cohort" %in% names(joined)) {
  joined <- joined |>
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

joined <- joined |>
  mutate(
    parent_educ_mean_from_parents = rowMeans(
      cbind(as.numeric(father_educ_years), as.numeric(mother_educ_years)),
      na.rm = TRUE
    ),
    parent_educ_mean_from_parents = if_else(
      is.nan(parent_educ_mean_from_parents),
      NA_real_,
      parent_educ_mean_from_parents
    ),
    female = as.numeric(female),
    married = as.numeric(married),
    birth_cohort = as.character(birth_cohort)
  )

audit_sample <- joined |>
  filter(
    age >= 25, age <= 60,
    is.finite(lwage),
    !is.na(educ_years), is.finite(educ_years),
    !is.na(parent_educ_mean_from_parents), is.finite(parent_educ_mean_from_parents),
    !is.na(q_school_access), is.finite(q_school_access),
    !is.na(age), !is.na(age2),
    !is.na(female), !is.na(married), !is.na(urban),
    !is.na(birth_aimag),
    !is.na(birth_cohort),
    !is.na(wave),
    !is.na(hhweight), is.finite(hhweight), hhweight > 0
  ) |>
  mutate(
    parent_educ_mean = parent_educ_mean_from_parents,
    birth_aimag = as.factor(birth_aimag),
    birth_cohort = as.factor(birth_cohort),
    wave = as.factor(wave)
  )

if (nrow(audit_sample) == 0) stop("Audit sample is empty.")

ivtr_check <- ivtr_ready |>
  mutate(row_id = row_number()) |>
  select(row_id, lwage, educ_years, parent_educ_mean, q_school_access, age, age2, female, married, urban, birth_aimag, birth_cohort, wave, hhweight)

audit_ready_compare <- audit_sample |>
  select(lwage, educ_years, parent_educ_mean, q_school_access, age, age2, female, married, urban, birth_aimag, birth_cohort, wave, hhweight)

same_n_as_ivtr <- nrow(audit_ready_compare) == nrow(ivtr_check)
same_parent_values <- if (same_n_as_ivtr) {
  isTRUE(all.equal(
    as.numeric(audit_ready_compare$parent_educ_mean),
    as.numeric(ivtr_check$parent_educ_mean),
    tolerance = 1e-12,
    check.attributes = FALSE
  ))
} else {
  FALSE
}

parent_uses_educ_years_flag <- FALSE
parent_trace <- tibble(
  constructed_variable = "parent_educ_mean",
  source_variable_1 = "father_educ_years",
  source_variable_2 = "mother_educ_years",
  formula = "rowMeans(cbind(father_educ_years, mother_educ_years), na.rm = TRUE); NaN -> NA",
  uses_educ_years = parent_uses_educ_years_flag,
  source_file = family_path,
  compared_to_ivtr_ready = same_parent_values
)

corr_pair <- function(x, y) suppressWarnings(cor(x, y, use = "pairwise.complete.obs"))
correlations <- tibble(
  metric = c(
    "corr(educ_years, parent_educ_mean)",
    "corr(educ_years, mother_educ_years)",
    "corr(educ_years, father_educ_years)",
    "corr(mother_educ_years, father_educ_years)"
  ),
  value = c(
    corr_pair(audit_sample$educ_years, audit_sample$parent_educ_mean),
    corr_pair(audit_sample$educ_years, audit_sample$mother_educ_years),
    corr_pair(audit_sample$educ_years, audit_sample$father_educ_years),
    corr_pair(audit_sample$mother_educ_years, audit_sample$father_educ_years)
  )
)

summarise_var <- function(data, var) {
  x <- as.numeric(data[[var]])
  tibble(
    variable = var,
    n_nonmissing = sum(!is.na(x) & is.finite(x)),
    min = min(x, na.rm = TRUE),
    p10 = as.numeric(quantile(x, 0.10, na.rm = TRUE, names = FALSE)),
    p25 = as.numeric(quantile(x, 0.25, na.rm = TRUE, names = FALSE)),
    p50 = as.numeric(quantile(x, 0.50, na.rm = TRUE, names = FALSE)),
    p75 = as.numeric(quantile(x, 0.75, na.rm = TRUE, names = FALSE)),
    p90 = as.numeric(quantile(x, 0.90, na.rm = TRUE, names = FALSE)),
    max = max(x, na.rm = TRUE)
  )
}

summary_diagnostics <- bind_rows(
  summarise_var(audit_sample, "educ_years"),
  summarise_var(audit_sample, "parent_educ_mean"),
  summarise_var(audit_sample, "mother_educ_years"),
  summarise_var(audit_sample, "father_educ_years")
)

fs_fml <- educ_years ~ parent_educ_mean + age + age2 + female + married + urban |
  birth_aimag + birth_cohort + wave
iv_fml <- lwage ~ age + age2 + female + married + urban |
  birth_aimag + birth_cohort + wave |
  educ_years ~ parent_educ_mean

extract_parent <- function(fit) {
  ct <- coeftable(fit)
  out <- ct["parent_educ_mean", ]
  estimate <- unname(out["Estimate"])
  se <- unname(out["Std. Error"])
  t_stat <- unname(out["t value"])
  p_value <- unname(out["Pr(>|t|)"])
  tibble(
    estimate = estimate,
    se = se,
    t_stat = t_stat,
    t2_manual_F = t_stat^2,
    p_value = p_value
  )
}

fs_no_weights_robust <- feols(fs_fml, data = audit_sample, vcov = "hetero", notes = FALSE)
fs_weights_robust <- feols(fs_fml, data = audit_sample, weights = ~hhweight, vcov = "hetero", notes = FALSE)
fs_weights_cluster <- feols(fs_fml, data = audit_sample, weights = ~hhweight, vcov = ~birth_aimag, notes = FALSE)

iv_weights_cluster <- feols(iv_fml, data = audit_sample, weights = ~hhweight, vcov = ~birth_aimag, notes = FALSE)
fixest_ivf1 <- tryCatch(
  as.numeric(fitstat(iv_weights_cluster, "ivf1")[[1]]$stat),
  error = function(e) NA_real_
)
fixest_ivf1_p <- tryCatch(
  as.numeric(fitstat(iv_weights_cluster, "ivf1")[[1]]$p),
  error = function(e) NA_real_
)

reported_F <- 602.23
f_audit <- bind_rows(
  extract_parent(fs_no_weights_robust) |> mutate(spec = "no weights, robust SE"),
  extract_parent(fs_weights_robust) |> mutate(spec = "weights, robust SE"),
  extract_parent(fs_weights_cluster) |> mutate(spec = "weights, birth_aimag cluster")
) |>
  mutate(
    wald_F_for_parent_educ_mean = t2_manual_F,
    fixest_ivf1_F = if_else(spec == "weights, birth_aimag cluster", fixest_ivf1, NA_real_),
    fixest_ivf1_p_value = if_else(spec == "weights, birth_aimag cluster", fixest_ivf1_p, NA_real_),
    reported_F_602_23_matches_manual_t2 = abs(t2_manual_F - reported_F) < 0.01,
    reported_F_602_23_matches_fixest_ivf1 = if_else(
      spec == "weights, birth_aimag cluster",
      abs(fixest_ivf1 - reported_F) < 0.01,
      NA
    )
  ) |>
  select(
    spec, estimate, se, t_stat, t2_manual_F, wald_F_for_parent_educ_mean,
    p_value, fixest_ivf1_F, fixest_ivf1_p_value,
    reported_F_602_23_matches_manual_t2,
    reported_F_602_23_matches_fixest_ivf1
  )

cluster_manual_F <- f_audit |>
  filter(spec == "weights, birth_aimag cluster") |>
  pull(t2_manual_F)

f_is_genuine_high <- !parent_uses_educ_years_flag &&
  !is.na(cluster_manual_F) &&
  cluster_manual_F >= 10 &&
  !is.na(fixest_ivf1) &&
  fixest_ivf1 >= 10

reported_f_wrong_extraction <- !is.na(cluster_manual_F) &&
  abs(cluster_manual_F - reported_F) >= 0.01 &&
  !is.na(fixest_ivf1) &&
  abs(fixest_ivf1 - reported_F) < 0.01

verdict <- if (parent_uses_educ_years_flag) {
  "parent_educ_mean accidentally uses educ_years; stop and fix the IV construction."
} else if (reported_f_wrong_extraction) {
  "Correct the reported F and update the IV report before IVTR. The IV is still strong, but the cluster-robust manual Wald/t^2 F differs from fixest ivf1."
} else if (f_is_genuine_high) {
  "F is genuine; proceed to IVTR, but keep exclusion caveat."
} else {
  "F audit inconclusive; review first-stage reporting before IVTR."
}

audit_table <- bind_rows(
  tibble(section = "construction", item = parent_trace$constructed_variable, value = parent_trace$formula),
  tibble(section = "construction", item = "uses_educ_years", value = as.character(parent_trace$uses_educ_years)),
  tibble(section = "construction", item = "source_variables", value = "father_educ_years, mother_educ_years"),
  tibble(section = "construction", item = "source_file", value = parent_trace$source_file),
  tibble(section = "construction", item = "ivtr_ready_parent_values_match_reconstruction", value = as.character(parent_trace$compared_to_ivtr_ready)),
  tibble(section = "sample", item = "audit_sample_N", value = as.character(nrow(audit_sample))),
  tibble(section = "sample", item = "ivtr_ready_N", value = as.character(nrow(ivtr_ready))),
  tibble(section = "correlation", item = correlations$metric, value = as.character(correlations$value)),
  summary_diagnostics |>
    mutate(
      section = "summary",
      item = variable,
      value = paste0(
        "n=", n_nonmissing,
        "; min=", min,
        "; p10=", p10,
        "; p25=", p25,
        "; p50=", p50,
        "; p75=", p75,
        "; p90=", p90,
        "; max=", max
      )
    ) |>
    select(section, item, value),
  f_audit |>
    mutate(
      section = "first_stage_F",
      item = spec,
      value = paste0(
        "coef=", estimate,
        "; se=", se,
        "; t=", t_stat,
        "; t2=", t2_manual_F,
        "; fixest_ivf1_F=", fixest_ivf1_F
      )
    ) |>
    select(section, item, value),
  tibble(section = "verdict", item = "final", value = verdict)
)

write_csv(audit_table, file.path(PATHS$out_tables, "T3a_parent_educ_mean_F_audit.csv"))

fmt <- function(x, digits = 4) ifelse(is.na(x), "NA", formatC(x, format = "f", digits = digits))
report_lines <- c(
  "# parent_educ_mean First-Stage F Audit",
  "",
  paste0("Generated: ", Sys.time()),
  "",
  "## Construction Trace",
  "- `parent_educ_mean` was reconstructed only from `father_educ_years` and `mother_educ_years`.",
  "- Formula: `rowMeans(cbind(father_educ_years, mother_educ_years), na.rm = TRUE); NaN -> NA`.",
  "- Source file for parent variables: `data/processed/family_structure.rds`.",
  paste0("- Uses `educ_years`: ", parent_uses_educ_years_flag),
  paste0("- Reconstructed values match IVTR-ready `parent_educ_mean`: ", same_parent_values),
  "",
  "## Sample",
  paste0("- Audit sample N: ", nrow(audit_sample)),
  paste0("- IVTR-ready N: ", nrow(ivtr_ready)),
  "",
  "## Correlations",
  paste0("- ", correlations$metric, ": ", fmt(correlations$value)),
  "",
  "## First-Stage F Audit",
  paste0(
    "- ", f_audit$spec,
    ": coef=", fmt(f_audit$estimate),
    ", SE=", fmt(f_audit$se),
    ", t=", fmt(f_audit$t_stat),
    ", t^2/Wald F=", fmt(f_audit$t2_manual_F),
    ifelse(is.na(f_audit$fixest_ivf1_F), "", paste0(", fixest ivf1 F=", fmt(f_audit$fixest_ivf1_F)))
  ),
  "",
  paste0("- Reported F=602.23 matches manual cluster t^2: ", abs(cluster_manual_F - reported_F) < 0.01),
  paste0("- Reported F=602.23 matches fixest ivf1 F: ", abs(fixest_ivf1 - reported_F) < 0.01),
  "",
  "## Verdict",
  verdict,
  "",
  "## Caveat",
  "Parent education may affect wages through family background, networks, and unobserved ability channels."
)

writeLines(report_lines, file.path(PATHS$out_root, "reports", "parent_educ_mean_F_audit.md"), useBytes = TRUE)

cat("Construction trace:\n")
print(parent_trace)
cat("\nCorrelations:\n")
print(correlations)
cat("\nSummary diagnostics:\n")
print(summary_diagnostics)
cat("\nFirst-stage F audit:\n")
print(f_audit)
cat("\nVerdict:", verdict, "\n")
cat("\nCompleted:", as.character(Sys.time()), "\n")
