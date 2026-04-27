# log_distance_to_ub Threshold Sample Preparation

Generated: 2026-04-26 23:54:25.139956

## Design Going Forward
- Outcome: `lwage`.
- Endogenous regressor: `educ_years`.
- IV: `parent_educ_mean`.
- Threshold variable: `log_distance_to_ub`.
- Controls: age, age2, female, married, urban.
- Fixed effects: birth_aimag, birth_cohort, wave.
- Weights: hhweight
- Cluster: birth_aimag.

## Source
- log_distance_to_ub reconstructed from data/auxiliary/aimag_distance_to_ub.csv using birth_aimag
- `log_distance_to_ub` is a threshold variable only; it is not used as an IV.

## Sample Diagnostics
- N: 3188
- birth_aimag clusters: 22
- birth_cohort groups: 4
- waves: 4
- log_distance_to_ub min/p10/p25/p50/p75/p90/max: 0.0000 / 0.0000 / 0.0000 / 5.8937 / 6.3385 / 7.0350 / 7.1333
- unique log_distance_to_ub values: 22
- distance_to_ub min/p10/p25/p50/p75/p90/max: 0.0000 / 0.0000 / 0.0000 / 362.7433 / 565.9255 / 1135.6939 / 1252.9474

## Correlations
- corr(log_distance_to_ub, educ_years): -0.0371
- corr(log_distance_to_ub, parent_educ_mean): -0.2402
- corr(log_distance_to_ub, lwage): -0.1061

## Birth-aimag Diagnostics
- deterministic by birth_aimag: TRUE
- Aimag-level threshold means there are limited unique values; this is a limitation, not an error.

## Decision
Safe to proceed to Stage 19B log_distance_to_ub threshold preparation/estimation.

## Warnings / Limitations
- `log_distance_to_ub` has birth-aimag-level variation only.
- It has limited unique values relative to individual-level q_school_access.
- It may capture broad regional/remoteness differences rather than a narrow school-access channel.
- It must not be used as an instrument in this design.


