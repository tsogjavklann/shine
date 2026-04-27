# 6-17 window — PROPER cluster-robust Kleibergen-Paap F
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(here); library(fixest); library(tibble); library(readr)
})
setFixest_estimation(panel.id = NULL)
options(width = 130)

panel <- readRDS(here("data/auxiliary/dzud_panel.rds")) |>
  group_by(year) |>
  mutate(severe_p75 = as.integer(loss_rate >= quantile(loss_rate, 0.75, na.rm = TRUE))) |>
  ungroup()

exp_6_17 <- expand_grid(birth_aimag = sort(unique(panel$hses_code)),
                        birth_year  = 1955:2010) |>
  rowwise() |>
  mutate(
    cum     = sum(panel$loss_rate[panel$hses_code == birth_aimag &
                                  panel$year %in% (birth_year + 6):(birth_year + 17)],
                  na.rm = TRUE),
    log_cum = log1p(cum),
    maxv    = suppressWarnings(max(panel$loss_rate[panel$hses_code == birth_aimag &
                                                   panel$year %in% (birth_year + 6):(birth_year + 17)],
                                   na.rm = TRUE)),
    cnt5    = sum(panel$dzud_5pct[panel$hses_code == birth_aimag &
                                  panel$year %in% (birth_year + 6):(birth_year + 17)],
                  na.rm = TRUE),
    cnt10   = sum(panel$dzud_10pct[panel$hses_code == birth_aimag &
                                   panel$year %in% (birth_year + 6):(birth_year + 17)],
                  na.rm = TRUE),
    cntp75  = sum(panel$severe_p75[panel$hses_code == birth_aimag &
                                   panel$year %in% (birth_year + 6):(birth_year + 17)],
                  na.rm = TRUE),
    intensity = if_else(cnt5 > 0, cnt5 / 12, 0),
    n_obs   = sum(!is.na(panel$loss_rate[panel$hses_code == birth_aimag &
                                         panel$year %in% (birth_year + 6):(birth_year + 17)]))
  ) |>
  ungroup() |>
  mutate(maxv = ifelse(is.finite(maxv), maxv, NA_real_))

df <- readRDS(here("data/processed/analysis_sample.rds")) |> as_tibble()

# Two samples: partial coverage (N=9077) vs full coverage (N=7145)
build_sample <- function(filter_full) {
  d <- df |>
    filter(main_flag_25_60 == 1L,
           !is.na(q_school_access), is.finite(q_school_access),
           !is.na(birth_year), !is.na(educ_years), !is.na(lwage),
           !is.na(birth_aimag), !is.na(hhweight)) |>
    left_join(exp_6_17, by = c("birth_aimag", "birth_year")) |>
    mutate(birth_cohort = case_when(
      birth_year < 1990 ~ "1985-89",
      birth_year < 1995 ~ "1990-94",
      TRUE              ~ "post1995"))
  if (filter_full) d <- d |> filter(n_obs == 12)
  d
}

run_iv <- function(data, iv_var, fe_string) {
  fml_iv <- as.formula(sprintf(
    "lwage ~ age + age2 + is_female + is_married | %s | educ_years ~ %s", fe_string, iv_var))
  m <- tryCatch(feols(fml_iv, data = data, weights = ~hhweight, cluster = ~aimag + wave),
                error = function(e) NULL)
  if (is.null(m)) return(list(F=NA, b=NA, se=NA, pi=NA))
  fs <- summary(m, stage = 1)[[1]]
  pi_hat <- tryCatch(coeftable(fs)[iv_var,"Estimate"], error = function(e) NA_real_)
  F_kp <- tryCatch(fitstat(m, "ivf1")$ivf1$stat, error = function(e) NA_real_)
  b <- tryCatch(coeftable(m)["fit_educ_years","Estimate"], error = function(e) NA_real_)
  se <- tryCatch(coeftable(m)["fit_educ_years","Std. Error"], error = function(e) NA_real_)
  list(F=F_kp, b=b, se=se, pi=pi_hat)
}

ivs <- c("cum","log_cum","maxv","cnt5","cnt10","cntp75","intensity")
labels <- c("cum_loss_rate","log_cum_loss","max_loss_rate","cnt5","cnt10","cntp75","intensity")

cat("=================================================================\n")
cat("6-17 WINDOW — PROPER cluster-robust K-P F (ivf1)\n")
cat("=================================================================\n\n")

for (sample_name in c("partial (N=9077)", "full (N=7145)")) {
  data <- build_sample(filter_full = grepl("full", sample_name))
  cat(sprintf("\n--- Sample: %s ---\n", sample_name))
  cat(sprintf("%-15s | V1 (region+wave)            | V2 (birth_aimag+cohort+wave)\n", "IV"))
  cat(sprintf("%-15s | F      π̂      β_IV   SE     | F      π̂      β_IV   SE\n", ""))
  cat(strrep("-", 100), "\n")
  for (i in seq_along(ivs)) {
    r1 <- run_iv(data, ivs[i], "region + wave")
    r2 <- run_iv(data, ivs[i], "birth_aimag + birth_cohort + wave")
    cat(sprintf("%-15s | F=%5.2f  π̂=%+.3f  β=%+.3f  SE=%.3f | F=%5.2f  π̂=%+.3f  β=%+.3f  SE=%.3f\n",
                labels[i],
                r1$F, r1$pi, r1$b, r1$se,
                r2$F, r2$pi, r2$b, r2$se))
  }
}

cat("\n=================================================================\n")
cat("ИНТЕРПРЕТАЦИ\n")
cat("=================================================================\n")
cat("F = Kleibergen-Paap rk Wald F (cluster-robust ~aimag+wave)\n")
cat("Stock-Yogo 5%% critical (1 endog, 1 IV): F >= 16.38 strong, [10,16.38] OK, <10 weak\n")


