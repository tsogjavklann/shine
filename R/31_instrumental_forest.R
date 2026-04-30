# =============================================================================
# 31_instrumental_forest.R
# -----------------------------------------------------------------------------
# Purpose:
#   Add an exploratory Instrumental Forest / Local IV Forest analysis.
#
# Design:
#   Outcome: lwage
#   Endogenous regressor: educ_years
#   IV: parent_educ_mean
#   Heterogeneity features: demographics, student-teacher ratio, school access,
#     birth aimag, birth cohort, and survey wave.
#
# Important:
#   - This script does not replace the main IV-threshold regression.
#   - The output should be framed as exploratory heterogeneity evidence.
#   - parent_educ_mean remains the IV and is not used as an X feature.
# =============================================================================

options(warn = 1, encoding = "UTF-8")

renv_lib <- file.path(getwd(), "renv", "library", "windows", "R-4.4", "x86_64-w64-mingw32")
if (dir.exists(renv_lib)) {
  .libPaths(c(normalizePath(renv_lib), .libPaths()))
}

source(file.path("R", "paths.R"), encoding = "UTF-8-BOM")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
  library(ggplot2)
  library(scales)
  library(grf)
})

dir.create(PATHS$out_tables, recursive = TRUE, showWarnings = FALSE)
dir.create(PATHS$out_figures, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(PATHS$out_root, "reports"), recursive = TRUE, showWarnings = FALSE)
dir.create(PATHS$out_logs, recursive = TRUE, showWarnings = FALSE)

log_path <- file.path(PATHS$out_logs, "31_instrumental_forest.log")
sink(log_path, split = TRUE)
on.exit(sink(), add = TRUE)

cat("31_instrumental_forest.R\n")
cat("Started:", as.character(Sys.time()), "\n\n")

set.seed(20260428)

fmt <- function(x, digits = 4) {
  ifelse(is.na(x), "NA", formatC(x, format = "f", digits = digits))
}

pct_effect <- function(beta) {
  100 * (exp(beta) - 1)
}

safe_read_csv <- function(path) {
  if (!file.exists(path)) return(NULL)
  suppressMessages(readr::read_csv(path, show_col_types = FALSE))
}

theme_academic <- function(base_size = 11) {
  theme_minimal(base_family = "Times New Roman", base_size = base_size) +
    theme(
      plot.title = element_text(face = "bold", colour = "#1F2328", size = base_size + 2),
      plot.subtitle = element_text(colour = "#5B6470", size = base_size - 1),
      axis.title = element_text(colour = "#1F2328"),
      axis.text = element_text(colour = "#1F2328"),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = "#E6E1D8", linewidth = 0.32),
      legend.position = "bottom",
      legend.title = element_blank(),
      plot.margin = margin(9, 14, 8, 10)
    )
}

save_plot <- function(plot, filename, width = 8, height = 5.2) {
  path <- file.path(PATHS$out_figures, filename)
  ggsave(path, plot, width = width, height = height, dpi = 300, bg = "white")
  cat("Saved figure:", path, "\n")
  invisible(path)
}

sample_path <- file.path(PATHS$data_proc, "ivtr_ready_parent_educ_mean_student_teacher_avg_17_18.rds")
if (!file.exists(sample_path)) {
  stop("Missing IVTR-ready sample: ", sample_path,
       "\nRun R/28_student_teacher_avg_17_18_ch_parallel_bootstrap.R first.")
}

raw <- readRDS(sample_path) |>
  as_tibble()

if (!"female" %in% names(raw) && "is_female" %in% names(raw)) {
  raw$female <- raw$is_female
}
if (!"married" %in% names(raw) && "is_married" %in% names(raw)) {
  raw$married <- raw$is_married
}
if (!"q_school_access" %in% names(raw)) {
  raw$q_school_access <- NA_real_
}

dat <- raw |>
  mutate(
    lwage = as.numeric(lwage),
    educ_years = as.numeric(educ_years),
    parent_educ_mean = as.numeric(parent_educ_mean),
    age = as.numeric(age),
    age2 = as.numeric(age2),
    female = as.numeric(female),
    married = as.numeric(married),
    urban_raw = as.numeric(urban),
    urban = case_when(
      urban_raw == 1 ~ 1,
      urban_raw %in% c(0, 2) ~ 0,
      TRUE ~ NA_real_
    ),
    student_teacher_ratio_avg_17_18 = as.numeric(student_teacher_ratio_avg_17_18),
    q_school_access = as.numeric(q_school_access),
    birth_aimag = as.factor(birth_aimag),
    birth_cohort = as.factor(birth_cohort),
    wave = as.factor(wave),
    hhweight = as.numeric(hhweight)
  ) |>
  filter(
    is.finite(lwage),
    is.finite(educ_years),
    is.finite(parent_educ_mean),
    is.finite(age),
    is.finite(age2),
    is.finite(female),
    is.finite(married),
    is.finite(urban),
    is.finite(student_teacher_ratio_avg_17_18),
    is.finite(hhweight),
    hhweight > 0,
    !is.na(birth_aimag),
    !is.na(birth_cohort),
    !is.na(wave)
  )

if (nrow(dat) < 500) stop("Too few complete observations for Instrumental Forest.")

if (all(is.na(dat$q_school_access))) {
  feature_formula <- ~ age + age2 + female + married + urban +
    student_teacher_ratio_avg_17_18 +
    birth_aimag + birth_cohort + wave
} else {
  feature_formula <- ~ age + age2 + female + married + urban +
    student_teacher_ratio_avg_17_18 + q_school_access +
    birth_aimag + birth_cohort + wave
}

X <- model.matrix(feature_formula, data = dat)[, -1, drop = FALSE]
Y <- dat$lwage
W <- dat$educ_years
Z <- dat$parent_educ_mean
weights <- dat$hhweight / mean(dat$hhweight, na.rm = TRUE)
clusters <- as.integer(dat$birth_aimag)

num_trees <- as.integer(Sys.getenv("GRF_TREES", unset = "2000"))
if (is.na(num_trees) || num_trees < 500) num_trees <- 2000L

num_threads <- as.integer(Sys.getenv("GRF_THREADS", unset = "3"))
if (is.na(num_threads) || num_threads < 1) num_threads <- 1L

cat("Sample N:", nrow(dat), "\n")
cat("X columns:", ncol(X), "\n")
cat("Trees:", num_trees, "\n")
cat("Threads:", num_threads, "\n")
cat("Clusters:", dplyr::n_distinct(dat$birth_aimag), "\n\n")

forest <- instrumental_forest(
  X = X,
  Y = Y,
  W = W,
  Z = Z,
  num.trees = num_trees,
  sample.weights = weights,
  clusters = clusters,
  num.threads = num_threads,
  seed = 20260428
)

pred <- predict(forest, estimate.variance = TRUE)
tau_hat <- as.numeric(pred$predictions)
tau_se <- if ("variance.estimates" %in% names(pred)) sqrt(pmax(as.numeric(pred$variance.estimates), 0)) else NA_real_

baseline <- safe_read_csv(file.path(PATHS$out_tables, "T14a_student_teacher_avg_17_18_baseline_ols_2sls.csv"))
gamma_tbl <- safe_read_csv(file.path(PATHS$out_tables, "T14c_student_teacher_avg_17_18_ch_gamma_hat.csv"))

iv_2sls_beta <- NA_real_
ols_beta <- NA_real_
if (!is.null(baseline)) {
  iv_2sls_beta <- baseline |>
    filter(grepl("2SLS", model)) |>
    pull(estimate) |>
    first()
  ols_beta <- baseline |>
    filter(grepl("OLS", model)) |>
    pull(estimate) |>
    first()
}

gamma_hat <- if (!is.null(gamma_tbl) && "gamma_hat" %in% names(gamma_tbl)) {
  gamma_tbl$gamma_hat[1]
} else {
  19.53062264661216
}

predictions <- dat |>
  transmute(
    id = if ("id" %in% names(dat)) id else row_number(),
    lwage,
    educ_years,
    parent_educ_mean,
    age,
    female,
    married,
    urban,
    birth_aimag = as.character(birth_aimag),
    birth_cohort = as.character(birth_cohort),
    wave = as.character(wave),
    student_teacher_ratio_avg_17_18,
    q_school_access,
    tau_hat = tau_hat,
    tau_se = tau_se,
    tau_return_pct = pct_effect(tau_hat),
    threshold_regime = if_else(
      student_teacher_ratio_avg_17_18 <= gamma_hat,
      "Доод STR регим",
      "Дээд STR регим"
    )
  )

write_csv(predictions, file.path(PATHS$out_tables, "T16_instrumental_forest_predictions.csv"))

tau_summary <- tibble(
  item = c(
    "N",
    "num_trees",
    "X_features",
    "mean_tau_log",
    "median_tau_log",
    "sd_tau_log",
    "p10_tau_log",
    "p90_tau_log",
    "mean_return_pct",
    "median_return_pct",
    "p10_return_pct",
    "p90_return_pct",
    "OLS_beta_log_reference",
    "IV_2SLS_beta_log_reference",
    "threshold_gamma_reference"
  ),
  value = c(
    nrow(dat),
    num_trees,
    ncol(X),
    mean(tau_hat, na.rm = TRUE),
    median(tau_hat, na.rm = TRUE),
    sd(tau_hat, na.rm = TRUE),
    quantile(tau_hat, 0.10, na.rm = TRUE, names = FALSE),
    quantile(tau_hat, 0.90, na.rm = TRUE, names = FALSE),
    mean(predictions$tau_return_pct, na.rm = TRUE),
    median(predictions$tau_return_pct, na.rm = TRUE),
    quantile(predictions$tau_return_pct, 0.10, na.rm = TRUE, names = FALSE),
    quantile(predictions$tau_return_pct, 0.90, na.rm = TRUE, names = FALSE),
    ols_beta,
    iv_2sls_beta,
    gamma_hat
  )
)
write_csv(tau_summary, file.path(PATHS$out_tables, "T16_instrumental_forest_summary.csv"))

predictions <- predictions |>
  mutate(
    tau_group = ntile(tau_hat, 4),
    tau_group_label = case_when(
      tau_group == 1 ~ "Доод 25%",
      tau_group == 2 ~ "Дунд-доод 25%",
      tau_group == 3 ~ "Дунд-дээд 25%",
      tau_group == 4 ~ "Дээд 25%",
      TRUE ~ NA_character_
    )
  )

group_summary <- predictions |>
  group_by(tau_group_label) |>
  summarise(
    N = n(),
    mean_tau_log = mean(tau_hat, na.rm = TRUE),
    mean_return_pct = mean(tau_return_pct, na.rm = TRUE),
    median_student_teacher_ratio_17_18 = median(student_teacher_ratio_avg_17_18, na.rm = TRUE),
    urban_share = mean(urban, na.rm = TRUE),
    female_share = mean(female, na.rm = TRUE),
    mean_age = mean(age, na.rm = TRUE),
    mean_parent_educ = mean(parent_educ_mean, na.rm = TRUE),
    .groups = "drop"
  )

regime_summary <- predictions |>
  group_by(threshold_regime) |>
  summarise(
    N = n(),
    mean_tau_log = mean(tau_hat, na.rm = TRUE),
    mean_return_pct = mean(tau_return_pct, na.rm = TRUE),
    median_student_teacher_ratio_17_18 = median(student_teacher_ratio_avg_17_18, na.rm = TRUE),
    urban_share = mean(urban, na.rm = TRUE),
    female_share = mean(female, na.rm = TRUE),
    mean_age = mean(age, na.rm = TRUE),
    .groups = "drop"
  )

write_csv(group_summary, file.path(PATHS$out_tables, "T16_instrumental_forest_tau_quartiles.csv"))
write_csv(regime_summary, file.path(PATHS$out_tables, "T16_instrumental_forest_threshold_regimes.csv"))

vi_raw <- tibble(
  variable = colnames(X),
  importance = as.numeric(variable_importance(forest))
) |>
  mutate(
    family = case_when(
      grepl("^student_teacher_ratio", variable) ~ "Сурагч-багшийн харьцаа",
      grepl("^q_school_access", variable) ~ "Сургуулийн хүртээмж",
      grepl("^age|^female|^married|^urban", variable) ~ "Хувийн шинж",
      grepl("^birth_aimag", variable) ~ "Төрсөн аймаг",
      grepl("^birth_cohort", variable) ~ "Төрсөн үе",
      grepl("^wave", variable) ~ "Судалгааны давалгаа",
      TRUE ~ "Бусад"
    )
  ) |>
  arrange(desc(importance))

vi_family <- vi_raw |>
  group_by(family) |>
  summarise(importance = sum(importance, na.rm = TRUE), .groups = "drop") |>
  mutate(share = importance / sum(importance, na.rm = TRUE)) |>
  arrange(desc(importance))

write_csv(vi_raw, file.path(PATHS$out_tables, "T16_instrumental_forest_variable_importance_raw.csv"))
write_csv(vi_family, file.path(PATHS$out_tables, "T16_instrumental_forest_variable_importance.csv"))

p_hist <- ggplot(predictions, aes(x = tau_return_pct)) +
  geom_histogram(bins = 35, fill = "#1D4E89", colour = "white", linewidth = 0.2, alpha = 0.90) +
  geom_vline(xintercept = pct_effect(iv_2sls_beta), linetype = "dashed", colour = "#A03A3A", linewidth = 0.8) +
  labs(
    title = "Instrumental Forest: боловсролын өгөөжийн тархалт",
    subtitle = "Local IV өгөөжийн таамагласан тархалт; тасархай шугам нь ХШХБК дундаж өгөөж",
    x = "Боловсролын нэг жилийн өгөөж, хувь",
    y = "Ажиглалтын тоо"
  ) +
  theme_academic()
save_plot(p_hist, "instrumental_forest_tau_distribution.png")

p_str <- ggplot(predictions, aes(x = student_teacher_ratio_avg_17_18, y = tau_return_pct, colour = threshold_regime)) +
  geom_point(alpha = 0.28, size = 1.05) +
  geom_smooth(method = "loess", se = TRUE, linewidth = 0.9) +
  geom_vline(xintercept = gamma_hat, linetype = "dashed", colour = "#A03A3A", linewidth = 0.8) +
  scale_colour_manual(values = c("Доод STR регим" = "#2D6A5F", "Дээд STR регим" = "#B88A2E")) +
  labs(
    title = "Local IV өгөөж ба сургуулийн орчны босго",
    subtitle = paste0("Босго = ", fmt(gamma_hat, 2), "; зураг нь exploratory heterogeneity map"),
    x = "17-18 насны сурагч-багшийн дундаж харьцаа",
    y = "Instrumental Forest өгөөж, хувь"
  ) +
  theme_academic()
save_plot(p_str, "instrumental_forest_tau_by_student_teacher_ratio.png")

p_vi <- ggplot(vi_family, aes(x = reorder(family, importance), y = share)) +
  geom_col(fill = "#1D4E89", width = 0.68) +
  coord_flip() +
  scale_y_continuous(labels = percent_format(accuracy = 1)) +
  labs(
    title = "Instrumental Forest: heterogeneity-г ялгахад ашиглагдсан мэдээлэл",
    subtitle = "Variable importance-ийг бүлгээр нэгтгэсэн үзүүлэлт",
    x = NULL,
    y = "Харьцангуй ач холбогдол"
  ) +
  theme_academic()
save_plot(p_vi, "instrumental_forest_variable_importance.png", width = 7.4, height = 4.8)

report_lines <- c(
  "# Instrumental Forest Exploratory Heterogeneity Analysis",
  "",
  paste0("Generated: ", Sys.time()),
  "",
  "## Design",
  "",
  "- Outcome: `lwage`.",
  "- Endogenous regressor: `educ_years`.",
  "- Instrument: `parent_educ_mean`.",
  "- Features: age, gender, marital status, urban status, student-teacher ratio, school access, birth aimag, birth cohort, and survey wave.",
  "- This is an exploratory heterogeneity map, not a replacement for the main IV-threshold model.",
  "",
  "## Main Outputs",
  "",
  paste0("- Sample size: ", nrow(dat), "."),
  paste0("- Number of trees: ", num_trees, "."),
  paste0("- Mean predicted local IV return: ", fmt(mean(predictions$tau_return_pct, na.rm = TRUE), 2), "%."),
  paste0("- Median predicted local IV return: ", fmt(median(predictions$tau_return_pct, na.rm = TRUE), 2), "%."),
  paste0("- 10th-90th percentile range: ",
         fmt(quantile(predictions$tau_return_pct, 0.10, na.rm = TRUE, names = FALSE), 2),
         "% to ",
         fmt(quantile(predictions$tau_return_pct, 0.90, na.rm = TRUE, names = FALSE), 2),
         "%."),
  "",
  "## Threshold-Regime Comparison",
  "",
  paste(capture.output(print(regime_summary)), collapse = "\n"),
  "",
  "## Interpretation For The Report",
  "",
  "The main IV-threshold regression tests whether returns differ across a specific school-environment threshold. The Instrumental Forest exercise asks the related question in a more data-driven way: do predicted IV returns vary across observed characteristics without forcing all heterogeneity into one pre-selected split? The results should be presented as exploratory evidence of heterogeneity, because the exclusion restriction for parental education remains a substantive identifying assumption.",
  "",
  "## Suggested Mongolian Wording",
  "",
  "Үндсэн ХХБР загвар боловсролын өгөөж 17-18 насны сурагч-багшийн харьцааны босгоор ялгаатай эсэхийг шалгасан бол нэмэлтээр Instrumental Forest аргыг ашиглан өгөөжийн ялгаатай байдлыг урьдчилан нэг босго оноохгүйгээр, өгөгдөлд суурилсан эрэл хайгуулын байдлаар үнэлэв. Энэхүү шинжилгээ нь үндсэн шалтгаант дүгнэлтийг орлохгүй, харин боловсролын өгөөжийн ялгаатай байдал сургуулийн орчин, бүс нутаг, хувь хүний шинжүүдтэй хэрхэн хавсарч байгааг дүрслэх зорилготой.",
  "",
  "## Files",
  "",
  "- `output/tables/T16_instrumental_forest_summary.csv`",
  "- `output/tables/T16_instrumental_forest_tau_quartiles.csv`",
  "- `output/tables/T16_instrumental_forest_threshold_regimes.csv`",
  "- `output/tables/T16_instrumental_forest_variable_importance.csv`",
  "- `output/figures/instrumental_forest_tau_distribution.png`",
  "- `output/figures/instrumental_forest_tau_by_student_teacher_ratio.png`",
  "- `output/figures/instrumental_forest_variable_importance.png`"
)

writeLines(report_lines, file.path(PATHS$out_root, "reports", "instrumental_forest_exploratory_summary.md"))

cat("\nSummary:\n")
print(tau_summary)
cat("\nTau quartiles:\n")
print(group_summary)
cat("\nThreshold regimes:\n")
print(regime_summary)
cat("\nVariable importance by family:\n")
print(vi_family)
cat("\nFinished:", as.character(Sys.time()), "\n")
