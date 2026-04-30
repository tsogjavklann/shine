# =============================================================================
# 06_iv_construction.R
# -----------------------------------------------------------------------------
# Зорилго : 4 IV variant үүсгэх (reform exposure birth-year cutoff design):
#             reform_main      — donut: ≤1995=0, 1996-97=NA, ≥1998=1
#             reform_fuzzy     — 0/0.5/1 partial
#             reform_alt_1997  — ≤1994=0, 1995-96=NA, ≥1997=1
#             reform_alt_1999  — ≤1996=0, 1997-98=NA, ≥1999=1
#           exposure_intensity — 8-р анги хэдэн жилд хүрсэн (бус gradient)
# Орц     : data/processed/wage_real.rds (has birth_year, id, wave)
# Гарц    : data/processed/iv_assignment.rds (id × IV columns)
# =============================================================================

source(here::here("R", "paths.R"))
suppressPackageStartupMessages({
  library(dplyr); library(readr); library(tidyr); library(cli); library(tictoc)
})

cli::cli_h1("06_iv_construction.R — 4 IV variants")
tic("Total")

# ---- 1. Орц -----------------------------------------------------------------
in_path <- file.path(PATHS$data_proc, "wage_real.rds")
if (!file.exists(in_path)) {
  cli::cli_abort("Орц олдсонгүй: {in_path}. Эхлээд R/04b-г ажиллуул.")
}
wage <- readRDS(in_path) |> as_tibble()
cli::cli_alert_info("Wage panel: {nrow(wage)} мөр")

# ---- 2. 4 IV хувилбар үүсгэх ------------------------------------------------
iv <- wage |>
  select(id, wave, birth_year) |>
  mutate(
    reform_main = case_when(
      is.na(birth_year)         ~ NA_integer_,
      birth_year <= 1995L       ~ 0L,
      birth_year %in% 1996:1997 ~ NA_integer_,
      birth_year >= 1998L       ~ 1L,
      TRUE                      ~ NA_integer_
    ),
    reform_fuzzy = case_when(
      is.na(birth_year)         ~ NA_real_,
      birth_year <= 1995L       ~ 0,
      birth_year %in% 1996:1997 ~ 0.5,
      birth_year >= 1998L       ~ 1,
      TRUE                      ~ NA_real_
    ),
    reform_alt_1997 = case_when(
      is.na(birth_year)         ~ NA_integer_,
      birth_year <= 1994L       ~ 0L,
      birth_year %in% 1995:1996 ~ NA_integer_,
      birth_year >= 1997L       ~ 1L,
      TRUE                      ~ NA_integer_
    ),
    reform_alt_1999 = case_when(
      is.na(birth_year)         ~ NA_integer_,
      birth_year <= 1996L       ~ 0L,
      birth_year %in% 1997:1998 ~ NA_integer_,
      birth_year >= 1999L       ~ 1L,
      TRUE                      ~ NA_integer_
    ),
    # exposure_intensity: цифр (хичнээн жилийн 11-жилийн систем дамжсан)
    # 1998+ онд төрсөн нь бүх 11 жилийг шинэ системд → intensity = 1
    # 1997 онд бол ~0.91 (10/11), 1996 ≈ 0.82 (9/11), ...
    # Энэ нь simplified linear; жинхэнэ exposure-ийг 06b-д өргөтгөж болно
    exposure_intensity = pmin(pmax((birth_year - 1987L) / 11.0, 0), 1)
  )

# ---- 3. Diagnostics ---------------------------------------------------------
distrib <- function(x, label) {
  if (is.numeric(x) && all(x %in% c(0, 0.5, 1, NA), na.rm = TRUE)) {
    tab <- table(x, useNA = "always")
    out <- tibble(label = label, value = names(tab), n = as.integer(tab))
    out
  } else {
    tibble(label = label, value = "summary",
           n = NA_integer_,
           mean = mean(x, na.rm = TRUE),
           sd   = sd(x, na.rm = TRUE))
  }
}

iv_summary <- bind_rows(
  distrib(iv$reform_main,     "reform_main"),
  distrib(iv$reform_fuzzy,    "reform_fuzzy"),
  distrib(iv$reform_alt_1997, "reform_alt_1997"),
  distrib(iv$reform_alt_1999, "reform_alt_1999")
)
cli::cli_h2("4 IV variants — distribution (full panel)")
print(iv_summary)

# Wave-аар (treated cohort wave-аар хэрхэн тархсан)
wave_dist <- iv |>
  group_by(wave) |>
  summarise(
    n_total          = n(),
    main_treated     = sum(reform_main == 1L, na.rm = TRUE),
    main_control     = sum(reform_main == 0L, na.rm = TRUE),
    main_donut_NA    = sum(is.na(reform_main)),
    alt1997_treated  = sum(reform_alt_1997 == 1L, na.rm = TRUE),
    alt1999_treated  = sum(reform_alt_1999 == 1L, na.rm = TRUE),
    .groups = "drop"
  )
cli::cli_h2("Wave × IV breakdown")
print(wave_dist)

# ---- 4. Хадгалах + лог ------------------------------------------------------
out_path <- file.path(PATHS$data_proc, "iv_assignment.rds")
saveRDS(iv, out_path)
write_csv(iv_summary, file.path(PATHS$out_logs, "06_iv_summary.csv"))
write_csv(wave_dist,  file.path(PATHS$out_logs, "06_iv_wave_dist.csv"))

log_path <- file.path(PATHS$out_logs, "06_iv_construction.log")
sink(log_path, append = FALSE)
cat("==========================================================\n")
cat("06_iv_construction.R лог  ", as.character(Sys.time()), "\n")
cat("==========================================================\n")
cat(sprintf("Wage panel: %d rows\n", nrow(wage)))
cat("\n4 IV variants distribution:\n"); print(iv_summary)
cat("\nWave × IV breakdown:\n"); print(wave_dist)
sink()

toc()
cli::cli_alert_success("Гарц: {out_path}")
cli::cli_alert_info("Дараагийн алхам: R/07_merge_final.R")
