# Student-teacher Ratio at Age 17 IV Threshold Pipeline

Generated: 2026-04-27 05:35:57.333203

## 1. Empirical Design
- Outcome: `lwage`.
- Endogenous regressor: `educ_years`.
- IV: `parent_educ_mean`.
- Threshold variable: `student_teacher_ratio_at_17`.
- Controls: age, age2, female, married, urban.
- Fixed effects residualized: birth_aimag, birth_cohort, wave.
- Weights: hhweight.
- Cluster/bootstrap unit: birth_aimag.
- Higher threshold values mean more students per teacher, i.e. more crowded/lower teacher-intensity school environment.
- `student_teacher_ratio_at_17` is not used as an IV.

## 2. Sample Diagnostics
- N: 1032
- birth_aimag clusters: 22
- birth_cohort groups: 4
- waves: 4
- birth_year range: 1983 to 1999
- year_at_17 range: 2000 to 2016
- student_teacher_ratio_at_17 min/p10/p25/p50/p75/p90/max: 3.6755 / 17.1544 / 18.5492 / 20.9544 / 24.2891 / 26.1962 / 66.4804
- unique threshold values: 296
- corr(threshold, educ_years): -0.0537
- corr(threshold, parent_educ_mean): 0.0517
- corr(threshold, lwage): 0.0538
- deterministic by birth_aimag: FALSE
- deterministic by birth_aimag + year_at_17: TRUE

## 3. Baseline OLS and 2SLS on This Sample
- OLS beta: 0.0549, SE: 0.0066, p-value: 0.0000
- 2SLS beta: 0.1093, SE: 0.0157, p-value: 0.0000
- First-stage parent_educ_mean coefficient: 0.3790, SE: 0.0403, F: 88.5095
- Weak-IV flag F < 10: FALSE

## 4. Residualization and Matrix Diagnostics
- Residualized dataset: C:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/shine/data/processed/ch_residualized_student_teacher17_parent_mean.rds
- Residualization succeeded: TRUE
- Median threshold example gamma: 20.9544
- Median example N_low/N_high: 520 / 512
- Median example rank(X)/rank(Z)/rank(X'PzX): 7 / 7 / 7
- Median example X'PzX condition number: 239490.2202

## 5. 2SLS Threshold Grid
- Candidate thresholds: 233
- Valid grid points: 233
- Skipped/invalid grid points: 0
- Warning-flagged grid points: 0
- gamma_hat: 25.4688
- N_low/N_high at gamma_hat: 855 / 177
- beta_low_2SLS: 0.0970
- beta_high_2SLS: 0.1382
- minimum SSR: 16668.3138

## 6. GMM Slopes at gamma_hat
- Weighting matrix: cluster-robust S by birth_aimag
- beta_low_GMM: 0.0970, SE: 0.0192, p-value: 0.0001
- beta_high_GMM: 0.1382, SE: 0.0296, p-value: 0.0001
- beta_high - beta_low: 0.0412
- Wald p-value: 0.2947

## 7. Bootstrap Inference
- Requested bootstrap replications: 399
- Successful draws: 399
- Failed draws: 0
- Warning-flagged draws: 0
- gamma 2.5% / 5% / 50% / 95% / 97.5%: 17.4136 / 17.4136 / 25.3876 / 25.8065 / 25.8065
- beta_low percentile CI: [0.0425, 0.1454]
- beta_high percentile CI: [0.0762, 0.1844]
- beta_diff percentile CI: [-0.0272, 0.0793]
- beta_diff CI contains zero: TRUE
- bootstrap p-value: 0.0802

## 8. Inference Conclusion
Bootstrap inference does not strongly support student-teacher-ratio threshold heterogeneity in education returns at the 5% level.
Do not interpret student_teacher_ratio_at_17 as causing wage returns.

## 9. Caveats
- `student_teacher_ratio_at_17` is a school-quality/crowding proxy, not a home-environment proxy.
- The threshold sample is much smaller because school-supply data at age 17 is available only for cohorts whose age-17 exposure falls in the observed school-supply panel.
- Only 22 birth_aimag clusters are available; cluster bootstrap inference can be noisy.
- The threshold is tied to birth_aimag and year_at_17, so it is not individual-level random variation.
- High condition numbers should be monitored when comparing with prior threshold results.
- Parental education may affect wages through family background, networks, and unobserved ability channels.
- FE residualization is an approximation to a high-dimensional fixed-effects threshold model.
- This is a Caner-Hansen-style IV threshold implementation, not a claim that threshold placement is causal.
