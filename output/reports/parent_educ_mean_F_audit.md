# parent_educ_mean First-Stage F Audit

Generated: 2026-04-26 21:47:30.720774

## Construction Trace
- `parent_educ_mean` was reconstructed only from `father_educ_years` and `mother_educ_years`.
- Formula: `rowMeans(cbind(father_educ_years, mother_educ_years), na.rm = TRUE); NaN -> NA`.
- Source file for parent variables: `data/processed/family_structure.rds`.
- Uses `educ_years`: FALSE
- Reconstructed values match IVTR-ready `parent_educ_mean`: TRUE

## Sample
- Audit sample N: 3188
- IVTR-ready N: 3188

## Correlations
- corr(educ_years, parent_educ_mean): 0.3467
- corr(educ_years, mother_educ_years): 0.3356
- corr(educ_years, father_educ_years): 0.2949
- corr(mother_educ_years, father_educ_years): 0.5246

## First-Stage F Audit
- no weights, robust SE: coef=0.3477, SE=0.0186, t=18.7300, t^2/Wald F=350.8147
- weights, robust SE: coef=0.3623, SE=0.0211, t=17.1502, t^2/Wald F=294.1284
- weights, birth_aimag cluster: coef=0.3623, SE=0.0153, t=23.6316, t^2/Wald F=558.4505, fixest ivf1 F=477.9033

- Reported F=602.23 matches manual cluster t^2: FALSE
- Reported F=602.23 matches fixest ivf1 F: FALSE

## Verdict
F is genuine; proceed to IVTR, but keep exclusion caveat.

## Caveat
Parent education may affect wages through family background, networks, and unobserved ability channels.
