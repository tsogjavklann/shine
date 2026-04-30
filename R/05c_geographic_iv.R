# =============================================================================
# 05c_geographic_iv.R
# -----------------------------------------------------------------------------
# Зорилго : Aimag-center coordinate hand-code → Haversine distance to UB →
#           candidate IV `distance_to_ub` (Card 1995-аар).
#           CHECKPOINT 2.5: First-stage F test home_aimag MAIN sample-д.
#           Шалгуур:
#             F ≥ 10:  IVTR full implementation (geographic IV)
#             5 ≤ F < 10: AR-robust CI хэлбэрээр caveat-тай үргэлжилнэ
#             F < 5:    PIVOT (Option A) руу буцна
# Орц     : data/processed/analysis_sample.rds
# Гарц    : data/auxiliary/aimag_distance_to_ub.csv
#           output/tables/T_2_5_distance_iv_first_stage.csv
#           output/logs/05c_distance_iv.log
# =============================================================================

source(here::here("R", "paths.R"))
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr)
  library(fixest); library(cli); library(tictoc)
})
setFixest_estimation(panel.id = NULL)
set.seed(2026)

cli::cli_h1("05c_geographic_iv.R — Card 1995 distance-to-UB IV")
tic("Total")

# ---- 1. Aimag-center coordinates (HSES newaimag codes) ----------------------
# Source: Wikipedia administrative center coords; UB ≈ Sukhbaatar Square
aimag_coords <- tibble::tribble(
  ~aimag,  ~aimag_name,         ~lat,     ~lon,
  11L,     "Улаанбаатар",         47.918,  106.917,
  21L,     "Дорнод/Чойбалсан",    48.072,  114.522,
  22L,     "Сүхбаатар/Баруун-Урт", 46.683,  113.283,
  23L,     "Хэнтий/Чингис",       47.317,  110.650,
  41L,     "Төв/Зуунмод",         47.706,  106.952,
  42L,     "Говьсүмбэр/Чойр",     46.358,  108.357,
  43L,     "Сэлэнгэ/Сүхбаатар",    50.236,  106.214,
  44L,     "Дорноговь/Сайншанд",  44.892,  110.117,
  45L,     "Дархан-Уул/Дархан",   49.486,  105.928,
  46L,     "Өмнөговь/Даланзадгад", 43.575,  104.425,
  48L,     "Дундговь/Мандалгов",  45.762,  106.283,
  61L,     "Орхон/Эрдэнэт",       49.034,  104.083,
  62L,     "Өвөрхангай/Арвайхээр", 46.265,  102.785,
  63L,     "Булган/Булган",       48.812,  103.530,
  64L,     "Баянхонгор/Баянхонгор", 46.193, 100.717,
  65L,     "Архангай/Цэцэрлэг",   47.475,  101.453,
  67L,     "Хөвсгөл/Мөрөн",       49.633,  100.158,
  81L,     "Завхан/Улиастай",     47.749,  96.842,
  82L,     "Говь-Алтай/Алтай",    46.367,  96.265,
  83L,     "Баян-Өлгий/Өлгий",    48.964,  89.969,
  84L,     "Ховд/Ховд",           48.005,  91.640,
  85L,     "Увс/Улаангом",        49.981,  92.062
)

# UB reference point
UB_LAT <- 47.918
UB_LON <- 106.917

# ---- 2. Haversine distance (km) ---------------------------------------------
haversine_km <- function(lat1, lon1, lat2 = UB_LAT, lon2 = UB_LON) {
  R <- 6371.0  # Earth radius km
  to_rad <- function(x) x * pi / 180
  lat1r <- to_rad(lat1); lat2r <- to_rad(lat2)
  dlat  <- to_rad(lat2 - lat1)
  dlon  <- to_rad(lon2 - lon1)
  a <- sin(dlat/2)^2 + cos(lat1r) * cos(lat2r) * sin(dlon/2)^2
  c <- 2 * atan2(sqrt(a), sqrt(1 - a))
  R * c
}

aimag_coords <- aimag_coords |>
  mutate(
    distance_to_ub = haversine_km(lat, lon),
    log_distance_to_ub = log(pmax(distance_to_ub, 1))
  )

cli::cli_h2("Aimag distance to UB (km)")
print(aimag_coords |> arrange(distance_to_ub) |>
        select(aimag, aimag_name, distance_to_ub) |>
        mutate(distance_to_ub = round(distance_to_ub, 1)),
      n = Inf)

write_csv(aimag_coords, file.path(PATHS$data_aux, "aimag_distance_to_ub.csv"))

# ---- 3. Merge to analysis_sample, restrict to MAIN home_aimag --------------
df <- readRDS(file.path(PATHS$data_proc, "analysis_sample.rds")) |> as_tibble()

# birth_aimag = home_aimag (q0114a/q0118a derived in R/03)
home <- df |>
  filter(main_flag_25_60 == 1L,
         !is.na(birth_aimag),
         !is.na(q_school_access), is.finite(q_school_access),
         !is.na(educ_years), !is.na(lwage),
         !is.na(age), !is.na(is_female), !is.na(is_married),
         !is.na(region), !is.na(wave), !is.na(aimag), !is.na(hhweight)) |>
  left_join(aimag_coords |> select(aimag, distance_to_ub, log_distance_to_ub),
            by = c("birth_aimag" = "aimag"))

n_with_dist <- sum(!is.na(home$distance_to_ub))
n_total     <- nrow(home)
cli::cli_alert_info("MAIN home_aimag: {n_total} rows; distance_to_ub valid: {n_with_dist}")

if (n_with_dist < n_total) {
  miss_aimags <- home |>
    filter(is.na(distance_to_ub)) |>
    count(birth_aimag) |>
    arrange(desc(n))
  cli::cli_alert_warning("Missing distance for some birth_aimag codes:")
  print(miss_aimags)
}

# Restrict to rows with distance
home <- home |> filter(!is.na(distance_to_ub))

# ---- 4. First-stage F tests (3 specifications) -----------------------------
CTRLS <- "age + age2 + is_female + is_married"

run_fs <- function(formula_str, data, label) {
  f <- as.formula(formula_str)
  m <- feols(f, data = data, weights = ~hhweight, cluster = ~aimag + wave)
  coefs <- coef(m)
  ses   <- se(m, cluster = ~aimag + wave)
  tval  <- coefs["distance_to_ub"] / ses["distance_to_ub"]
  pval  <- 2 * (1 - pnorm(abs(tval)))
  F_dist <- tval^2  # Wald F for single coefficient
  tibble(
    spec    = label,
    N       = nobs(m),
    pi_dist = unname(coefs["distance_to_ub"]),
    se_2way = unname(ses["distance_to_ub"]),
    t_stat  = unname(tval),
    p_value = unname(pval),
    F_dist  = unname(F_dist),
    R2_adj  = fitstat(m, "ar2")$ar2
  )
}

run_fs_log <- function(formula_str, data, label) {
  f <- as.formula(formula_str)
  m <- feols(f, data = data, weights = ~hhweight, cluster = ~aimag + wave)
  coefs <- coef(m)
  ses   <- se(m, cluster = ~aimag + wave)
  tval  <- coefs["log_distance_to_ub"] / ses["log_distance_to_ub"]
  pval  <- 2 * (1 - pnorm(abs(tval)))
  F_log_dist <- tval^2
  tibble(
    spec    = label,
    N       = nobs(m),
    pi_log_dist = unname(coefs["log_distance_to_ub"]),
    se_2way = unname(ses["log_distance_to_ub"]),
    t_stat  = unname(tval),
    p_value = unname(pval),
    F_log_dist = unname(F_log_dist),
    R2_adj  = fitstat(m, "ar2")$ar2
  )
}

cli::cli_alert("First stage 1: distance only, no FE...")
fs1 <- run_fs(
  paste("educ_years ~ distance_to_ub +", CTRLS, "| wave"),
  home, "1) distance only, wave FE"
)

cli::cli_alert("First stage 2: distance + region FE + wave FE...")
fs2 <- run_fs(
  paste("educ_years ~ distance_to_ub +", CTRLS, "| region + wave"),
  home, "2) distance + region FE + wave FE"
)

cli::cli_alert("First stage 3: distance + region + location + wave FE...")
fs3 <- run_fs(
  paste("educ_years ~ distance_to_ub +", CTRLS, "| region + location_f + wave"),
  home, "3) + location FE (Main B-style)"
)

T_2_5 <- bind_rows(fs1, fs2, fs3) |>
  mutate(across(c(pi_dist, se_2way, t_stat, p_value, F_dist, R2_adj), ~ round(.x, 5)))

cli::cli_h2("CHECKPOINT 2.5 — First-stage F (distance_to_ub)")
print(T_2_5)

cli::cli_alert("Log-distance first stage 1: log distance only, wave FE...")
fs1_log <- run_fs_log(
  paste("educ_years ~ log_distance_to_ub +", CTRLS, "| wave"),
  home, "1) log distance only, wave FE"
)

cli::cli_alert("Log-distance first stage 2: log distance + region FE + wave FE...")
fs2_log <- run_fs_log(
  paste("educ_years ~ log_distance_to_ub +", CTRLS, "| region + wave"),
  home, "2) log distance + region FE + wave FE"
)

cli::cli_alert("Log-distance first stage 3: log distance + region + location + wave FE...")
fs3_log <- run_fs_log(
  paste("educ_years ~ log_distance_to_ub +", CTRLS, "| region + location_f + wave"),
  home, "3) log distance + location FE"
)

T_2_5_log <- bind_rows(fs1_log, fs2_log, fs3_log) |>
  mutate(across(c(pi_log_dist, se_2way, t_stat, p_value, F_log_dist, R2_adj), ~ round(.x, 5)))

cli::cli_h2("CHECKPOINT 2.5b - First-stage F (log_distance_to_ub)")
print(T_2_5_log)

# Sign + strength interpretation
F_main <- fs2$F_dist  # use Spec 2 (Main A-style with region FE) as canonical
F_main_log <- fs2_log$F_log_dist
strength <- case_when(
  is.na(F_main) ~ "F NA",
  F_main >= 10  ~ "🎉 STRONG (F ≥ 10) → IVTR full implementation OK",
  F_main >= 5   ~ "⚠️ WEAK (F ∈ [5, 10)) → AR-robust CI caveat",
  TRUE          ~ "🔴 VERY WEAK (F < 5) → PIVOT to Option A"
)
sign_dir <- if (!is.na(fs2$pi_dist) && fs2$pi_dist < 0) {
  "Card-style sign (хол → бага сурах) ✓"
} else {
  "Wrong sign (хол → их сурах) — concerning"
}

strength_log <- case_when(
  is.na(F_main_log) ~ "F NA",
  F_main_log >= 10  ~ "STRONG (F >= 10) -> log-distance IV first stage OK",
  F_main_log >= 5   ~ "WEAK (F in [5, 10)) -> AR-robust CI caveat",
  TRUE              ~ "VERY WEAK (F < 5) -> diagnostic only"
)
sign_dir_log <- if (!is.na(fs2_log$pi_log_dist) && fs2_log$pi_log_dist < 0) {
  "Card-style sign (farther -> less schooling)"
} else {
  "Wrong sign (farther -> more schooling) -- concerning"
}

cli::cli_alert_info("Spec 2 (canonical) F = {round(F_main, 2)}: {strength}")
cli::cli_alert_info("Spec 2 log-distance F = {round(F_main_log, 2)}: {strength_log}")
cli::cli_alert_info("pi_log_distance = {round(fs2_log$pi_log_dist, 5)} ({sign_dir_log})")
cli::cli_alert_info("π̂_distance = {round(fs2$pi_dist, 5)} ({sign_dir})")

# ---- 5. Coverage by aimag in home subsample --------------------------------
aimag_dist_panel <- home |>
  group_by(birth_aimag, distance_to_ub) |>
  summarise(n_panel = n(), mean_educ = mean(educ_years, na.rm = TRUE),
            .groups = "drop") |>
  arrange(distance_to_ub)
cli::cli_h2("Birth-aimag panel sizes + mean educ_years (sorted by distance)")
print(aimag_dist_panel, n = Inf)

# ---- 6. Хадгалах + лог ------------------------------------------------------
write_csv(T_2_5, file.path(PATHS$out_tables, "T_2_5_distance_iv_first_stage.csv"))
write_csv(T_2_5_log, file.path(PATHS$out_tables, "T_2_5_log_distance_iv_first_stage.csv"))
write_csv(aimag_dist_panel, file.path(PATHS$out_logs, "05c_aimag_panel_sizes.csv"))

log_path <- file.path(PATHS$out_logs, "05c_distance_iv.log")
sink(log_path, append = FALSE)
cat("==========================================================\n")
cat("05c_geographic_iv.R лог  ", as.character(Sys.time()), "\n")
cat("==========================================================\n")
cat(sprintf("MAIN home_aimag sample (with distance): %d rows\n", n_total))
cat("\nAimag distances to UB (km):\n"); print(aimag_coords |> arrange(distance_to_ub), n = Inf)
cat("\nFirst-stage results:\n"); print(T_2_5)
cat("\nLog-distance first-stage results:\n"); print(T_2_5_log)
cat(sprintf("\nCanonical F (Spec 2): %.3f → %s\n", F_main, strength))
cat(sprintf("π̂_distance = %.5f → %s\n", fs2$pi_dist, sign_dir))
cat("\nBirth-aimag panel sizes (home_aimag MAIN, sorted by distance):\n")
print(aimag_dist_panel, n = Inf)
sink()

toc()
cli::cli_alert_success("Гарц: T_2_5_distance_iv_first_stage.csv + 05c_distance_iv.log")


