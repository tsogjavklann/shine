# Stage 19B: log_distance_to_ub Matrix Preparation

Generated: 2026-04-27 00:08:28.998886

## Design
- Outcome: `lwage`.
- Endogenous regressor: `educ_years`.
- Instrument: `parent_educ_mean`.
- Threshold variable: `log_distance_to_ub`.
- Controls: age, age2, female, married, urban.
- Fixed effects residualized: birth_aimag, birth_cohort, wave.
- Weights used in residualization: hhweight
- Cluster variable for later stages: birth_aimag.

## Sample Diagnostics
- N: 3188
- birth_aimag clusters: 22
- birth_cohort groups: 4
- waves: 4
- log_distance_to_ub min/p10/p25/p50/p75/p90/max: 0.0000 / 0.0000 / 0.0000 / 5.8937 / 6.3385 / 7.0350 / 7.1333
- unique log_distance_to_ub values: 22
- distance_to_ub min/p10/p25/p50/p75/p90/max: 0.0000 / 0.0000 / 0.0000 / 362.7433 / 565.9255 / 1135.6939 / 1252.9474
- corr(log_distance_to_ub, educ_years): -0.0371
- corr(log_distance_to_ub, parent_educ_mean): -0.2402
- corr(log_distance_to_ub, lwage): -0.1061

## Residualization
- Residualized dataset: C:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/shine/data/processed/ch_residualized_logdist_parent_mean.rds
- Residualization succeeded: TRUE
- log_distance_to_ub was not residualized and remains in levels.

## Median-threshold Matrix Diagnostics
- gamma_example: 5.8937
- N_low: 1604
- N_high: 1584
- X dimensions: 3188 x 7
- Z dimensions: 3188 x 7
- rank(X): 7
- rank(Z): 7
- rank(Z'Z): 7
- Z'Z invertible: TRUE
- rank(X'PzX): 7
- X'PzX invertible: TRUE
- X'PzX condition number: 182784.2224
- Example matrices full rank: TRUE

## Birth-aimag Threshold Limitation
- log_distance_to_ub deterministic by birth_aimag: TRUE
- This did not cause matrix-rank failure at the median threshold.
- It remains a substantive limitation because the threshold has only birth-aimag-level variation while y/x/z/controls are residualized on birth_aimag FE.

## Decision
Proceed to Stage 19C threshold grid search.

## Warnings / Limitations
- Stage 19B only prepares residualized data and checks one example threshold matrix.
- No threshold grid search, GMM, or bootstrap was run.
- log_distance_to_ub is a threshold variable only and was not used as an IV.
- log_distance_to_ub has only 22 unique values.
- The parental-education exclusion caveat remains.
