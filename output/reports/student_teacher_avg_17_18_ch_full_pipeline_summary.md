# Student-teacher Ratio at ages 17-18 IV Threshold Pipeline

Generated: 2026-04-27 10:39:45.367968

## 1. Empirical Design
- Outcome: `lwage`.
- Endogenous regressor: `educ_years`.
- IV: `parent_educ_mean`.
- Threshold variable: `student_teacher_ratio_avg_17_18`.
- Controls: age, age2, female, married, urban.
- Fixed effects residualized: birth_aimag, birth_cohort, wave.
- Weights: hhweight.
- Cluster/bootstrap unit: birth_aimag.
- Higher threshold values mean more students per teacher, i.e. more crowded/lower teacher-intensity school environment.
- `student_teacher_ratio_avg_17_18` is not used as an IV.

## 2. Sample Diagnostics
- N: 3188
- birth_aimag clusters: 22
- birth_cohort groups: 4
- waves: 4
- birth_year range: 1983 to 1999
- year_at_17_18 range: 2001 to 2017
- student_teacher_ratio_avg_17_18 min/p10/p25/p50/p75/p90/max: 3.7858 / 16.8914 / 18.4827 / 20.5079 / 23.8847 / 26.2976 / 70.0574
- unique threshold values: 359
- corr(threshold, educ_years): -0.0491
- corr(threshold, parent_educ_mean): 0.0055
- corr(threshold, lwage): 0.0231
- deterministic by birth_aimag: FALSE
- deterministic by birth_aimag + year_at_17_18: TRUE

## 3. Baseline OLS and 2SLS on This Sample
- OLS beta: 0.0472, SE: 0.0034, p-value: 0.0000
- 2SLS beta: 0.1033, SE: 0.0118, p-value: 0.0000
- First-stage parent_educ_mean coefficient: 0.3623, SE: 0.0153, F: 558.4505
- Weak-IV flag F < 10: FALSE

## 4. Residualization and Matrix Diagnostics
- Residualized dataset: C:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/shine/data/processed/ch_residualized_student_teacher_avg_17_18_parent_mean.rds
- Residualization succeeded: TRUE
- Median threshold example gamma: 20.5079
- Median example N_low/N_high: 1607 / 1581
- Median example rank(X)/rank(Z)/rank(X'PzX): 7 / 7 / 7
- Median example X'PzX condition number: 186786.1592

## 5. 2SLS Threshold Grid
- Candidate thresholds: 278
- Valid grid points: 278
- Skipped/invalid grid points: 0
- Warning-flagged grid points: 0
- gamma_hat: 19.5306
- N_low/N_high at gamma_hat: 1051 / 2137
- beta_low_2SLS: 0.0784
- beta_high_2SLS: 0.1094
- minimum SSR: 45704.6528

## 6. GMM Slopes at gamma_hat
- Weighting matrix: cluster-robust S by birth_aimag
- beta_low_GMM: 0.0784, SE: 0.0191, p-value: 0.0005
- beta_high_GMM: 0.1094, SE: 0.0095, p-value: 0.0000
- beta_high - beta_low: 0.0310
- Wald p-value: 0.1021

## 7. Bootstrap Inference
- Requested bootstrap replications: 399
- Successful draws: 399
- Failed draws: 0
- Warning-flagged draws: 0
- gamma 2.5% / 5% / 50% / 95% / 97.5%: 18.4827 / 18.5646 / 19.5570 / 25.5063 / 25.5346
- beta_low percentile CI: [0.0558, 0.1173]
- beta_high percentile CI: [0.0800, 0.1504]
- beta_diff percentile CI: [0.0044, 0.0608]
- beta_diff CI contains zero: FALSE
- bootstrap p-value: 0.0451

## 8. Inference Conclusion
Bootstrap inference supports education returns differing across student-teacher-ratio regimes at the 5% level.
Do not interpret student_teacher_ratio_avg_17_18 as causing wage returns.

## 9. Caveats
- `student_teacher_ratio_avg_17_18` is a school-quality/crowding proxy, not a home-environment proxy.
- The threshold sample is much smaller because complete school-supply data at ages 17 and 18 is available only for cohorts whose late-school exposure falls in the observed school-supply panel.
- Only 22 birth_aimag clusters are available; cluster bootstrap inference can be noisy.
- The threshold is tied to birth_aimag and year_at_17_18, so it is not individual-level random variation.
- High condition numbers should be monitored when comparing with prior threshold results.
- Parental education may affect wages through family background, networks, and unobserved ability channels.
- FE residualization is an approximation to a high-dimensional fixed-effects threshold model.
- This is a Caner-Hansen-style IV threshold implementation, not a claim that threshold placement is causal.
