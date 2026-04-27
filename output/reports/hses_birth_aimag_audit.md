# HSES birth_aimag Audit

Generated: 2026-04-27 02:42:55.629525

## Construction Source
- 2020, 2021, 2022: birth-place raw aimag source is `q0114a`; birth-place raw soum source is `q0114b`.
- 2024: birth-place raw aimag source is `q0118a`; birth-place raw soum source is `q0118b`.
- If the respondent reports being born in the current place (`q0113 == 1` in 2020-2022; `q0117 == 1` in 2024), `birth_aimag` is filled from household/current `newaimag`.
- This means some `birth_aimag` values equal current aimag by construction, but only when the birth-in-current-place question says so.

## Key Result
- processed_differs_expected total: 0
- analysis_sample rows: 43070

## Files
- `output/tables/T9_hses_birth_aimag_source_labels.csv`
- `output/tables/T9_hses_birth_aimag_raw_harmonized_audit.csv`
- `output/tables/T9_hses_birth_aimag_analysis_sample_audit.csv`
- `output/tables/T9_hses_birth_aimag_ivtr_sample_audit.csv`
- `output/tables/T9_hses_birth_aimag_mismatches.csv`
