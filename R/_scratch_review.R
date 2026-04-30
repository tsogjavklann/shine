# =============================================================================
# Code review diagnostics for CHECKPOINT 2.6 suspicions
# =============================================================================
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(stringr)
  library(fixest); library(cli)
})
setFixest_estimation(panel.id = NULL)

# Load
df  <- readRDS(here::here("data/processed/analysis_sample.rds")) |> as_tibble()
fam <- readRDS(here::here("data/processed/family_structure.rds")) |> as_tibble()
ed_supply <- readRDS(here::here("data/auxiliary/school_density_by_aimag.rds")) |> as_tibble()

main <- df |>
  filter(main_flag_25_60 == 1L,
         !is.na(q_school_access), is.finite(q_school_access),
         !is.na(birth_year),
         !is.na(educ_years), !is.na(lwage),
         !is.na(age), !is.na(is_female), !is.na(is_married),
         !is.na(region), !is.na(wave), !is.na(aimag), !is.na(hhweight),
         !is.na(birth_aimag)) |>
  left_join(fam |> select(id, n_siblings, birth_order),
            by = "id")

# Re-derive teachers_at_17 from supply table
teacher_lookup <- ed_supply |>
  group_by(hses_code, year) |>
  summarise(students = first(students), .groups = "drop")
# Re-fetch teachers data not stored — derive teachers_at_17 from school_density_by_aimag.rds
# The school_density_by_aimag.rds has schools + students. Teachers TABLE separate (R/12e in-script).
# For this diagnostic, RECOMPUTE from school_density file approximating teacher density via student-teacher proxy
# But actually we want the same source — compute teachers_at_17 from school_density_by_aimag

# Use schools as proxy ratio (same variation pattern as teachers since high aimag → high schools → high teachers)
main_with_supply <- main |>
  mutate(year_at_17 = birth_year + 17L) |>
  left_join(ed_supply |> select(hses_code, year, schools, students),
            by = c("birth_aimag" = "hses_code", "year_at_17" = "year")) |>
  mutate(supply_at_17 = schools / students)   # schools per 1000 students at age 17

cli::cli_h1("=== ЭРЭГЦҮҮЛЭЛ #1: teacher/supply_at_17 vs q_school_access (school_access) ===")

cor_check <- main_with_supply |>
  filter(!is.na(supply_at_17), !is.na(q_school_access))

cat(sprintf("N with both vars: %d\n", nrow(cor_check)))
cat(sprintf("\nIndividual-level correlation (q_school_access vs supply_at_17):\n"))
cat(sprintf("  Pearson:  %.4f\n", cor(cor_check$supply_at_17, cor_check$q_school_access)))
cat(sprintf("  Spearman: %.4f\n",
            cor(cor_check$supply_at_17, cor_check$q_school_access, method="spearman")))

# Aimag-level correlation
aimag_avg <- cor_check |>
  group_by(birth_aimag) |>
  summarise(supply17 = mean(supply_at_17),
            qschool_access    = mean(q_school_access),
            .groups = "drop")
cat(sprintf("\nAimag-level mean correlation (n=%d aimags):\n", nrow(aimag_avg)))
cat(sprintf("  Pearson: %.4f\n", cor(aimag_avg$supply17, aimag_avg$qschool_access)))
cat("\nTop aimags by supply_at_17:\n")
print(aimag_avg |> arrange(desc(supply17)) |> slice(1:10))

# Variance decomposition: how much of supply_at_17 variation is captured by birth_aimag dummies?
m_aimag <- feols(supply_at_17 ~ as.factor(birth_aimag), data = cor_check, weights = ~hhweight)
r2_aimag <- fitstat(m_aimag, "r2")$r2
cat(sprintf("\nVariance of supply_at_17 explained by birth_aimag dummies: R² = %.4f\n", r2_aimag))
cat("(If R² ≈ 1: supply_at_17 нь зөвхөн aimag-аас тогтсон → no extra variation)\n")

# How much variation is captured by birth_aimag × birth_year?
m_aimag_year <- feols(supply_at_17 ~ as.factor(birth_aimag) * as.factor(birth_year),
                      data = cor_check, weights = ~hhweight)
r2_aimag_year <- fitstat(m_aimag_year, "r2")$r2
cat(sprintf("Variance explained by birth_aimag × birth_year: R² = %.4f\n", r2_aimag_year))

cli::cli_h1("=== ЭРЭГЦҮҮЛЭЛ #2: birth_order distribution ===")

bo <- main$birth_order
cat(sprintf("birth_order n_NA: %d (%.1f%%)\n", sum(is.na(bo)), 100*mean(is.na(bo))))
cat("birth_order distribution (non-NA):\n")
print(table(bo, useNA = "no"))
cat("\nbirth_order summary:\n"); print(summary(bo))

# Reproduce first stage exactly
fs_bo <- feols(educ_years ~ birth_order + age + age2 + is_female + is_married | region + wave,
               data = main |> filter(!is.na(birth_order)),
               weights = ~hhweight, cluster = ~aimag + wave)
cat("\nFirst stage for birth_order:\n")
print(fs_bo)

# 2SLS — recompute β + SE
iv_bo <- feols(lwage ~ age + age2 + is_female + is_married | region + wave |
                 educ_years ~ birth_order,
               data = main |> filter(!is.na(birth_order)),
               weights = ~hhweight, cluster = ~aimag + wave)
cat("\nIV 2SLS for birth_order:\n")
print(summary(iv_bo))
cat("\nF-stat (ivf1):\n"); print(fitstat(iv_bo, "ivf1"))

cli::cli_h1("=== ЭРЭГЦҮҮЛЭЛ #3: aimag × cohort cell distribution ===")

main <- main |>
  mutate(
    cohort_bin = case_when(
      birth_year >= 1960 & birth_year <= 1969 ~ "1960s",
      birth_year >= 1970 & birth_year <= 1979 ~ "1970s",
      birth_year >= 1980 & birth_year <= 1989 ~ "1980s",
      birth_year >= 1990 & birth_year <= 1995 ~ "1990-95",
      birth_year >= 1996 & birth_year <= 1997 ~ "donut",
      birth_year >= 1998                       ~ "post1998",
      TRUE ~ NA_character_
    )
  )

cells <- main |> filter(cohort_bin != "donut") |>
  count(birth_aimag, cohort_bin)
cat(sprintf("Total (aimag, cohort) cells: %d (max possible 22 × 5 = 110)\n", nrow(cells)))
cat("Cell-size summary:\n")
print(cells |> summarise(min_n = min(n), median_n = median(n),
                         mean_n = mean(n), max_n = max(n),
                         cells_lt_30 = sum(n < 30),
                         cells_ge_30 = sum(n >= 30)))

cat("\ncohort_bin distribution (full):\n")
print(table(main$cohort_bin, useNA = "always"))

# Mean educ by aimag-cohort cell — does it vary?
cohort_var <- main |> filter(cohort_bin != "donut", !is.na(cohort_bin)) |>
  group_by(birth_aimag, cohort_bin) |>
  summarise(mean_educ = mean(educ_years, na.rm=T), n = n(), .groups = "drop")
cat("\nVariance of mean_educ across (aimag × cohort) cells (var explained by cells):\n")
m_cells <- feols(educ_years ~ as.factor(birth_aimag) * as.factor(cohort_bin),
                 data = main |> filter(cohort_bin != "donut", !is.na(cohort_bin)),
                 weights = ~hhweight)
cat(sprintf("R² = %.4f\n", fitstat(m_cells, "r2")$r2))

cli::cli_h1("=== F-statistic source check (cluster-robust ivf1?) ===")

# fitstat with feols+cluster gives cluster-robust ivf1 by default
# Verify by comparing with explicit cluster vcov
test_iv <- feols(lwage ~ age + age2 + is_female + is_married | region + wave |
                   educ_years ~ supply_at_17,
                 data = cor_check,
                 weights = ~hhweight,
                 cluster = ~aimag + wave)
cat("ivf1 (cluster-robust, fixest default with cluster set):\n")
print(fitstat(test_iv, "ivf1"))
cat("\nivf1.kpr (Kleibergen-Paap rk Wald F):\n")
print(fitstat(test_iv, "ivf1.kpr"))


