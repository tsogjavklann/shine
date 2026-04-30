# Student-teacher Ratio at Ages 16-17 IV Threshold Pipeline

Generated: 2026-04-27 10:33:54.869795

## 1. Empirical Design
- Outcome: `lwage`.
- Endogenous regressor: `educ_years`.
- IV: `parent_educ_mean`.
- Threshold variable: `student_teacher_ratio_avg_16_17`.
- Controls: age, age2, female, married, urban.
- Fixed effects residualized: birth_aimag, birth_cohort, wave.
- Weights: hhweight.
- Cluster/bootstrap unit: birth_aimag.
- Higher threshold values mean more students per teacher, i.e. more crowded/lower teacher-intensity school environment.
- `student_teacher_ratio_avg_16_17` is not used as an IV.

## 2. Sample Diagnostics
- N: 3113
- birth_aimag clusters: 22
- birth_cohort groups: 4
- waves: 4
- birth_year range: 1984 to 1999
- year_at_16_17 range: 2001 to 2016
- student_teacher_ratio_avg_16_17 min/p10/p25/p50/p75/p90/max: 3.7293 / 17.4568 / 19.0192 / 20.7979 / 24.1682 / 26.3568 / 67.2181
- unique threshold values: 339
- corr(threshold, educ_years): -0.0443
- corr(threshold, parent_educ_mean): 0.0087
- corr(threshold, lwage): 0.0198
- deterministic by birth_aimag: FALSE
- deterministic by birth_aimag + year_at_16_17: TRUE

## 3. Baseline OLS and 2SLS on This Sample
- OLS beta: 0.0468, SE: 0.0033, p-value: 0.0000
- 2SLS beta: 0.1057, SE: 0.0110, p-value: 0.0000
- First-stage parent_educ_mean coefficient: 0.3559, SE: 0.0172, F: 427.2425
- Weak-IV flag F < 10: FALSE

## 4. Residualization and Matrix Diagnostics
- Residualized dataset: C:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/shine/data/processed/ch_residualized_student_teacher_avg_16_17_parent_mean.rds
- Residualization succeeded: TRUE
- Median threshold example gamma: 20.7979
- Median example N_low/N_high: 1560 / 1553
- Median example rank(X)/rank(Z)/rank(X'PzX): 7 / 7 / 7
- Median example X'PzX condition number: 201018.3320

## 5. 2SLS Threshold Grid
- Candidate thresholds: 259
- Valid grid points: 259
- Skipped/invalid grid points: 0
- Warning-flagged grid points: 0
- gamma_hat: 19.7299
- N_low/N_high at gamma_hat: 1017 / 2096
- beta_low_2SLS: 0.0868
- beta_high_2SLS: 0.1106
- minimum SSR: 44956.4408

## 6. GMM Slopes at gamma_hat
- Weighting matrix: cluster-robust S by birth_aimag
- beta_low_GMM: 0.0868, SE: 0.0197, p-value: 0.0003
- beta_high_GMM: 0.1106, SE: 0.0096, p-value: 0.0000
- beta_high - beta_low: 0.0238
- Wald p-value: 0.2226

## 7. Bootstrap Inference
- Requested bootstrap replications: 399
- Successful draws: 399
- Failed draws: 0
- Warning-flagged draws: 0
- gamma 2.5% / 5% / 50% / 95% / 97.5%: 17.9216 / 18.0680 / 19.7299 / 25.8393 / 25.9937
- beta_low percentile CI: [0.0596, 0.1196]
- beta_high percentile CI: [0.0846, 0.1650]
- beta_diff percentile CI: [0.0042, 0.0676]
- beta_diff CI contains zero: FALSE
- bootstrap p-value: 0.1228

## 8. Inference Conclusion
Bootstrap inference does not strongly support student-teacher-ratio threshold heterogeneity in education returns at the 5% level.
Do not interpret student_teacher_ratio_avg_16_17 as causing wage returns.

## 9. Caveats
- `student_teacher_ratio_avg_16_17` is a school-quality/crowding proxy, not a home-environment proxy.
- The threshold sample is much smaller because complete school-supply data at ages 16 and 17 is available only for cohorts whose late-school exposure falls in the observed school-supply panel.
- Only 22 birth_aimag clusters are available; cluster bootstrap inference can be noisy.
- The threshold is tied to birth_aimag and year_at_16_17, so it is not individual-level random variation.
- High condition numbers should be monitored when comparing with prior threshold results.
- Parental education may affect wages through family background, networks, and unobserved ability channels.
- FE residualization is an approximation to a high-dimensional fixed-effects threshold model.
- This is a Caner-Hansen-style IV threshold implementation, not a claim that threshold placement is causal.
