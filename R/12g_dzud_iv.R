# =============================================================================
# R/12g_dzud_iv.R — Dzud IV approach (Mongolia-specific extreme weather shock)
#
# Эх сурвалж: NSO 1212.mn гар татсан xlsx → R/02b_clean_nso_xlsx.R-аар цэвэрлэсэн
#   data/aux/dzud_panel.csv  (loss + livestock + loss_rate + dzud thresholds)
#
# (Originally fetched via PXWeb API — DT_NSO_1001_136V1 + 109V1; one-to-one match
#  verified by R/_scratch_verify_csv_source.R)
#
# Аргачлал: aimag-year хорогдлын хувь = loss / (lagged_count) > threshold => dzud
# Childhood exposure: dzud_count_6_17 = sum(dzud_severe[birth_aimag, birth_year+6 .. birth_year+17])
# =============================================================================
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(stringr); library(tibble)
  library(httr); library(jsonlite); library(fixest); library(cli); library(here)
})
setFixest_estimation(panel.id = NULL)
set.seed(2026)
options(width = 130)

# -----------------------------------------------------------------------------
# 0. Helpers (PXWeb)
# -----------------------------------------------------------------------------
fetch_pxweb <- function(table_url, body_str, retries = 3L) {
  body_raw <- charToRaw(enc2utf8(body_str))
  for (i in seq_len(retries)) {
    res <- tryCatch(
      POST(table_url,
           add_headers("Content-Type" = "application/json; charset=utf-8",
                       "Accept" = "application/json"),
           body = body_raw, timeout(120)),
      error = function(e) NULL)
    if (!is.null(res) && status_code(res) == 200L) {
      return(fromJSON(content(res, "text", encoding = "UTF-8"), simplifyVector = FALSE))
    }
  }
  stop(sprintf("PXWeb fetch failed for %s", table_url))
}

parse_jsonstat <- function(js) {
  dim_ids <- unlist(js$id)
  dim_info <- lapply(dim_ids, function(d) {
    cat <- js$dimension[[d]]$category
    idx <- unlist(cat$index); lab <- unlist(cat$label)
    ord <- order(idx)
    list(codes = names(idx)[ord], labels = lab[names(idx)[ord]])
  })
  names(dim_info) <- dim_ids
  grid_lst_rev <- rev(setNames(lapply(dim_info, function(di) di$codes), dim_ids))
  grid_df <- expand.grid(grid_lst_rev, stringsAsFactors = FALSE, KEEP.OUT.ATTRS = FALSE)
  grid_df <- grid_df[, rev(seq_along(grid_df)), drop = FALSE]
  names(grid_df) <- dim_ids
  vals <- unlist(js$value, use.names = FALSE)
  n <- min(nrow(grid_df), length(vals))
  grid_df <- grid_df[seq_len(n), , drop = FALSE]
  grid_df$value <- as.numeric(vals[seq_len(n)])
  # attach labels for ALL dimensions (e.g. Бүс → bus_label, Он → on_label)
  for (d in dim_ids) {
    grid_df[[paste0(d, "_label")]] <- dim_info[[d]]$labels[match(grid_df[[d]], dim_info[[d]]$codes)]
  }
  as_tibble(grid_df)
}

# Map NSO Бүс label → HSES hses_code
aimag_lookup <- read_csv(here("data", "aux", "aimag_lookup.csv"), show_col_types = FALSE)
match_aimag <- function(label_vec) {
  trimmed <- str_trim(label_vec)
  aimag_lookup$hses_code[match(trimmed, aimag_lookup$aimag_mn)]
}

# -----------------------------------------------------------------------------
# 1-3. LOAD pre-built dzud_panel from data/aux/ (R/02b_clean_nso_xlsx.R-аас)
# -----------------------------------------------------------------------------
cli_h1("STEP 1: dzud_panel.csv ачааллах (R/02b_clean_nso_xlsx.R-ийн гарц)")

panel <- readRDS(here("data", "aux", "dzud_panel.rds")) |> as_tibble()
cat(sprintf("dzud_panel: %d мөр × %d багана\n", nrow(panel), ncol(panel)))
cat(sprintf("Жилийн хүрээ: %d-%d, аймаг: %d\n",
            min(panel$year), max(panel$year), length(unique(panel$hses_code))))

cat("\nloss_rate quantiles:\n")
print(quantile(panel$loss_rate, c(0.5, 0.75, 0.9, 0.95, 0.99), na.rm = TRUE))

cat(sprintf("\nDzud-years counted (any aimag, any year):\n"))
cat(sprintf("  >=5%%  loss rate: %d aimag-years\n", sum(panel$dzud_5pct, na.rm = TRUE)))
cat(sprintf("  >=10%% loss rate: %d aimag-years\n", sum(panel$dzud_10pct, na.rm = TRUE)))
cat(sprintf("  Top 10%%: %d aimag-years\n", sum(panel$dzud_top10, na.rm = TRUE)))

worst <- panel |>
  group_by(year) |>
  summarise(n_aimags_dzud5 = sum(dzud_5pct, na.rm = TRUE),
            n_aimags_dzud10 = sum(dzud_10pct, na.rm = TRUE),
            mean_loss_rate = mean(loss_rate, na.rm = TRUE),
            .groups = "drop") |>
  arrange(desc(n_aimags_dzud5))
cat("\nTop 15 dzud-years:\n")
print(worst, n = 15)

# -----------------------------------------------------------------------------
# 4. CHILDHOOD EXPOSURE — dzud_count_6_17 by (birth_aimag, birth_year)
# -----------------------------------------------------------------------------
cli_h1("STEP 4: Childhood dzud exposure (age 6-17)")

# Cross-join all (birth_aimag, birth_year) cells × ages 6-17 → look up dzud
exposure <- expand_grid(
  birth_aimag = sort(unique(panel$hses_code)),
  birth_year  = 1955:2010
) |>
  rowwise() |>
  mutate(
    dzud5_6_17     = sum(panel$dzud_5pct[panel$hses_code == birth_aimag &
                                         panel$year %in% (birth_year + 6):(birth_year + 17)],
                         na.rm = TRUE),
    dzud10_6_17    = sum(panel$dzud_10pct[panel$hses_code == birth_aimag &
                                          panel$year %in% (birth_year + 6):(birth_year + 17)],
                         na.rm = TRUE),
    dzud_top10_6_17 = sum(panel$dzud_top10[panel$hses_code == birth_aimag &
                                           panel$year %in% (birth_year + 6):(birth_year + 17)],
                          na.rm = TRUE),
    cum_loss_rate_6_17 = sum(panel$loss_rate[panel$hses_code == birth_aimag &
                                             panel$year %in% (birth_year + 6):(birth_year + 17)],
                             na.rm = TRUE),
    max_loss_rate_6_17 = suppressWarnings(max(panel$loss_rate[panel$hses_code == birth_aimag &
                                                              panel$year %in% (birth_year + 6):(birth_year + 17)],
                                              na.rm = TRUE)),
    n_obs_6_17     = sum(!is.na(panel$loss_rate[panel$hses_code == birth_aimag &
                                                panel$year %in% (birth_year + 6):(birth_year + 17)]))
  ) |>
  ungroup() |>
  mutate(any_dzud5_6_17  = as.integer(dzud5_6_17  > 0),
         dzud5_intensity = ifelse(n_obs_6_17 > 0, dzud5_6_17 / n_obs_6_17, NA_real_),
         max_loss_rate_6_17 = ifelse(is.finite(max_loss_rate_6_17), max_loss_rate_6_17, NA_real_),
         log_cum_loss = log1p(cum_loss_rate_6_17))

cat(sprintf("Exposure cells (aimag × birth_year): %d\n", nrow(exposure)))
cat(sprintf("Cells with at least 6 obs in childhood window: %d\n", sum(exposure$n_obs_6_17 >= 6)))

saveRDS(exposure, here("data", "aux", "dzud_exposure.rds"))

# -----------------------------------------------------------------------------
# 5. MERGE TO HSES & first stage
# -----------------------------------------------------------------------------
cli_h1("STEP 5: First-stage F-statistic")

df <- readRDS(here("data", "processed", "analysis_sample.rds")) |> as_tibble()
main <- df |>
  filter(main_flag_25_60 == 1L,
         !is.na(q_school_access), is.finite(q_school_access),
         !is.na(birth_year), !is.na(educ_years), !is.na(lwage),
         !is.na(birth_aimag), !is.na(hhweight)) |>
  left_join(exposure, by = c("birth_aimag" = "birth_aimag", "birth_year" = "birth_year"))

cat(sprintf("Main sample N: %d\n", nrow(main)))
cat(sprintf("With dzud5_6_17 (n_obs>=6 in window): %d (%.1f%%)\n",
            sum(main$n_obs_6_17 >= 6, na.rm = TRUE),
            100*mean(main$n_obs_6_17 >= 6, na.rm = TRUE)))

iv_data <- main |> filter(n_obs_6_17 >= 6)

# First stage: dzud_count
fs1 <- feols(educ_years ~ dzud5_6_17 + age + age2 + is_female + is_married | region + wave,
             data = iv_data, weights = ~hhweight, cluster = ~aimag + wave)
cat("\n--- First stage: educ_years ~ dzud5_6_17 (count) ---\n")
print(coeftable(fs1)["dzud5_6_17", , drop = FALSE])

iv1 <- feols(lwage ~ age + age2 + is_female + is_married | region + wave |
               educ_years ~ dzud5_6_17,
             data = iv_data, weights = ~hhweight, cluster = ~aimag + wave)
cat("\nIV F-stat (cluster-robust):\n")
print(fitstat(iv1, "ivf1"))
cat("\n2SLS β (educ_years):\n")
print(coeftable(iv1)["fit_educ_years", , drop = FALSE])

# First stage: any_dzud (binary) — may be collinear if all observations have any_dzud=1
fs2 <- feols(educ_years ~ any_dzud5_6_17 + age + age2 + is_female + is_married | region + wave,
             data = iv_data, weights = ~hhweight, cluster = ~aimag + wave)
cat("\n--- First stage: educ_years ~ any_dzud5_6_17 (binary) ---\n")
if ("any_dzud5_6_17" %in% rownames(coeftable(fs2))) {
  print(coeftable(fs2)["any_dzud5_6_17", , drop = FALSE])
  iv2 <- feols(lwage ~ age + age2 + is_female + is_married | region + wave |
                 educ_years ~ any_dzud5_6_17,
               data = iv_data, weights = ~hhweight, cluster = ~aimag + wave)
  cat("IV F-stat:\n"); print(fitstat(iv2, "ivf1"))
} else {
  cat(sprintf("any_dzud5_6_17 collinear (mean = %.3f); skipping\n", mean(iv_data$any_dzud5_6_17)))
  iv2 <- NULL
}

# First stage: intensity (share)
fs3 <- feols(educ_years ~ dzud5_intensity + age + age2 + is_female + is_married | region + wave,
             data = iv_data, weights = ~hhweight, cluster = ~aimag + wave)
cat("\n--- First stage: educ_years ~ dzud5_intensity (share) ---\n")
print(coeftable(fs3)["dzud5_intensity", , drop = FALSE])

iv3 <- feols(lwage ~ age + age2 + is_female + is_married | region + wave |
               educ_years ~ dzud5_intensity,
             data = iv_data, weights = ~hhweight, cluster = ~aimag + wave)
cat("IV F-stat:\n"); print(fitstat(iv3, "ivf1"))

# 4-6: Continuous & top-10 alternatives
fs4 <- feols(educ_years ~ cum_loss_rate_6_17 + age + age2 + is_female + is_married | region + wave,
             data = iv_data, weights = ~hhweight, cluster = ~aimag + wave)
cat("\n--- First stage: educ_years ~ cum_loss_rate_6_17 (continuous sum) ---\n")
print(coeftable(fs4)["cum_loss_rate_6_17", , drop = FALSE])
iv4 <- feols(lwage ~ age + age2 + is_female + is_married | region + wave |
               educ_years ~ cum_loss_rate_6_17,
             data = iv_data, weights = ~hhweight, cluster = ~aimag + wave)
cat("IV F-stat:\n"); print(fitstat(iv4, "ivf1"))

fs5 <- feols(educ_years ~ log_cum_loss + age + age2 + is_female + is_married | region + wave,
             data = iv_data, weights = ~hhweight, cluster = ~aimag + wave)
cat("\n--- First stage: educ_years ~ log_cum_loss ---\n")
print(coeftable(fs5)["log_cum_loss", , drop = FALSE])
iv5 <- feols(lwage ~ age + age2 + is_female + is_married | region + wave |
               educ_years ~ log_cum_loss,
             data = iv_data, weights = ~hhweight, cluster = ~aimag + wave)
cat("IV F-stat:\n"); print(fitstat(iv5, "ivf1"))

fs6 <- feols(educ_years ~ dzud_top10_6_17 + age + age2 + is_female + is_married | region + wave,
             data = iv_data, weights = ~hhweight, cluster = ~aimag + wave)
cat("\n--- First stage: educ_years ~ dzud_top10_6_17 (Top-10% threshold) ---\n")
print(coeftable(fs6)["dzud_top10_6_17", , drop = FALSE])
iv6 <- feols(lwage ~ age + age2 + is_female + is_married | region + wave |
               educ_years ~ dzud_top10_6_17,
             data = iv_data, weights = ~hhweight, cluster = ~aimag + wave)
cat("IV F-stat:\n"); print(fitstat(iv6, "ivf1"))

fs7 <- feols(educ_years ~ max_loss_rate_6_17 + age + age2 + is_female + is_married | region + wave,
             data = iv_data |> filter(!is.na(max_loss_rate_6_17)),
             weights = ~hhweight, cluster = ~aimag + wave)
cat("\n--- First stage: educ_years ~ max_loss_rate_6_17 (worst single year) ---\n")
print(coeftable(fs7)["max_loss_rate_6_17", , drop = FALSE])
iv7 <- feols(lwage ~ age + age2 + is_female + is_married | region + wave |
               educ_years ~ max_loss_rate_6_17,
             data = iv_data |> filter(!is.na(max_loss_rate_6_17)),
             weights = ~hhweight, cluster = ~aimag + wave)
cat("IV F-stat:\n"); print(fitstat(iv7, "ivf1"))

# -----------------------------------------------------------------------------
# 6. HETEROGENEITY: rural birth × dzud
# -----------------------------------------------------------------------------
cli_h1("STEP 6: Heterogeneity check (rural × dzud)")

if ("urban" %in% names(iv_data)) {
  iv_rural <- iv_data |> mutate(rural = as.integer(urban == 0))
  fs_het <- feols(educ_years ~ dzud5_6_17 * rural + age + age2 + is_female + is_married |
                    region + wave,
                  data = iv_rural, weights = ~hhweight, cluster = ~aimag + wave)
  cat("First stage with rural interaction:\n")
  print(coeftable(fs_het)[grep("dzud", rownames(coeftable(fs_het))), , drop = FALSE])
}

# -----------------------------------------------------------------------------
# 7. COLLINEARITY with q_school_access
# -----------------------------------------------------------------------------
cli_h1("STEP 7: Collinearity with q_school_access (threshold variable)")

cor_check <- iv_data |> filter(!is.na(q_school_access))
cat(sprintf("N: %d\n", nrow(cor_check)))
cat(sprintf("cor(dzud5_6_17, q_school_access)      = %.4f\n",
            cor(cor_check$dzud5_6_17, cor_check$q_school_access)))
cat(sprintf("cor(any_dzud5_6_17, q_school_access)  = %.4f\n",
            cor(cor_check$any_dzud5_6_17, cor_check$q_school_access)))
cat(sprintf("cor(dzud5_intensity, q_school_access) = %.4f\n",
            cor(cor_check$dzud5_intensity, cor_check$q_school_access, use = "complete.obs")))
cat("(|cor| < 0.5 → IVTR-д ашиглах боломжтой)\n")

# -----------------------------------------------------------------------------
# 8. SUMMARY TABLE
# -----------------------------------------------------------------------------
cli_h1("STEP 8: Summary table")

extract_F <- function(iv) tryCatch(if (is.null(iv)) NA_real_ else fitstat(iv, "ivf1")$ivf1$stat, error = function(e) NA_real_)
extract_b <- function(iv) tryCatch(if (is.null(iv)) NA_real_ else coeftable(iv)["fit_educ_years", "Estimate"], error = function(e) NA_real_)
extract_se <- function(iv) tryCatch(if (is.null(iv)) NA_real_ else coeftable(iv)["fit_educ_years", "Std. Error"], error = function(e) NA_real_)
extract_pi <- function(fs, var) tryCatch(coeftable(fs)[var, "Estimate"], error = function(e) NA_real_)

summary_tbl <- tibble(
  spec = c("dzud5_6_17 (count)", "any_dzud5_6_17 (binary)", "dzud5_intensity (share)",
           "cum_loss_rate_6_17 (continuous)", "log_cum_loss (log)",
           "dzud_top10_6_17 (Top-10%)", "max_loss_rate_6_17 (worst yr)"),
  N = c(rep(nrow(iv_data), 6), sum(!is.na(iv_data$max_loss_rate_6_17))),
  pi_hat = c(extract_pi(fs1, "dzud5_6_17"),
             extract_pi(fs2, "any_dzud5_6_17"),
             extract_pi(fs3, "dzud5_intensity"),
             extract_pi(fs4, "cum_loss_rate_6_17"),
             extract_pi(fs5, "log_cum_loss"),
             extract_pi(fs6, "dzud_top10_6_17"),
             extract_pi(fs7, "max_loss_rate_6_17")),
  F_first = c(extract_F(iv1), extract_F(iv2), extract_F(iv3),
              extract_F(iv4), extract_F(iv5), extract_F(iv6), extract_F(iv7)),
  beta_iv = c(extract_b(iv1), extract_b(iv2), extract_b(iv3),
              extract_b(iv4), extract_b(iv5), extract_b(iv6), extract_b(iv7)),
  se_beta = c(extract_se(iv1), extract_se(iv2), extract_se(iv3),
              extract_se(iv4), extract_se(iv5), extract_se(iv6), extract_se(iv7)),
  cor_qschool_access = c(cor(cor_check$dzud5_6_17, cor_check$q_school_access),
                cor(cor_check$any_dzud5_6_17, cor_check$q_school_access),
                cor(cor_check$dzud5_intensity, cor_check$q_school_access, use = "complete.obs"),
                cor(cor_check$cum_loss_rate_6_17, cor_check$q_school_access),
                cor(cor_check$log_cum_loss, cor_check$q_school_access),
                cor(cor_check$dzud_top10_6_17, cor_check$q_school_access),
                cor(cor_check$max_loss_rate_6_17, cor_check$q_school_access, use = "complete.obs")),
  verdict = NA_character_
) |>
  mutate(verdict = case_when(
    F_first >= 10 & abs(cor_qschool_access) < 0.5 ~ "✅ STRONG (F>=10, low cor)",
    F_first >= 10                        ~ "⚠️ STRONG but high cor q_school_access",
    F_first >= 5                         ~ "🟡 MARGINAL (F in [5,10))",
    F_first >= 1                         ~ "❌ WEAK (F<5)",
    TRUE                                 ~ "🚨 USELESS (F<1)"
  ))

print(summary_tbl)
write_csv(summary_tbl, here("output", "tables", "T2c_dzud_iv.csv"))
cat(sprintf("\nSaved: output/tables/T2c_dzud_iv.csv\n"))

cli_h1("DZUD IV ANALYSIS COMPLETE")
