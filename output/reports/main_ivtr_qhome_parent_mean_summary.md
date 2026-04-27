# Main IVTR: q_school_access Threshold with parent_educ_mean IV

Generated: 2026-04-26 21:54:13.79544

## 1. Empirical Design
- Outcome: `lwage`.
- Endogenous regressor: `educ_years`.
- Main IV: `parent_educ_mean`.
- Threshold variable: `q_school_access`.
- Controls: age, age2, female, married, urban.
- Fixed effects: birth_aimag, birth_cohort, wave.
- Weights: `hhweight`.
- Cluster: birth_aimag.

## 2. Existing Caner-Hansen Implementation
- Exact implementation found: FALSE

## 3. Method Note
- Method: Caner-Hansen-inspired IV threshold approximation.
- Objective: Weighted second-stage residual sum of squares; not full Caner-Hansen GMM inference.

## 4. Accepted IV Diagnostics
- `parent_educ_mean` is constructed from `father_educ_years` and `mother_educ_years` only.
- It does not use `educ_years`.
- Audited IVTR-ready sample first-stage clustered Wald F = 558.45.
- Weak-IV flag = FALSE.

## 5. q_school_access Diagnostics
- N: 3188
- min: 0.7819, p10: 0.9478, p25: 1.0522, p50: 1.4560, p75: 1.7398, p90: 1.9572, max: 2.3019
- unique values: 356
- corr(q_school_access, educ_years): 0.0014
- corr(q_school_access, parent_educ_mean): -0.1569
- birth_aimag clusters: 22, birth_cohort groups: 4, waves: 4

## 6. Baseline OLS and 2SLS
- OLS beta: 0.0472, SE: 0.0034, p-value: 0.0000
- 2SLS beta: 0.1033, SE: 0.0118, p-value: 0.0000

## 7. gamma_hat
- gamma_hat: 1.3942

## 8. Regime Sizes
- Low regime N: 1495
- High regime N: 1693

## 9. Regime Returns
- beta_low: 0.1074, SE: 0.0097, p-value: 0.0000
- beta_high: 0.0939, SE: 0.0150, p-value: 0.0000
- beta_high - beta_low: -0.0135

## 10. Threshold Effect Test
- Wald F: 1.4284, p-value: 0.2453, df: 1, 21

## 11. Interpretation
The regime point estimates differ numerically, but there is no strong evidence of threshold heterogeneity in education returns across q_school_access regimes.
This should not be read as q_school_access causing wage returns.

## 12. Caveats
- This is not a full Caner-Hansen GMM implementation or nonstandard threshold inference.
- Parental education may affect wages through family background, networks, and unobserved ability channels.
- q_school_access is treated as a threshold proxy; if it reflects current household conditions, interpretation should be cautious.
- The threshold search uses an in-sample weighted RSS objective, so threshold-effect inference is approximate.
