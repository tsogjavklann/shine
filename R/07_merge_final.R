# =============================================================================
# 07_merge_final.R
# -----------------------------------------------------------------------------
# Зорилго : Бүх боловсруулсан файлыг merge → analysis_sample.rds (нэг файл,
#           sample_flag баганатай: "main" = age 25-60, "alt" = age 22-60).
#           Currently_student filter (q0214/q0213) — HSES-д шууд боломжгүй
#           бол 22-24 насныхдад caveat log нэмнэ.
#
# Орц     : data/processed/wage_real.rds          (43,070 wage panel + lwage)
#           data/processed/school_access.rds      (id × q_home + q_new)
#           data/processed/iv_assignment.rds      (id × 4 IV)
#           data/processed/hses_harmonized.rds    (full panel — additional vars
#                                                   like educ_years, marital,
#                                                   region, hhweight, etc.)
#
# Гарц    : data/processed/analysis_sample.rds
# =============================================================================

source(here::here("R", "paths.R"))
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(cli); library(tictoc)
})

cli::cli_h1("07_merge_final.R — final analysis_sample")
tic("Total")

# ---- 1. Load all inputs -----------------------------------------------------
wage    <- readRDS(file.path(PATHS$data_proc, "wage_real.rds"))     |> as_tibble()
sa      <- readRDS(file.path(PATHS$data_proc, "school_access.rds")) |> as_tibble()
iv      <- readRDS(file.path(PATHS$data_proc, "iv_assignment.rds")) |> as_tibble()
harm    <- readRDS(file.path(PATHS$data_proc, "hses_harmonized.rds")) |> as_tibble()

cli::cli_alert_info("Inputs loaded — wage:{nrow(wage)}  sa:{nrow(sa)}  iv:{nrow(iv)}  harm:{nrow(harm)}")

# ---- 2. Pull additional control variables from harm ------------------------
# Wage panel-д аль хэдийн байгаа variables-ийг давхар нэмэхгүй
need_extra <- c("id", "educ_years", "marital", "relation_head", "region",
                "urban", "location", "hhsize", "hhweight", "newaimag_proxy")
extra <- harm |> select(any_of(need_extra)) |> distinct(id, .keep_all = TRUE)

# ---- 3. Merge ---------------------------------------------------------------
# Wage panel includes many columns already (id, wave, age, sex, etc.).
# Drop overlapping cols from `extra` except the join key id.
overlap_drop <- setdiff(intersect(names(wage), names(extra)), "id")
extra2 <- extra |> select(-all_of(overlap_drop))

analysis <- wage |>
  left_join(extra2, by = "id") |>
  left_join(sa |> select(id, q_home, n_years_home, q_new, n_years_new),
            by = "id") |>
  left_join(iv |> select(id, reform_main, reform_fuzzy, reform_alt_1997,
                         reform_alt_1999, exposure_intensity),
            by = "id")

cli::cli_alert_info("After merge: {nrow(analysis)} rows × {ncol(analysis)} cols")

# ---- 4. Currently-student filter -------------------------------------------
# HSES-ийн q0214 ("[НЭР] одоо сургуульд сурдаг уу?") байх бол 22-24 насны
# одоо суралцаж байгаа хүмүүсийг wage panel-д орж болохгүй.
# Бид q0214-ийг R/03 harmonize-д extract хийгээгүй (focus on labour module).
# Тиймээс: 22-24 насныхдад caveat log нэмнэ. Гэхдээ working_for_wage=1 filter
# нь R/04-д хэдийн ажилласан учир учрыг шалгасан student-ажиллагсадын
# overlap бага байх ёстой.
n_22_24 <- sum(analysis$age >= 22 & analysis$age <= 24, na.rm = TRUE)
cli::cli_alert_info(
  "22-24 насны wage-panel rows: {n_22_24} ({round(100*n_22_24/nrow(analysis),2)}%) — ",
  "currently_student filter-гүй; q0214 R/03-д extract хийгдээгүй (caveat)."
)

# ---- 5. sample_flag --------------------------------------------------------
analysis <- analysis |>
  mutate(
    age2 = age^2,
    main_flag_25_60 = as.integer(age >= 25 & age <= 60),
    sample_flag = if_else(main_flag_25_60 == 1L, "main", "alt"),
    # Demographic helpers
    is_female = as.integer(sex == 2L),
    is_married = as.integer(marital %in% 2:3),  # хууль ёсны эсвэл хамтран
    # Region/location factors (placeholder — пакет конкрет нэрнүүдтэй)
    region_f = as.factor(region),
    location_f = as.factor(location)
  )

# ---- 6. Final summary -------------------------------------------------------
N_main <- sum(analysis$main_flag_25_60 == 1L, na.rm = TRUE)
N_alt  <- nrow(analysis)
N_extra <- N_alt - N_main

cli::cli_h2("Final analysis_sample sizes")
cli::cli_alert_info("Total (alt_sample, 22-60):     {N_alt}")
cli::cli_alert_info("main_sample (25-60):           {N_main}")
cli::cli_alert_info("alt_sample-only (22-24 нэмэлт): {N_extra}")

iv_main_dist <- analysis |>
  filter(main_flag_25_60 == 1L) |>
  summarise(
    n               = n(),
    main_treated    = sum(reform_main == 1L, na.rm = TRUE),
    main_control    = sum(reform_main == 0L, na.rm = TRUE),
    main_donut_NA   = sum(is.na(reform_main)),
    alt1997_treated = sum(reform_alt_1997 == 1L, na.rm = TRUE),
    alt1999_treated = sum(reform_alt_1999 == 1L, na.rm = TRUE)
  )
cli::cli_h2("IV distribution in main_sample (25-60)")
print(iv_main_dist)

iv_alt_dist <- analysis |>
  summarise(
    n               = n(),
    main_treated    = sum(reform_main == 1L, na.rm = TRUE),
    main_control    = sum(reform_main == 0L, na.rm = TRUE),
    main_donut_NA   = sum(is.na(reform_main)),
    alt1997_treated = sum(reform_alt_1997 == 1L, na.rm = TRUE),
    alt1999_treated = sum(reform_alt_1999 == 1L, na.rm = TRUE)
  )
cli::cli_h2("IV distribution in alt_sample (22-60)")
print(iv_alt_dist)

q_coverage <- analysis |>
  summarise(
    n           = n(),
    n_q_home    = sum(!is.na(q_home) & is.finite(q_home)),
    n_q_new     = sum(!is.na(q_new)  & is.finite(q_new)),
    pct_q_home  = round(100 * n_q_home / n, 1),
    pct_q_new   = round(100 * n_q_new  / n, 1)
  )
cli::cli_h2("school_access coverage in analysis_sample")
print(q_coverage)

# ---- 7. Хадгалах + лог ------------------------------------------------------
out_path <- file.path(PATHS$data_proc, "analysis_sample.rds")
saveRDS(analysis, out_path)
write_csv(analysis |> select(id, wave, age, sample_flag, main_flag_25_60,
                             reform_main, reform_alt_1997, reform_alt_1999,
                             q_home, q_new, lwage, educ_years) |> head(20),
          file.path(PATHS$out_logs, "07_analysis_sample_head.csv"))

log_path <- file.path(PATHS$out_logs, "07_merge_final.log")
sink(log_path, append = FALSE)
cat("==========================================================\n")
cat("07_merge_final.R лог  ", as.character(Sys.time()), "\n")
cat("==========================================================\n")
cat(sprintf("Total alt_sample (22-60): %d\n", N_alt))
cat(sprintf("main_sample (25-60):      %d\n", N_main))
cat(sprintf("alt-only (22-24):         %d\n", N_extra))
cat(sprintf("\n22-24 насны wage panel rows: %d (currently_student filter-гүй)\n", n_22_24))
cat("\nIV distribution in main_sample (25-60):\n"); print(iv_main_dist)
cat("\nIV distribution in alt_sample (22-60):\n"); print(iv_alt_dist)
cat("\nschool_access coverage:\n"); print(q_coverage)
cat(sprintf("\nFinal columns (%d):\n  %s\n", ncol(analysis), paste(names(analysis), collapse = ", ")))
sink()

toc()
cli::cli_alert_success("Гарц: {out_path}  ({nrow(analysis)} rows × {ncol(analysis)} cols)")
cli::cli_alert_info("Долоо хоног 1 ДУУСЛАА. Checkpoint 1 — RESULTS_LOG.md-д бичнэ.")
