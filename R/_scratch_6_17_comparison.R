# 6-17 window: V1 (region+wave) vs V2 (birth_aimag+cohort+wave) бүх IV-аар харьцуулна
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(here); library(fixest); library(tibble)
})
setFixest_estimation(panel.id = NULL)
options(width = 130)

panel <- readRDS(here("data/auxiliary/dzud_panel.rds")) |>
  group_by(year) |>
  mutate(severe_p75 = as.integer(loss_rate >= quantile(loss_rate, 0.75, na.rm = TRUE))) |>
  ungroup()

# Build 6-17 exposure
exp_6_17 <- expand_grid(birth_aimag = sort(unique(panel$hses_code)),
                        birth_year  = 1955:2010) |>
  rowwise() |>
  mutate(
    cum    = sum(panel$loss_rate[panel$hses_code == birth_aimag &
                                 panel$year %in% (birth_year + 6):(birth_year + 17)],
                 na.rm = TRUE),
    log_cum = log1p(cum),
    maxv   = suppressWarnings(max(panel$loss_rate[panel$hses_code == birth_aimag &
                                                  panel$year %in% (birth_year + 6):(birth_year + 17)],
                                  na.rm = TRUE)),
    cnt5   = sum(panel$dzud_5pct[panel$hses_code == birth_aimag &
                                 panel$year %in% (birth_year + 6):(birth_year + 17)],
                 na.rm = TRUE),
    cnt10  = sum(panel$dzud_10pct[panel$hses_code == birth_aimag &
                                  panel$year %in% (birth_year + 6):(birth_year + 17)],
                 na.rm = TRUE),
    cntp75 = sum(panel$severe_p75[panel$hses_code == birth_aimag &
                                  panel$year %in% (birth_year + 6):(birth_year + 17)],
                 na.rm = TRUE),
    intensity = if_else(cnt5 > 0, cnt5 / 12, 0),
    n_obs  = sum(!is.na(panel$loss_rate[panel$hses_code == birth_aimag &
                                        panel$year %in% (birth_year + 6):(birth_year + 17)]))
  ) |>
  ungroup() |>
  mutate(maxv = ifelse(is.finite(maxv), maxv, NA_real_))

df <- readRDS(here("data/processed/analysis_sample.rds")) |> as_tibble()
main_partial <- df |>
  filter(main_flag_25_60 == 1L,
         !is.na(q_school_access), is.finite(q_school_access),
         !is.na(birth_year), !is.na(educ_years), !is.na(lwage),
         !is.na(birth_aimag), !is.na(hhweight)) |>
  left_join(exp_6_17, by = c("birth_aimag", "birth_year")) |>
  mutate(birth_cohort = case_when(
    birth_year < 1970 ~ "pre1970",
    birth_year < 1975 ~ "1970-74",
    birth_year < 1980 ~ "1975-79",
    birth_year < 1985 ~ "1980-84",
    birth_year < 1990 ~ "1985-89",
    birth_year < 1995 ~ "1990-94",
    TRUE              ~ "post1995"))

main_full <- main_partial |> filter(n_obs == 12)

cat(sprintf("V1 (partial coverage): N = %d\n", nrow(main_partial)))
cat(sprintf("V2 (full coverage):    N = %d\n\n", nrow(main_full)))

run_fs <- function(data, iv_var, fe_string) {
  fml <- as.formula(sprintf("educ_years ~ %s + age + age2 + is_female + is_married | %s",
                            iv_var, fe_string))
  m <- tryCatch(feols(fml, data = data, weights = ~hhweight, cluster = ~aimag + wave),
                error = function(e) NULL)
  if (is.null(m)) return(c(NA, NA, NA))
  ct <- coeftable(m)
  if (!iv_var %in% rownames(ct)) return(c(NA, NA, NA))
  c(ct[iv_var,"Estimate"], ct[iv_var,"Std. Error"], ct[iv_var,"t value"]^2)
}

ivs <- c("cum","log_cum","maxv","cnt5","cnt10","cntp75","intensity")
labels <- c("cum_loss_rate","log_cum_loss","max_loss_rate","cnt5 (>=5% count)",
            "cnt10 (>=10% count)","cntp75 (year-p75 count)","intensity (cnt5/12)")

cat("=================================================================\n")
cat("6-17 WINDOW — V1 (region+wave) vs V2 (birth_aimag+cohort+wave)\n")
cat("=================================================================\n\n")
cat(sprintf("%-25s | %-22s | %-22s\n",
            "IV",
            "V1: region+wave (N=9077)",
            "V2: birth_aimag+cohort+wave (N=7145)"))
cat(sprintf("%-25s | %-22s | %-22s\n",
            "",
            "F          π̂        sign",
            "F          π̂        sign"))
cat(strrep("-", 80), "\n")

for (i in seq_along(ivs)) {
  v1 <- run_fs(main_partial, ivs[i], "region + wave")
  v2 <- run_fs(main_full,    ivs[i], "birth_aimag + birth_cohort + wave")
  v1sign <- if (is.na(v1[1])) "" else if (v1[1] > 0) "+" else "-"
  v2sign <- if (is.na(v2[1])) "" else if (v2[1] > 0) "+" else "-"
  cat(sprintf("%-25s | F=%6.2f  π̂=%+.3f %s   | F=%6.2f  π̂=%+.3f %s\n",
              labels[i], v1[3], v1[1], v1sign, v2[3], v2[1], v2sign))
}

cat("\n=================================================================\n")
cat("ИНТЕРПРЕТАЦИ\n")
cat("=================================================================\n")
cat("V1: бараг бүгд STRONG (F>10) — between-aimag chronic ялгаанаас\n")
cat("V2: бүгд WEAK (F<5) — within-aimag shock variation null\n")
cat("Sign flip: V1 өс vs V2 нь эерэг → confounding-н тодорхой шинж\n")


