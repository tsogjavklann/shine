# =============================================================================
# 30_academic_figures.R
# -----------------------------------------------------------------------------
# Зорилго : Одоогийн IV-threshold үр дүнгийн графикуудыг академик хэв маягтай,
#           Монгол нэршилтэй, paper-д шууд оруулахад тохиромжтой PNG болгон
#           дахин үүсгэх.
# Ашиглах : Rscript R/30_academic_figures.R
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readr)
  library(scales)
})

source(here::here("R", "paths.R"))

dir.create(PATHS$out_figures, recursive = TRUE, showWarnings = FALSE)

COLORS <- list(
  ink = "#202124",
  muted = "#5F6368",
  grid = "#E3E6EA",
  blue = "#1F4E79",
  teal = "#2F5D50",
  orange = "#9A5A2E",
  red = "#9E2F2F",
  gray = "#7A8087"
)

theme_academic <- function(base_size = 11) {
  theme_minimal(base_family = "Times New Roman", base_size = base_size) +
    theme(
      plot.title = element_text(face = "bold", size = base_size + 2,
                                colour = COLORS$ink, hjust = 0),
      plot.subtitle = element_text(size = base_size - 1, colour = COLORS$muted,
                                   margin = margin(t = 3, b = 7)),
      plot.caption = element_blank(),
      axis.title = element_text(face = "plain", size = base_size,
                                colour = COLORS$ink),
      axis.text = element_text(size = base_size - 1, colour = COLORS$ink),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = COLORS$grid, linewidth = 0.35),
      legend.position = "bottom",
      legend.title = element_blank(),
      legend.text = element_text(colour = COLORS$ink),
      strip.text = element_text(face = "bold", colour = COLORS$ink),
      plot.margin = margin(9, 14, 8, 10)
    )
}

save_academic <- function(plot, filename, width = 8, height = 5.2) {
  path <- file.path(PATHS$out_figures, filename)
  ggsave(path, plot, width = width, height = height, dpi = 300, bg = "white")
  message("Saved: ", path)
  invisible(path)
}

read_table <- function(filename) {
  read.csv(file.path(PATHS$out_tables, filename),
           stringsAsFactors = FALSE, check.names = FALSE)
}

pct <- function(x, digits = 1) sprintf(paste0("%.", digits, "f%%"), 100 * x)
pp <- function(x, digits = 1) sprintf(paste0("%.", digits, "f"), 100 * x)

parse_ci <- function(x) {
  nums <- regmatches(x, gregexpr("-?[0-9]+\\.?[0-9]*", x))[[1]]
  as.numeric(nums[1:2])
}

specs <- list(
  list(
    id = "student_teacher_avg_17_18",
    label = "17-18 насны дундаж сурагч-багшийн харьцаа",
    short = "17-18 нас",
    stem = "student_teacher_avg_17_18",
    stage = "stage28",
    grid = "T14c_student_teacher_avg_17_18_ch_threshold_grid.csv",
    gmm = "T14d_student_teacher_avg_17_18_ch_gmm_final_results.csv",
    boot = "T14e_student_teacher_avg_17_18_ch_bootstrap_inference.csv",
    draws = "T14e_student_teacher_avg_17_18_ch_bootstrap_draws.csv",
    baseline = "T14a_student_teacher_avg_17_18_baseline_ols_2sls.csv"
  ),
  list(
    id = "student_teacher_avg_16_18",
    label = "16-18 насны дундаж сурагч-багшийн харьцаа",
    short = "16-18 нас",
    stem = "student_teacher_avg_16_18",
    stage = "stage24",
    grid = "T11c_student_teacher_avg_16_18_ch_threshold_grid.csv",
    gmm = "T11d_student_teacher_avg_16_18_ch_gmm_final_results.csv",
    boot = "T11e_student_teacher_avg_16_18_ch_bootstrap_inference.csv",
    draws = "T11e_student_teacher_avg_16_18_ch_bootstrap_draws.csv",
    baseline = "T11a_student_teacher_avg_16_18_baseline_ols_2sls.csv"
  ),
  list(
    id = "student_teacher_avg_16_17",
    label = "16-17 насны дундаж сурагч-багшийн харьцаа",
    short = "16-17 нас",
    stem = "student_teacher_avg_16_17",
    stage = "stage27",
    grid = "T13c_student_teacher_avg_16_17_ch_threshold_grid.csv",
    gmm = "T13d_student_teacher_avg_16_17_ch_gmm_final_results.csv",
    boot = "T13e_student_teacher_avg_16_17_ch_bootstrap_inference.csv",
    draws = "T13e_student_teacher_avg_16_17_ch_bootstrap_draws.csv",
    baseline = "T13a_student_teacher_avg_16_17_baseline_ols_2sls.csv"
  ),
  list(
    id = "student_teacher17",
    label = "17 насны сурагч-багшийн харьцаа",
    short = "17 нас",
    stem = "student_teacher17",
    stage = "stage23",
    grid = "T9c_student_teacher17_ch_threshold_grid.csv",
    gmm = "T9d_student_teacher17_ch_gmm_final_results.csv",
    boot = "T9e_student_teacher17_ch_bootstrap_inference.csv",
    draws = "T9e_student_teacher17_ch_bootstrap_draws.csv",
    baseline = "T9a_student_teacher17_baseline_ols_2sls.csv"
  )
)

make_grid_plot <- function(spec) {
  grid <- read_table(spec$grid)
  gmm <- read_table(spec$gmm)
  gamma_hat <- unique(gmm$gamma_hat)[1]
  n_low <- unique(gmm$N_low)[1]
  n_high <- unique(gmm$N_high)[1]

  grid <- grid %>%
    mutate(ssr_centered = SSR_2SLS - min(SSR_2SLS, na.rm = TRUE))

  p <- ggplot(grid, aes(x = gamma, y = ssr_centered)) +
    geom_line(colour = COLORS$blue, linewidth = 0.95) +
    geom_point(data = filter(grid, is_gamma_hat),
               colour = COLORS$red, size = 2.8) +
    geom_vline(xintercept = gamma_hat, linetype = "dashed",
               colour = COLORS$red, linewidth = 0.75) +
    annotate("text", x = gamma_hat,
             y = max(grid$ssr_centered, na.rm = TRUE) * 0.94,
             label = paste0("Босго = ", sprintf("%.2f", gamma_hat)),
             family = "Times New Roman", fontface = "bold",
             colour = COLORS$red, hjust = -0.06, size = 3.7) +
    scale_y_continuous(labels = comma) +
    labs(
      title = "Босго хайлтын муруй",
      subtitle = paste0(spec$label, "  |  Доод: ", comma(n_low),
                        "  Дээд: ", comma(n_high)),
      x = "Сурагч-багшийн харьцааны босго",
      y = "ХШХБК алдааны квадратын нийлбэр"
    ) +
    theme_academic()

  save_academic(p, paste0(spec$stem, "_", spec$stage, "c_2sls_objective_grid.png"))
  save_academic(p, paste0("academic_", spec$stem, "_threshold_grid.png"))
}

make_regime_plot <- function(spec) {
  gmm <- read_table(spec$gmm)
  boot <- read_table(spec$boot)
  gamma_hat <- unique(gmm$gamma_hat)[1]
  beta_diff <- unique(gmm$beta_difference_high_minus_low)[1]
  boot_p <- boot$bootstrap_p_value[1]

  plot_data <- gmm %>%
    mutate(
      regime = if_else(term == "educ_low",
                       paste0("Доод регим\nХарьцаа ≤ ", sprintf("%.2f", gamma_hat)),
                       paste0("Дээд регим\nХарьцаа > ", sprintf("%.2f", gamma_hat))),
      regime = factor(regime, levels = unique(regime)),
      return_pct = 100 * (exp(estimate) - 1),
      lo = 100 * (exp(estimate - 1.96 * se) - 1),
      hi = 100 * (exp(estimate + 1.96 * se) - 1)
    )

  p <- ggplot(plot_data, aes(x = regime, y = return_pct)) +
    geom_hline(yintercept = 0, colour = COLORS$gray, linewidth = 0.4) +
    geom_pointrange(aes(ymin = lo, ymax = hi, colour = regime),
                    linewidth = 0.85, size = 0.85) +
    geom_text(aes(label = sprintf("%.1f%%", return_pct)),
              nudge_x = 0.13, nudge_y = 0.18, family = "Times New Roman",
              fontface = "bold", colour = COLORS$ink, size = 3.8) +
    scale_colour_manual(values = c(COLORS$blue, COLORS$orange)) +
    labs(
      title = "Регим тус бүрийн боловсролын өгөөж",
      subtitle = paste0(spec$label, "  |  Дээд − доод = ",
                        pp(beta_diff), " нэгж хувь, p = ",
                        sprintf("%.3f", boot_p)),
      x = NULL,
      y = "Нэг жилийн өгөөж (%)"
    ) +
    theme_academic() +
    theme(legend.position = "none")

  save_academic(p, paste0(spec$stem, "_", spec$stage, "d_gmm_regime_returns.png"),
                width = 7.2, height = 5.1)
  save_academic(p, paste0("academic_", spec$stem, "_regime_returns.png"),
                width = 7.2, height = 5.1)
}

make_gamma_boot_plot <- function(spec) {
  draws <- read_table(spec$draws) %>%
    mutate(failed_flag = failed_flag %in% c(TRUE, "TRUE", "true", "1")) %>%
    filter(!failed_flag)
  boot <- read_table(spec$boot)
  gamma_hat <- boot$gamma_observed[1]

  p <- ggplot(draws, aes(x = gamma_boot)) +
    geom_histogram(bins = 28, fill = COLORS$blue, colour = "white", linewidth = 0.35) +
    geom_vline(xintercept = gamma_hat, colour = COLORS$red, linewidth = 0.8) +
    geom_vline(xintercept = c(boot$gamma_q025[1], boot$gamma_q975[1]),
               colour = COLORS$ink, linetype = "dotted", linewidth = 0.65) +
    annotate("text", x = gamma_hat, y = Inf, vjust = 1.45,
             label = paste0("Босго = ", sprintf("%.2f", gamma_hat)),
             family = "Times New Roman", fontface = "bold",
             colour = COLORS$red, size = 3.5) +
    labs(
      title = "Босго үнэлгээний дахин түүвэрлэлтийн тархалт",
      subtitle = paste0(spec$label, "  |  Давталт = ", comma(boot$n_success[1]),
                        ", 95% интервал [", sprintf("%.2f", boot$gamma_q025[1]),
                        "; ", sprintf("%.2f", boot$gamma_q975[1]), "]"),
      x = "Дахин түүвэрлэлтийн босго",
      y = "Давтамж"
    ) +
    theme_academic()

  save_academic(p, paste0(spec$stem, "_", spec$stage, "e_gamma_bootstrap_distribution.png"))
  save_academic(p, paste0("academic_", spec$stem, "_gamma_bootstrap.png"))
}

make_beta_diff_boot_plot <- function(spec) {
  draws <- read_table(spec$draws) %>%
    mutate(failed_flag = failed_flag %in% c(TRUE, "TRUE", "true", "1")) %>%
    filter(!failed_flag)
  boot <- read_table(spec$boot)
  obs <- boot$beta_diff_observed[1]

  p <- ggplot(draws, aes(x = 100 * beta_diff_boot)) +
    geom_histogram(bins = 32, fill = COLORS$teal, colour = "white", linewidth = 0.35) +
    geom_vline(xintercept = 100 * obs, colour = COLORS$red, linewidth = 0.8) +
    geom_vline(xintercept = 0, colour = COLORS$ink, linetype = "dashed", linewidth = 0.65) +
    geom_vline(xintercept = c(100 * boot$beta_diff_q025[1], 100 * boot$beta_diff_q975[1]),
               colour = COLORS$ink, linetype = "dotted", linewidth = 0.65) +
    annotate("text", x = 100 * obs, y = Inf, vjust = 1.45,
             label = paste0("Ялгаа = ", pp(obs), " нэгж хувь"),
             family = "Times New Roman", fontface = "bold",
             colour = COLORS$red, size = 3.5) +
    labs(
      title = "Өгөөжийн ялгааны дахин түүвэрлэлтийн тархалт",
      subtitle = paste0("95% интервал [", pp(boot$beta_diff_q025[1]),
                        "; ", pp(boot$beta_diff_q975[1]), "] нэгж хувь; p = ",
                        sprintf("%.3f", boot$bootstrap_p_value[1])),
      x = "Дээд − доод регимийн өгөөж (нэгж хувь)",
      y = "Давтамж"
    ) +
    theme_academic()

  save_academic(p, paste0(spec$stem, "_", spec$stage, "e_beta_diff_bootstrap_distribution.png"))
  save_academic(p, paste0("academic_", spec$stem, "_beta_diff_bootstrap.png"))
}

make_baseline_plot <- function(spec) {
  baseline <- read_table(spec$baseline) %>%
    mutate(
      model_mn = recode(model,
                        "OLS baseline" = "ЭХБК",
                        "2SLS parent_educ_mean IV" = "ХШХБК\n(эцэг эхийн боловсрол)",
                        .default = model),
      model_mn = factor(model_mn, levels = model_mn),
      return_pct = 100 * (exp(estimate) - 1),
      lo = 100 * (exp(estimate - 1.96 * se) - 1),
      hi = 100 * (exp(estimate + 1.96 * se) - 1)
    )

  p <- ggplot(baseline, aes(x = model_mn, y = return_pct, colour = model_mn)) +
    geom_pointrange(aes(ymin = lo, ymax = hi), linewidth = 0.85, size = 0.85) +
    geom_text(aes(label = sprintf("%.1f%%", return_pct)),
              nudge_x = 0.12, family = "Times New Roman", fontface = "bold",
              colour = COLORS$ink, size = 3.8) +
    scale_colour_manual(values = c(COLORS$blue, COLORS$orange)) +
    labs(
      title = "Боловсролын өгөөжийн суурь үнэлгээ",
      subtitle = paste0(spec$label, " түүвэр дээрх ЭХБК ба ХШХБК харьцуулалт"),
      x = NULL,
      y = "Нэг жилийн өгөөж (%)"
    ) +
    theme_academic() +
    theme(legend.position = "none")

  save_academic(p, paste0("academic_", spec$stem, "_baseline_ols_2sls.png"),
                width = 7.2, height = 5.1)
}

make_threshold_comparison_plot <- function() {
  cmp <- read_table("T15f_full_ivtr_threshold_comparison.csv") %>%
    rowwise() %>%
    mutate(ci = list(parse_ci(bootstrap_CI_beta_diff)),
           ci_low = ci[1],
           ci_high = ci[2]) %>%
    ungroup() %>%
    mutate(
      q_label = recode(q_variable,
                       "q_school_access" = "Сургуулийн хүртээмж",
                       "log_distance_to_ub" = "УБ хүртэлх зай",
                       "student_teacher_ratio_at_17" = "Сурагч-багш, 17 нас",
                       "student_teacher_ratio_avg_16_17" = "Сурагч-багш, 16-17 нас",
                       "student_teacher_ratio_avg_16_18" = "Сурагч-багш, 16-18 нас",
                       "student_teacher_ratio_avg_17_18" = "Сурагч-багш, 17-18 нас",
                       .default = q_variable),
      q_label = factor(q_label, levels = rev(q_label)),
      support = if_else(conclusion == "suggestive", "Илэрцтэй", "Хүчтэй батлагдаагүй")
    )

  p <- ggplot(cmp, aes(y = q_label, x = 100 * beta_diff, colour = support)) +
    geom_vline(xintercept = 0, colour = COLORS$ink, linetype = "dashed", linewidth = 0.55) +
    geom_errorbar(aes(xmin = 100 * ci_low, xmax = 100 * ci_high),
                  orientation = "y", width = 0.18, linewidth = 0.8) +
    geom_point(size = 2.9) +
    geom_text(aes(label = paste0("p=", sprintf("%.3f", centered_bootstrap_p_value))),
              nudge_x = 0.65, family = "Times New Roman", size = 3.2,
              colour = COLORS$ink) +
    scale_colour_manual(values = c("Илэрцтэй" = COLORS$orange,
                                   "Хүчтэй батлагдаагүй" = COLORS$gray)) +
    labs(
      title = "Босго хувьсагчдын харьцуулалт",
      subtitle = "Дээд ба доод регимийн боловсролын өгөөжийн ялгаа",
      x = "Дээд − доод регимийн өгөөж (нэгж хувь)",
      y = NULL
    ) +
    theme_academic()

  save_academic(p, "academic_full_ivtr_threshold_comparison.png",
                width = 8.6, height = 5.4)
}

for (spec in specs) {
  message("\n--- ", spec$label, " ---")
  make_grid_plot(spec)
  make_regime_plot(spec)
  make_gamma_boot_plot(spec)
  make_beta_diff_boot_plot(spec)
  make_baseline_plot(spec)
}

make_threshold_comparison_plot()

message("\nAcademic figures generated successfully.")
