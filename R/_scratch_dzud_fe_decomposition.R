# =============================================================================
# Dzud IV — FE decomposition: identification source шалгалт
# Зорилго: v1-ийн F=12.5 нь between-aimag (chronic) уу, within-aimag (shock) уу?
# =============================================================================
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(here); library(fixest); library(tibble)
})
setFixest_estimation(panel.id = NULL)
options(width = 130)

panel <- readRDS(here("data/auxiliary/dzud_panel.rds")) |>
  group_by(year) |>
  mutate(severe_p75 = as.integer(loss_rate >= quantile(loss_rate, 0.75, na.rm = TRUE))) |>
  ungroup()

# Build 12-17 exposure (single window for clarity)
exp <- expand_grid(birth_aimag = sort(unique(panel$hses_code)),
                   birth_year  = 1955:2010) |>
  rowwise() |>
  mutate(cum_12_17 = sum(panel$loss_rate[panel$hses_code == birth_aimag &
                                         panel$year %in% (birth_year + 12):(birth_year + 17)],
                         na.rm = TRUE),
         cnt5_12_17 = sum(panel$dzud_5pct[panel$hses_code == birth_aimag &
                                          panel$year %in% (birth_year + 12):(birth_year + 17)],
                          na.rm = TRUE),
         n_obs = sum(!is.na(panel$loss_rate[panel$hses_code == birth_aimag &
                                            panel$year %in% (birth_year + 12):(birth_year + 17)]))) |>
  ungroup()

df <- readRDS(here("data/processed/analysis_sample.rds")) |> as_tibble()
main <- df |>
  filter(main_flag_25_60 == 1L,
         !is.na(q_school_access), is.finite(q_school_access),
         !is.na(birth_year), !is.na(educ_years), !is.na(lwage),
         !is.na(birth_aimag), !is.na(hhweight)) |>
  left_join(exp, by = c("birth_aimag", "birth_year")) |>
  filter(n_obs == 6) |>
  mutate(birth_cohort = case_when(
    birth_year < 1970 ~ "pre1970",
    birth_year < 1975 ~ "1970-74",
    birth_year < 1980 ~ "1975-79",
    birth_year < 1985 ~ "1980-84",
    birth_year < 1990 ~ "1985-89",
    birth_year < 1995 ~ "1990-94",
    TRUE              ~ "post1995"))

cat(sprintf("Sample N = %d\n\n", nrow(main)))

# --- VARIANCE DECOMPOSITION of dzud variable ---
cat("=================================================================\n")
cat("VARIANCE DECOMPOSITION: cum_12_17 (cumulative dzud loss-rate)\n")
cat("=================================================================\n")

m_aimag       <- feols(cum_12_17 ~ 1 | birth_aimag, data = main)
m_year        <- feols(cum_12_17 ~ 1 | birth_year, data = main)
m_aim_year    <- feols(cum_12_17 ~ 1 | birth_aimag + birth_year, data = main)
m_aim_cohort  <- feols(cum_12_17 ~ 1 | birth_aimag + birth_cohort, data = main)
m_region      <- feols(cum_12_17 ~ 1 | region, data = main)
m_reg_wave    <- feols(cum_12_17 ~ 1 | region + wave, data = main)

show_r2 <- function(m, label) {
  r2 <- fitstat(m, "r2")$r2
  cat(sprintf("  %-40s R² = %.4f\n", label, r2))
}
show_r2(m_aimag,      "birth_aimag FE only")
show_r2(m_year,       "birth_year FE only")
show_r2(m_aim_year,   "birth_aimag + birth_year FE")
show_r2(m_aim_cohort, "birth_aimag + birth_cohort (5y) FE")
show_r2(m_region,     "region FE only")
show_r2(m_reg_wave,   "region + wave FE (V1 spec)")

cat(sprintf("\nИнтерпретация:\n"))
cat(sprintf("  Хэрэв birth_aimag FE-р R² ≈ 1: бүх variation aimag-аас (chronic, time-invariant)\n"))
cat(sprintf("  Хэрэв birth_aimag+cohort R² << 1: жинхэнэ within-aimag time variation байна\n\n"))

# --- F-stat across FE specs ---
cat("=================================================================\n")
cat("FIRST-STAGE F (educ ~ cum_12_17 + ctrls): различные FE\n")
cat("=================================================================\n")

run_fs <- function(label, fe_string, cluster_string = "~aimag + wave") {
  fml <- as.formula(sprintf("educ_years ~ cum_12_17 + age + age2 + is_female + is_married | %s", fe_string))
  m <- tryCatch(feols(fml, data = main, weights = ~hhweight,
                      cluster = as.formula(cluster_string)),
                error = function(e) NULL)
  if (is.null(m)) { cat(sprintf("  %-50s ERROR\n", label)); return() }
  ct <- coeftable(m)
  if (!"cum_12_17" %in% rownames(ct)) {
    cat(sprintf("  %-50s collinear/dropped\n", label)); return()
  }
  est <- ct["cum_12_17","Estimate"]
  se  <- ct["cum_12_17","Std. Error"]
  t   <- ct["cum_12_17","t value"]
  p   <- ct["cum_12_17","Pr(>|t|)"]
  cat(sprintf("  %-50s π̂=%+.4f  SE=%.4f  t=%+.2f  F=%.2f  p=%.4f\n",
              label, est, se, t, t^2, p))
}

cat("\n--- IV1: cum_12_17 (cumulative loss rate, 12-17 window) ---\n")
run_fs("V1: region + wave",                 "region + wave")
run_fs("birth_aimag + wave",                "birth_aimag + wave")
run_fs("V2: birth_aimag + birth_cohort + wave", "birth_aimag + birth_cohort + wave")

# IV2: cnt5_6_17 (count of >=5% dzud, 6-17 broad window — original "F=12.5" spec)
cat("\n--- IV2: cnt5_6_17 (count of >=5% dzud-years, age 6-17) ---\n")
run_fs2 <- function(label, fe_string) {
  fml <- as.formula(sprintf("educ_years ~ cnt5_6_17 + age + age2 + is_female + is_married | %s", fe_string))
  m <- tryCatch(feols(fml, data = main, weights = ~hhweight, cluster = ~aimag + wave),
                error = function(e) NULL)
  if (is.null(m)) { cat(sprintf("  %-50s ERROR\n", label)); return() }
  ct <- coeftable(m)
  if (!"cnt5_6_17" %in% rownames(ct)) {
    cat(sprintf("  %-50s collinear/dropped\n", label)); return()
  }
  est <- ct["cnt5_6_17","Estimate"]; se <- ct["cnt5_6_17","Std. Error"]
  t <- ct["cnt5_6_17","t value"]; p <- ct["cnt5_6_17","Pr(>|t|)"]
  cat(sprintf("  %-50s π̂=%+.4f  SE=%.4f  t=%+.2f  F=%.2f  p=%.4f\n",
              label, est, se, t, t^2, p))
}
# Need to add cnt5_6_17 to main frame first
exp_6_17 <- expand_grid(birth_aimag = sort(unique(panel$hses_code)),
                        birth_year  = 1955:2010) |>
  rowwise() |>
  mutate(cnt5_6_17 = sum(panel$dzud_5pct[panel$hses_code == birth_aimag &
                                         panel$year %in% (birth_year + 6):(birth_year + 17)],
                         na.rm = TRUE),
         n6 = sum(!is.na(panel$loss_rate[panel$hses_code == birth_aimag &
                                         panel$year %in% (birth_year + 6):(birth_year + 17)]))) |>
  ungroup()
main <- main |> left_join(exp_6_17, by = c("birth_aimag","birth_year")) |> filter(n6 == 12)

run_fs2("V1: region + wave",                 "region + wave")
run_fs2("birth_aimag + wave",                "birth_aimag + wave")
run_fs2("V2: birth_aimag + birth_cohort + wave", "birth_aimag + birth_cohort + wave")
run_fs2("birth_aimag + birth_year + wave",   "birth_aimag + birth_year + wave")

# Variance decomposition for cnt5_6_17
cat("\n--- VARIANCE DECOMPOSITION of cnt5_6_17 ---\n")
m1 <- feols(cnt5_6_17 ~ 1 | birth_aimag, data = main)
m2 <- feols(cnt5_6_17 ~ 1 | birth_aimag + birth_cohort, data = main)
m3 <- feols(cnt5_6_17 ~ 1 | region + wave, data = main)
cat(sprintf("  birth_aimag FE only:                R² = %.4f\n", fitstat(m1,"r2")$r2))
cat(sprintf("  birth_aimag + birth_cohort FE:      R² = %.4f\n", fitstat(m2,"r2")$r2))
cat(sprintf("  region + wave FE (V1):              R² = %.4f\n", fitstat(m3,"r2")$r2))

cat(sprintf("\n=================================================================\n"))
cat("ДҮГНЭЛТ — ИДЕНТИФИКАЦИЙН ЭХ СУРВАЛЖ\n")
cat("=================================================================\n")
cat("Хэрэв 'birth_aimag + wave' F<5 БОЛОВЧ 'region + wave' F=12.5 БОЛ:\n")
cat("→ V1 нь aimag-level chronic ялгаа (Завхан vs УБ)-аас identification ирсэн\n")
cat("→ Бенин: dzud-prone aimags урт хугацаандаа нэг л education + wage хослолтой\n")
cat("→ Exclusion violated: dzud дамжуулагч биш, харин 'remoteness' дамжуулагч\n")


