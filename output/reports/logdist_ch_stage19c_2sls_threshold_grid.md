# Stage 19C: log_distance_to_ub 2SLS Threshold Grid

Generated: 2026-04-27 00:12:18.653285

## Design
- Outcome: `lwage_r`.
- Endogenous regressor: `educ_years_r`.
- Instrument: `parent_educ_mean_r`.
- Threshold variable: `log_distance_to_ub` in levels.
- Controls: `age_r`, `age2_r`, `female_r`, `married_r`, `urban_r`.
- Weights: hhweight
- `log_distance_to_ub` is used only as a threshold variable, not as an IV.

## Grid Diagnostics
- Candidate thresholds: 21
- Valid grid points: 21
- Skipped/invalid grid points: 0
- Warning-flagged grid points: 0
- p10 and p25 are zero: TRUE
- p10 and p25 equal zero because UB-born respondents have distance 0.
- The gamma grid is coarse because log_distance_to_ub has only 22 unique birth-aimag-level values.

## gamma_hat
- gamma_hat: 6.2288
- distance_cutoff_km: 507.1563
- N_low: 2086
- N_high: 1102
- beta_low_2SLS: 0.1101
- beta_high_2SLS: 0.0795
- Minimum SSR: 45632.9086
- rank_X: 7
- rank_Z: 7
- rank_XPZX: 7
- condition_number_XPZX: 182644.4405

## Numerical Warnings
- No warning-flagged grid points.

## Decision
Proceed to Stage 19D GMM slope estimation.

## Limitations
- Stage 19C estimates gamma_hat by residualized 2SLS grid search only.
- No final GMM slope estimation was run.
- No bootstrap was run.
- log_distance_to_ub has only 22 unique birth-aimag-level values.
- Stage 19D should keep monitoring condition numbers and rank failures.
