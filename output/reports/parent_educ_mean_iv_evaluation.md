# parent_educ_mean IV Evaluation

Generated: 2026-04-26 21:36:50.211353
Input sample: C:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/shine/data/processed/analysis_sample.rds
Family source: C:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/shine/data/processed/family_structure.rds
IV basis: years-based
Weights: hhweight
Cluster: birth_aimag

## OLS
- N: 3710
- beta_OLS: 0.0487, SE: 0.0034, p-value: 0.0000

## parent_educ_mean IV
- N: 3710
- beta_2SLS: 0.1002, SE: 0.0117, p-value: 0.0000
- First-stage coefficient: 0.3647, SE: 0.0157, p-value: 0.0000
- First-stage F: 602.2311, weak-IV flag: FALSE
- Just-identified model: overidentification does not apply.
- Parent education may affect wages through family background, networks, and unobserved ability channels.

## q_school_access Diagnostics
- N nonmissing: 3188
- Mean: 1.4423, SD: 0.3903, Min: 0.7819, Max: 2.3019
- p10: 0.9478, p25: 1.0522, p50: 1.4560, p75: 1.7398, p90: 1.9572
- Unique values: 356
- corr(q_school_access, educ_years): 0.0014
- corr(q_school_access, parent_educ_mean): -0.1569

## Decision
Proceed to IVTR with parent_educ_mean and q_school_access.
IVTR-ready dataset created: TRUE
IVTR-ready dataset: C:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/shine/data/processed/ivtr_ready_parent_educ_mean_qschool_access.rds

## Warnings
- The VCOV matrix is not positive definite and was 'fixed' (see ?vcov).
- Two-way cluster warning detected; main table uses one-way birth_aimag clustering.
