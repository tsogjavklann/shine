# Final Pastore-Style Parental Education IV

Generated: 2026-04-26 21:24:09.902159
Input sample: C:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/shine/data/processed/analysis_sample.rds
Parental education source: C:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/shine/data/processed/family_structure.rds
IV basis: years-based
Weights: hhweight
Cluster: birth_aimag

## Results
- N: 1802
- OLS beta: 0.0420, SE: 0.0035, p-value: 0.0000
- 2SLS beta: 0.1011, SE: 0.0178, p-value: 0.0000
- First-stage joint F, father + mother instruments: 140.0662, p-value: 0.0000
- father_educ_years first-stage coefficient: 0.1958, SE: 0.0243, p-value: 0.0000
- mother_educ_years first-stage coefficient: 0.1892, SE: 0.0195, p-value: 0.0000
- Weak-IV flag: FALSE
- Overidentification test: The overidentifying restrictions are rejected.
- Overid statistic: 5.4229, df: 1, p-value: 0.0199

## q_school_access Diagnostics
- N nonmissing: 1802
- Mean: 1.4503, SD: 0.3909, Min: 0.7819, Max: 2.3019
- p10: 0.9484, p25: 1.0522, p50: 1.4579, p75: 1.7398, p90: 1.9528
- Unique values: 323
- Correlation with educ_years: -0.0033
- Correlation with father_educ_years: -0.1527
- Correlation with mother_educ_years: -0.1329

## Interpretation
The overidentifying restrictions are rejected.
Parental education may affect wages through family background, networks, and unobserved ability channels.
Decision: Do not proceed to IVTR as the main causal design without revisiting IV strength/validity.

## Warnings
- The VCOV matrix is not positive definite and was 'fixed' (see ?vcov).
- Two-way cluster warning detected; main table uses one-way birth_aimag clustering.

IVTR-ready dataset: C:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/shine/data/processed/ivtr_ready_pastore_parental_qschool_access.rds
