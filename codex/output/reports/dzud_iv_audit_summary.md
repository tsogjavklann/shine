# Dzud IV Audit Summary

## Data Files Used
- HSES individual analysis data: `C:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/shine/data/processed/analysis_sample.rds`
- Livestock count XLSX: `C:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/shine/data/МАЛЫН ТОО, малын төрөл, аймаг, нийслэл, жилээр.xlsx`
- Livestock mortality XLSX: `C:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/shine/data/ТОМ МАЛЫН ЗҮЙ БУС ХОРОГДОЛ, малын төрөл, аймаг, нийслэл, жилээр.xlsx`

## Sample Size
- Clean HSES wage-earner sample with matched birth aimag: 18216
- Main age 12-17 complete-exposure rows: 11418

## Main Corrected FE Results
- FE: birth_aimag + birth_cohort + wave
| IV | pi_hat | p | F_first | beta_2SLS | se_2SLS | N | verdict |
|---|---:|---:|---:|---:|---:|---:|---|
| dzud_cum_12_17 | 0.0049 | 0.0366 | 4.983 | -0.0515 | 0.0940 | 11418 | WRONG_SIGN |
| dzud_p75_count_12_17 | 0.0597 | 0.0536 | 4.180 | -0.0089 | 0.0632 | 11418 | WRONG_SIGN |
| dzud_max_12_17 | 0.0046 | 0.1827 | 1.899 | -0.1090 | 0.1723 | 11418 | WRONG_SIGN |
| dzud_count5_12_17 | 0.0510 | 0.2475 | 1.415 | -0.0223 | 0.1161 | 11418 | WRONG_SIGN |
| dzud_any_dzud5_12_17 | 0.0789 | 0.3098 | 1.083 | 0.1839 | 0.2500 | 11418 | WRONG_SIGN |
| dzud_count10_12_17 | 0.0260 | 0.6017 | 0.281 | 0.1284 | 0.4268 | 11418 | WRONG_SIGN |

## Diagnostics
- Region + wave does not produce high diagnostic F in the main window.
- Sign flip indicates unstable mechanism and weak identification.
- Animal-specific IVs are not suitable as separate IVs due to multicollinearity; max pairwise correlation = 0.967.

## Final Verdict
- Reject as IV
- Reject dzud as primary IV.
- Do not make causal IV claims from the dzud first stage.
