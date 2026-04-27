# Stage 16A: Caner-Hansen Matrix Preparation

Generated: 2026-04-26 22:02:07.2798

## Design
- Outcome: `lwage`.
- Endogenous regressor: `educ_years`.
- Instrument: `parent_educ_mean`.
- Threshold variable: `q_school_access`.
- Controls: age, age2, female, married, urban.
- Fixed effects residualized: birth_aimag, birth_cohort, wave.
- Weights used in residualization: hhweight

## Accepted IV Diagnostics
- `parent_educ_mean` is constructed from `father_educ_years` and `mother_educ_years` only.
- No `educ_years` leakage.
- IVTR-ready first-stage clustered Wald F = 558.45.
- Weak-IV flag = FALSE.

## Sample Diagnostics
- N: 3188
- birth_aimag clusters: 22
- birth_cohort groups: 4
- waves: 4
- q_school_access min/p10/p25/p50/p75/p90/max: 0.7819 / 0.9478 / 1.0522 / 1.4560 / 1.7398 / 1.9572 / 2.3019
- unique q_school_access values: 356
- corr(q_school_access, educ_years): 0.0014
- corr(q_school_access, parent_educ_mean): -0.1569

## Residualization
- Residualized dataset: C:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/shine/data/processed/ch_residualized_qschool_access_parent_mean.rds
- Residualization succeeded: TRUE
- q_school_access was not residualized and remains in levels.

## Median-threshold Matrix Diagnostics
- gamma_example: 1.4560
- N_low: 1595
- N_high: 1593
- X dimensions: 3188 x 7
- Z dimensions: 3188 x 7
- rank(X): 7
- rank(Z): 7
- X'PzX invertible: TRUE
- X'PzX condition number: 183485.3280
- Example matrices full rank: TRUE

## Decision
Proceed to Stage 16B grid search.

## Warnings / Limitations
- Stage 16A only prepares residualized data and checks one example threshold matrix.
- No full Caner-Hansen estimator was run.
- No bootstrap was run.
- q_school_access threshold validity and parental-education exclusion caveats remain.
