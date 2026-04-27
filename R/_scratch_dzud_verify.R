# =============================================================================
# DZUD IV VERIFICATION — data, logic, F estimation
# =============================================================================
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(stringr); library(tibble)
  library(fixest); library(here)
})
setFixest_estimation(panel.id = NULL)
options(width = 130)

panel    <- readRDS(here("data", "aux", "dzud_panel.rds")) |> as_tibble()
exposure <- readRDS(here("data", "aux", "dzud_exposure.rds")) |> as_tibble()
df       <- readRDS(here("data", "processed", "analysis_sample.rds")) |> as_tibble()

cat("================================================================\n")
cat("VERIFY 1: Data quality — well-known dzud years (1999-2002, 2009-2010)\n")
cat("================================================================\n\n")

# Aimag-level loss_rate for known dzud years
known_dzud_years <- c(1999, 2000, 2001, 2002, 2009, 2010)
known <- panel |>
  filter(year %in% known_dzud_years) |>
  arrange(year, desc(loss_rate)) |>
  select(year, hses_code, loss, livestock_lag, loss_rate)
cat("Loss rates for famous dzud years:\n")
print(known, n = 50)

cat("\n--- Mean loss_rate by year (top 20 years) ---\n")
yearly <- panel |>
  group_by(year) |>
  summarise(mean_lr = mean(loss_rate, na.rm = TRUE),
            max_lr = max(loss_rate, na.rm = TRUE),
            n_above_5 = sum(loss_rate >= 0.05, na.rm = TRUE),
            .groups = "drop") |>
  arrange(desc(mean_lr))
print(yearly, n = 20)

cat("\n================================================================\n")
cat("VERIFY 2: Aimag-level aggregation correctness\n")
cat("================================================================\n\n")
cat(sprintf("Loss panel: %d cells (22 aimags × 55 years = expected 1210)\n", nrow(panel)))
cat(sprintf("Aimags: %d, Years: %d-%d\n",
            length(unique(panel$hses_code)), min(panel$year), max(panel$year)))
cat("\nLivestock count by aimag for 2000 (sanity check):\n")
print(panel |> filter(year == 2000) |> arrange(desc(livestock)) |> select(hses_code, livestock, loss, loss_rate))

cat("\n================================================================\n")
cat("VERIFY 3: F-stat WITHOUT region FE (test if FE killing variation)\n")
cat("================================================================\n\n")

main <- df |>
  filter(main_flag_25_60 == 1L,
         !is.na(q_school_access), is.finite(q_school_access),
         !is.na(birth_year), !is.na(educ_years), !is.na(lwage),
         !is.na(birth_aimag), !is.na(hhweight)) |>
  left_join(exposure, by = c("birth_aimag", "birth_year")) |>
  filter(n_obs_6_17 >= 6)

# Spec A: dzud_top10 with ALL possible FE configurations
cat("Spec: educ_years ~ dzud_top10_6_17 + controls\n\n")

cat("--- A1: NO FE, NO cluster ---\n")
m1 <- feols(educ_years ~ dzud_top10_6_17 + age + age2 + is_female + is_married,
            data = main, weights = ~hhweight)
print(coeftable(m1)["dzud_top10_6_17", , drop = FALSE])

cat("\n--- A2: Wave FE only ---\n")
m2 <- feols(educ_years ~ dzud_top10_6_17 + age + age2 + is_female + is_married | wave,
            data = main, weights = ~hhweight, cluster = ~aimag + wave)
cat(sprintf("F = %.3f, p = %.4f\n",
            coeftable(m2)["dzud_top10_6_17","t value"]^2,
            coeftable(m2)["dzud_top10_6_17","Pr(>|t|)"]))
print(coeftable(m2)["dzud_top10_6_17", , drop = FALSE])

cat("\n--- A3: Region + wave FE (current spec) ---\n")
m3 <- feols(educ_years ~ dzud_top10_6_17 + age + age2 + is_female + is_married | region + wave,
            data = main, weights = ~hhweight, cluster = ~aimag + wave)
cat(sprintf("F = %.3f, p = %.4f\n",
            coeftable(m3)["dzud_top10_6_17","t value"]^2,
            coeftable(m3)["dzud_top10_6_17","Pr(>|t|)"]))
print(coeftable(m3)["dzud_top10_6_17", , drop = FALSE])

cat("\n--- A4: birth_aimag + wave FE (within-aimag identification) ---\n")
m4 <- feols(educ_years ~ dzud_top10_6_17 + age + age2 + is_female + is_married | birth_aimag + wave,
            data = main, weights = ~hhweight, cluster = ~aimag + wave)
cat(sprintf("F = %.3f, p = %.4f\n",
            coeftable(m4)["dzud_top10_6_17","t value"]^2,
            coeftable(m4)["dzud_top10_6_17","Pr(>|t|)"]))
print(coeftable(m4)["dzud_top10_6_17", , drop = FALSE])

cat("\n--- A5: birth_year + birth_aimag FE (cohort-aimag DiD) ---\n")
m5 <- feols(educ_years ~ dzud_top10_6_17 + is_female | birth_aimag + birth_year + wave,
            data = main, weights = ~hhweight, cluster = ~aimag + wave)
cat(sprintf("F = %.3f, p = %.4f\n",
            coeftable(m5)["dzud_top10_6_17","t value"]^2,
            coeftable(m5)["dzud_top10_6_17","Pr(>|t|)"]))
print(coeftable(m5)["dzud_top10_6_17", , drop = FALSE])

cat("\n================================================================\n")
cat("VERIFY 4: Rural birth — check if individual-level rural exists\n")
cat("================================================================\n\n")
cat("Variables in main containing 'urban' or 'rural':\n")
print(grep("urban|rural|locat", names(main), value = TRUE, ignore.case = TRUE))
if ("location" %in% names(main)) {
  cat("\nlocation distribution:\n"); print(table(main$location, useNA="ifany"))
}
if ("urban" %in% names(main)) {
  cat("\nurban distribution:\n"); print(table(main$urban, useNA="ifany"))
}

cat("\n================================================================\n")
cat("VERIFY 5: Birth-soum availability (potential improvement)\n")
cat("================================================================\n\n")
cat("Variables containing 'birth':\n")
print(grep("birth", names(df), value = TRUE, ignore.case = TRUE))
if ("birth_soum" %in% names(df)) {
  cat(sprintf("\nbirth_soum non-NA: %d/%d (%.1f%%)\n",
              sum(!is.na(df$birth_soum)), nrow(df), 100*mean(!is.na(df$birth_soum))))
  cat(sprintf("Unique birth_soum values: %d\n", length(unique(na.omit(df$birth_soum)))))
}

cat("\n================================================================\n")
cat("VERIFY 6: Compare to mother_educ F (sanity benchmark)\n")
cat("================================================================\n\n")
fam <- readRDS(here("data", "processed", "family_structure.rds")) |> as_tibble()
main_me <- df |>
  filter(main_flag_25_60 == 1L,
         !is.na(q_school_access), is.finite(q_school_access),
         !is.na(birth_year), !is.na(educ_years), !is.na(lwage),
         !is.na(birth_aimag), !is.na(hhweight)) |>
  left_join(fam |> select(id, mother_educ_level), by = "id") |>
  filter(!is.na(mother_educ_level))

cat(sprintf("mother_educ_level sample N: %d\n", nrow(main_me)))
m_me <- feols(educ_years ~ mother_educ_level + age + age2 + is_female + is_married | region + wave,
              data = main_me, weights = ~hhweight, cluster = ~aimag + wave)
cat("First stage (mother_educ benchmark):\n")
print(coeftable(m_me)["mother_educ_level", , drop = FALSE])
cat(sprintf("F = %.2f\n", coeftable(m_me)["mother_educ_level","t value"]^2))

cat("\n================================================================\n")
cat("ALL VERIFY COMPLETE\n")
cat("================================================================\n")
