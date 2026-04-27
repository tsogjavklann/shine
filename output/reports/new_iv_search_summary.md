# New HSES IV Search

Generated: 2026-04-26 18:43:03.012363

Main wage sample N before IV-specific missing filters: 18264
Candidate IVs tested: 50

## Top 10 by Corrected-FE First Stage

- dropout_grade: pi=0.9393, F=2567.5, N=406, verdict=STRONG, q_school_access_cor=0.058
- health_insured: pi=2.0166, F=439.6, N=18259, verdict=STRONG, q_school_access_cor=-0.011
- parent_educ_mean: pi=0.3819, F=135.96, N=1221, verdict=STRONG, q_school_access_cor=-0.126
- ever_dropout: pi=-7.7314, F=119.45, N=429, verdict=STRONG, q_school_access_cor=-0.063
- migration_reason_education_self: pi=1.2455, F=117.37, N=18259, verdict=STRONG, q_school_access_cor=0.053
- mother_educ_years: pi=0.3586, F=113.64, N=1129, verdict=STRONG, q_school_access_cor=-0.099
- father_educ_years: pi=0.3431, F=98.75, N=729, verdict=STRONG, q_school_access_cor=-0.128
- rural_birth_x_birth_year_c: pi=0.0273, F=45.76, N=18259, verdict=STRONG, q_school_access_cor=0.197
- born_ub_x_birth_year_c: pi=-0.0273, F=45.76, N=18259, verdict=STRONG, q_school_access_cor=-0.374
- years_since_migration: pi=-0.0222, F=39.32, N=14200, verdict=STRONG, q_school_access_cor=0.102

## Strong
- dropout_grade: F=2567.5, notes=HSES schooling | Post-treatment: not a valid IV
- health_insured: F=439.6, notes=HSES health | Current health insurance; endogenous
- parent_educ_mean: F=135.96, notes=Family roster | Strong first stage possible but exclusion restriction caveat
- ever_dropout: F=119.45, notes=HSES schooling | Post-treatment: not a valid IV
- migration_reason_education_self: F=117.37, notes=HSES migration | Directly education-related; invalid as excluded IV
- mother_educ_years: F=113.64, notes=Family roster | Strong first stage possible but exclusion restriction caveat
- father_educ_years: F=98.75, notes=Family roster | Strong first stage possible but exclusion restriction caveat
- rural_birth_x_birth_year_c: F=45.76, notes=Cohort x geography | Interaction diagnostic; needs substantive shock story
- born_ub_x_birth_year_c: F=45.76, notes=Cohort x geography | Interaction diagnostic; needs substantive shock story
- years_since_migration: F=39.32, notes=HSES migration | Migration timing is likely endogenous
- severe_cognitive_difficulty: F=28.81, notes=HSES disability | Current disability; direct wage channel
- any_mildplus_disability: F=21.77, notes=HSES disability | Current disability; direct wage channel
- any_severe_disability: F=16.97, notes=HSES disability | Current disability; direct wage channel
- migration_reason_children_school: F=14.48, notes=HSES migration | Household choice; exclusion risk
- migrated_school_age_6_17: F=12.09, notes=HSES migration | Retrospective migration; exclusion risk
- severe_language_difficulty: F=10.73, notes=HSES language/disability | Not ethnicity; direct channels possible

## Marginal
- migrated_before_18: F=9.93, notes=HSES migration | Retrospective migration; exclusion risk
- severe_hearing_difficulty: F=7.91, notes=HSES disability | Current disability; direct wage channel
- current_school_public: F=7.44, notes=HSES current school | Current student only; low adult wage coverage
- migrated_school_age_x_rural_birth: F=7.13, notes=Migration x geography | Endogenous migration interaction

## Hidden Gems Tested
- migrated_school_age_6_17: F=12.09, verdict=STRONG
- dropout_reason_distance: F=2.98, verdict=WRONG_SIGN
- dormitory_current_student: F=0.03, verdict=WEAK
- birth_soum_available: F=NA, verdict=COLLINEAR_USELESS
- migration_reason_natural_disaster: F=NA, verdict=COLLINEAR_USELESS
- never_school_reason_dorm_shortage: F=NA, verdict=COLLINEAR_USELESS

## Recommended IV
No clean HSES-only IV is recommended. Strong first stages, where present, have exclusion restriction or post-treatment problems.
