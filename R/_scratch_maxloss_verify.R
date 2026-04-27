# Max_loss_rate 6-17 — F-stat верификация
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(here); library(fixest); library(tibble); library(readr)
})
setFixest_estimation(panel.id = NULL)
options(width = 130)

panel <- readRDS(here("data/auxiliary/dzud_panel.rds"))

exp_6_17 <- expand_grid(birth_aimag = sort(unique(panel$hses_code)),
                        birth_year  = 1955:2010) |>
  rowwise() |>
  mutate(maxv = suppressWarnings(max(panel$loss_rate[panel$hses_code == birth_aimag &
                                                     panel$year %in% (birth_year + 6):(birth_year + 17)],
                                     na.rm = TRUE)),
         n_obs = sum(!is.na(panel$loss_rate[panel$hses_code == birth_aimag &
                                            panel$year %in% (birth_year + 6):(birth_year + 17)]))) |>
  ungroup() |>
  mutate(maxv = ifelse(is.finite(maxv), maxv, NA_real_))

df <- readRDS(here("data/processed/analysis_sample.rds")) |> as_tibble()
main <- df |>
  filter(main_flag_25_60 == 1L,
         !is.na(q_school_access), is.finite(q_school_access),
         !is.na(birth_year), !is.na(educ_years), !is.na(lwage),
         !is.na(birth_aimag), !is.na(hhweight)) |>
  left_join(exp_6_17, by = c("birth_aimag", "birth_year")) |>
  filter(n_obs == 12) |>
  mutate(birth_cohort = case_when(
    birth_year < 1990 ~ "1985-89",
    birth_year < 1995 ~ "1990-94",
    TRUE              ~ "post1995"))

cat(sprintf("N=%d\n\n", nrow(main)))

# 1. First stage with V1 spec
fs_v1 <- feols(educ_years ~ maxv + age + age2 + is_female + is_married | region + wave,
               data = main, weights = ~hhweight, cluster = ~aimag + wave)
cat("=== V1 (region+wave) ===\n")
print(coeftable(fs_v1)["maxv", , drop = FALSE])
iv_v1 <- feols(lwage ~ age + age2 + is_female + is_married | region + wave |
                 educ_years ~ maxv,
               data = main, weights = ~hhweight, cluster = ~aimag + wave)
cat("ivf1 (Kleibergen-Paap):\n"); print(fitstat(iv_v1, "ivf1"))
cat(sprintf("Simple Wald t² = %.2f\n", coeftable(fs_v1)["maxv","t value"]^2))
cat(sprintf("2SLS β=%+.4f, SE=%.4f\n", coeftable(iv_v1)["fit_educ_years","Estimate"],
            coeftable(iv_v1)["fit_educ_years","Std. Error"]))

# 2. First stage with V2 spec
fs_v2 <- feols(educ_years ~ maxv + age + age2 + is_female + is_married |
                 birth_aimag + birth_cohort + wave,
               data = main, weights = ~hhweight, cluster = ~aimag + wave)
cat("\n=== V2 (birth_aimag + birth_cohort + wave) ===\n")
print(coeftable(fs_v2)["maxv", , drop = FALSE])
iv_v2 <- feols(lwage ~ age + age2 + is_female + is_married | birth_aimag + birth_cohort + wave |
                 educ_years ~ maxv,
               data = main, weights = ~hhweight, cluster = ~aimag + wave)
cat("ivf1 (Kleibergen-Paap):\n"); print(fitstat(iv_v2, "ivf1"))
cat(sprintf("Simple Wald t² = %.2f\n", coeftable(fs_v2)["maxv","t value"]^2))
cat(sprintf("2SLS β=%+.4f, SE=%.4f\n", coeftable(iv_v2)["fit_educ_years","Estimate"],
            coeftable(iv_v2)["fit_educ_years","Std. Error"]))

# 3. Even stricter: birth_aimag + birth_year + wave
fs_v3 <- feols(educ_years ~ maxv + is_female + is_married | birth_aimag + birth_year + wave,
               data = main, weights = ~hhweight, cluster = ~aimag + wave)
cat("\n=== V3 (birth_aimag + birth_year + wave) — STRICTEST ===\n")
print(coeftable(fs_v3)["maxv", , drop = FALSE])
cat(sprintf("Simple Wald t² = %.2f\n", coeftable(fs_v3)["maxv","t value"]^2))

cat("\n=== max_loss distribution by birth_year (within-aimag variation check) ===\n")
print(main |> group_by(birth_aimag, birth_year) |>
        summarise(maxv = first(maxv), .groups = "drop") |>
        group_by(birth_aimag) |>
        summarise(min_maxv = min(maxv), max_maxv = max(maxv),
                  range = max_maxv - min_maxv, .groups = "drop") |>
        arrange(desc(range)) |> head(10))


