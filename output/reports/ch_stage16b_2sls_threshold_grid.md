# Stage 16B: Caner-Hansen-style 2SLS Threshold Grid

Generated: 2026-04-26 22:06:11.527093

## Design
- Outcome: `lwage_r`.
- Endogenous regressor: `educ_years_r`.
- Instrument: `parent_educ_mean_r`.
- Threshold variable: `q_school_access` in levels.
- Controls: `age_r`, `age2_r`, `female_r`, `married_r`, `urban_r`.
- Weights: hhweight

## Accepted IV Diagnostics
- `parent_educ_mean` is constructed from `father_educ_years` and `mother_educ_years` only.
- No `educ_years` leakage.
- IVTR-ready first-stage clustered Wald F = 558.45.
- Weak-IV flag = FALSE.

## Grid Diagnostics
- Candidate thresholds: 279
- Valid grid points: 279
- Skipped/invalid grid points: 0
- Warning-flagged grid points: 0

## gamma_hat
- gamma_hat: 1.0380
- N_low: 793
- N_high: 2395
- beta_low_2SLS: 0.1205
- beta_high_2SLS: 0.0909
- Minimum SSR: 45607.5815
- rank_X: 7
- rank_Z: 7
- rank_XPZX: 7
- condition_number_XPZX: 183728.9851

## Numerical Warnings
- No warning-flagged grid points.

## Decision
Proceed to Stage 16C GMM slope estimation.

## Limitations
- Stage 16B estimates gamma_hat by residualized 2SLS grid search only.
- No final GMM slope estimation was run.
- No bootstrap was run.
- Stage 16C should keep monitoring condition numbers and rank failures.
