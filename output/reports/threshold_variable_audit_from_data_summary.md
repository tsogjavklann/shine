# Threshold Variable Audit From Available Data

Generated: 2026-04-26 23:11:06.004143
Main wage sample with parent_educ_mean N: 3710

## 1. Threshold Families Available
- Cognitive ability: candidates=7, usable continuous=0, usable binary=0, top=q0211
- Credit constraints / family background: candidates=17, usable continuous=0, usable binary=0, top=birth_order
- Local labor market conditions / geographic access: candidates=6, usable continuous=2, usable binary=2, top=distance_to_ub
- School quality / education access: candidates=39, usable continuous=2, usable binary=0, top=q_school_access

## 2. Families Unavailable or Weak
- Direct cognitive test/exam/AFQT/math/language scores are unavailable in the processed analysis data.
- Basic literacy/numeracy indicators (`q0211`, `q0212`) exist in the inventory, but are binary proxies and are not currently merged into the processed analysis sample.
- True childhood parental income, parental assets, and parental wealth measures were not found as usable processed variables.
- Current household income/consumption/assets/dwelling variables are post-treatment risk and/or not available in the processed analysis sample.

## 3. Top Recommended Continuous Threshold
- q_school_access (family: School quality / education access, score: 19). Mechanism: Education returns may differ by childhood school access or school quality environment.

## 4. Top Recommended Binary Heterogeneity Split
- born_ub (family: Local labor market conditions / geographic access, score: 14). Use as heterogeneity split, not continuous Caner-Hansen threshold.

## 5. Rejected Variables
- school_density_student_at_15: weak coverage in main wage sample
- school_density_student_at_17: weak coverage in main wage sample
- student_teacher_ratio_at_15: weak coverage in main wage sample
- student_teacher_ratio_at_17: weak coverage in main wage sample
- teachers_per_student_at_15: weak coverage in main wage sample
- teachers_per_student_at_17: weak coverage in main wage sample
- mean_school_density_student_age7_15: weak coverage in main wage sample
- mean_student_teacher_ratio_age7_15: weak coverage in main wage sample
- mean_students_per_school_age7_15: weak coverage in main wage sample
- mean_teachers_per_student_age7_15: weak coverage in main wage sample
- school_density_student_at_12: weak coverage in main wage sample
- student_teacher_ratio_at_12: weak coverage in main wage sample
- teachers_per_student_at_12: weak coverage in main wage sample
- birth_order: insufficient continuous/ordered variation
- mother_educ_years: too close to the IV; insufficient continuous/ordered variation
- n_siblings: insufficient continuous/ordered variation
- parent_educ_mean: same variable as the IV; insufficient continuous/ordered variation
- students_per_school_at_15: weak coverage in main wage sample
- students_per_school_at_17: weak coverage in main wage sample
- n_years_school_access: insufficient continuous/ordered variation

## 6. Should q_school_access Remain Main Threshold?
- q_school_access score: 19; usable continuous: yes; N_nonmissing: 3188; unique values: 356.
- Recommendation: q_school_access should remain the main threshold unless you want a narrower school-quality interpretation using a specific normalized school-supply exposure.

## 7. Is log_distance_to_ub Better?
- log_distance_to_ub score: 17; usable continuous: yes; unique values: 22.
- It is a plausible geographic-access threshold and may be useful as an alternative threshold, but it is coarser than q_school_access and captures broad regional/remoteness differences.
- It must not be used as an IV.

## 8. Truly Predetermined Credit-Constraint Variables
- No true childhood parental income, childhood parental wealth, or childhood asset variable was found in the processed/cleaned audit data.
- `n_siblings` and `birth_order` are predetermined family-background proxies, but they are not direct credit-constraint measures.
- `parent_educ_mean` and father/mother education variables are rejected as thresholds because they overlap with the IV.

## 9. Final Recommendation For Next IVTR Test
- Main recommendation: use `q_school_access` as the next continuous threshold variable.
- Binary split option: `born_ub` only as a heterogeneity split.

## Warnings
- Scores are theory/data-quality scores, not p-values.
- This audit did not run IVTR models.
- Current household/location variables carry post-treatment risk.
- Many household asset/consumption variables are visible in inventories but not merged into processed analysis data.
