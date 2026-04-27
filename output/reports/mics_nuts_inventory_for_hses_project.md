# NUTS/MICS Inventory for HSES Returns-to-Education Project

Generated: 2026-04-27 10:21:45.886986

## Local Data Found
- Local MICS/NUTS .sav files found: 18
- Survey folders: НҮТС-2013, НҮТС-2018, НҮТС-2023

## Main Relevant Families
- wealth_assets_housing: useful for household-environment/wealth-context proxies, but not directly linkable to adult HSES individuals.
- education_schooling: useful for validating school-access and youth schooling environment measures.
- parents_family: useful for validating family-background patterns, not for replacing the parent_educ_mean IV.
- demographics_geo_weights: needed to aggregate by region/urban/year and apply MICS weights.

## Econometric Recommendation
- Do not merge MICS microdata to HSES at the individual level; the samples contain different people.
- Use MICS as auxiliary/contextual data aggregated by region x urban/rural x survey year, or at broader region/year level if aimag is unavailable.
- Candidate contextual thresholds could include regional child household wealth index, housing deprivation, internet/computer access, school attendance, or child labour rates.
- These are contextual proxies, not individual childhood measures for HSES adults.
- Because HSES adults in the wage sample are mostly born before the MICS child cohorts, MICS is better for external validation and current/period context than exact childhood exposure.

## Output Tables
- output/tables/T12_mics_nuts_variable_inventory.csv
- output/tables/T12_mics_nuts_file_summary.csv
- output/tables/T12_mics_nuts_family_summary.csv
- output/tables/T12_mics_nuts_candidate_variables.csv
