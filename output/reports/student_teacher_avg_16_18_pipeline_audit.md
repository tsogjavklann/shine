# Audit: student_teacher_ratio_avg_16_18 Threshold Pipeline

Generated: 2026-04-27 10:19:04.571182

## Verdict
PASS: no construction, IV-role, grid, regime-coding, or rank error was found.

## Construction Checks
- Panel formula max abs difference for student_teacher_ratio = students / teachers: 0e+00
- Saved threshold vs independently rebuilt threshold max abs difference: 0e+00
- Saved parent_educ_mean vs rebuilt from father/mother max abs difference: 0e+00
- All saved observations have complete age 16, 17, and 18 school-supply years: TRUE

## Role Checks
- Parent IV formula present: TRUE
- GMM instruments use parent_educ_mean_r interactions: TRUE
- Threshold used as instrument: FALSE
- log_distance_to_ub used as IV: FALSE
- father+mother overidentified IV used: FALSE

## Grid / Regime / Matrix Checks
- gamma_hat matches minimum SSR grid point: TRUE
- Grid rows / warning rows: 252 / 0
- Regime counts match gamma table: TRUE
- Low/high N: 1007 / 2106
- Full rank GMM matrices: TRUE
- Near-singular warning: FALSE

## Bootstrap Check
- Successful / failed / warning draws: 1999 / 0 / 1
- beta_diff observed: 0.022406
- beta_diff percentile CI: [-0.000778, 0.058425]
- Percentile CI contains zero: TRUE
- Centered bootstrap p-value: 0.114057
- Sign-based two-sided p-value: 0.053027
- Note: the centered bootstrap p-value and percentile CI can disagree because they answer slightly different bootstrap-tail questions.

## Important Interpretation
- The computational pipeline passed the audit.
- The inference is still methodologically cautious: the centered bootstrap p-value is above 0.05, while the percentile CI excludes zero.
- Therefore, do not write this as unequivocally proven strong heterogeneity. Write it as suggestive evidence with a positive percentile interval, but with the bootstrap p-value caveat.
- The direction remains high-crowding regime > low-crowding regime, which is not the simple better-school-quality story.
