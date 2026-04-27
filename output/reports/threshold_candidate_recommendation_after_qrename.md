# Threshold Candidate Search After q_school_access Rename

Generated: 2026-04-27 05:19:31.842691
Parent-IV base sample N: 3710

## Method
- This audit does not estimate IVTR.
- This audit does not search for or change IVs.
- Candidates are scored by theory, predetermined status, data quality, variation, and penalties for post-treatment risk and FE-level limitations.

## Main Finding
- Best continuous candidate found: `student_teacher_ratio_at_17` (score 18, N=1032, unique=296).
- Best binary split candidate: `born_ub` (score 12, N=3710).

## Top Continuous Shortlist
- `student_teacher_ratio_at_17`: score=18, family=School quality, N=1032, unique=296, caveat=Strong theory, but coverage may be limited to cohorts with 2000+ school data.
- `teachers_per_student_at_17`: score=18, family=School quality, N=1032, unique=296, caveat=Inverse of student-teacher ratio; interpretation is cleaner if higher means better supply.
- `q_age`: score=18, family=Life-cycle, N=3710, unique= 35, caveat=Not family/home background; age is already a control.
- `q_school_access`: score=18, family=School access, N=3188, unique=356, caveat=Previously used; partial exposure for older cohorts.
- `school_density_student_at_17`: score=17, family=School access, N=1032, unique=255, caveat=Age-17 exposure avoids partial 6-17 averaging.
- `students_per_school_at_17`: score=17, family=School crowding, N=1032, unique=255, caveat=Higher values mean more crowded schools.
- `mean_student_teacher_ratio_age7_15`: score=16, family=School quality, N= 523, unique=125, caveat=Conceptually good, but can inherit partial-coverage problems.
- `mean_teachers_per_student_age7_15`: score=16, family=School quality, N= 523, unique=125, caveat=Conceptually good, but can inherit partial-coverage problems.
- `q_birth_year`: score=16, family=Cohort, N=3710, unique= 39, caveat=Closely related to birth_cohort FE and wave-age structure.
- `mean_school_density_student_age7_15`: score=15, family=School access, N= 523, unique=125, caveat=Close to q_school_access but narrower construction.

## Variables Not Recommended As Main Continuous TR
- `n_siblings`: too little variation for continuous threshold (score=15, N=3710).
- `birth_order`: too little variation for continuous threshold (score=14, N=3710).
- `born_ub`: binary split only, not continuous threshold (score=12, N=3710).
- `rural_birth`: binary split only, not continuous threshold (score=12, N=3710).
- `teachers_per_1000_children_at_17`: missing or no variation (score=10, N=   0).
- `q_current_hhsize`: post-treatment/current-outcome risk (score= 7, N=3710).
- `urban`: post-treatment/current-outcome risk (score= 4, N=3710).

## Recommendation
- If you want a threshold more theoretically precise than `q_school_access`, the best available next candidate is a late-school-age school-quality measure, especially `student_teacher_ratio_at_17` or `teachers_per_student_at_17`.
- These are preferable to the old `q_school_access` because they avoid averaging over partially observed childhood years.
- They are preferable to `log_distance_to_ub` because they capture school-quality/access more directly and have more continuous variation.
- Their weakness is smaller sample coverage, so the next step should be matrix/sample preparation only, not immediate bootstrap claims.

## Important Warnings
- HSES does not contain a clean retrospective childhood household income/wealth variable for adult respondents.
- Current household-condition variables are not recommended as main TR because education and wages may affect them.
- `parent_educ_mean`, `father_educ_years`, and `mother_educ_years` should not be thresholds because they overlap with the IV.
- Binary variables such as `born_ub` are heterogeneity splits, not continuous Caner-Hansen threshold variables.
