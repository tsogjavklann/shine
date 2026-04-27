# School-Supply IV Survey Summary

## Manual Excel Files Used
- `data/ЕРӨНХИЙ БОЛОВСРОЛЫН СУРГУУЛИЙН ТОО, аймаг, нийслэл, жилээр.xlsx`
- `data/ЕРӨНХИЙ БОЛОВСРОЛЫН СУРГУУЛЬД ӨДРӨӨР СУРАЛЦАГЧДЫН ТОО, аймаг, нийслэл, жилээр.xlsx`
- `data/ЕРӨНХИЙ БОЛОВСРОЛЫН СУРГУУЛИЙН ҮНДСЭН БАГШ, аймаг, нийслэл, жилээр.xlsx`
- `data/ХҮН АМЫН ТОО, хүйс, насны бүлэг, жилээр.xlsx`
- `data/ЖИЛИЙН ДУНДАЖ ХҮН АМЫН ТОО, аймаг, нийслэл, жилээр.xlsx`

## 1212 Verification Status
- See output/reports/manual_1212_excel_verification.md

## Year Coverage
- Schools: 2000-2025
- Students: 2000-2025
- Teachers: 2000-2025
- School-age population usable for aimag-level IV normalization: FALSE

## HSES Sample Size After Merge
- Main wage sample rows before IV-specific missingness: 18216
- HSES source: `./data/processed/analysis_sample.rds`

## Top 10 IV Candidates Under Corrected FE
- Corrected FE: birth_aimag + birth_cohort + wave
| IV | pi_hat | p | F_first | beta_2SLS | se_2SLS | N | sign_ok | verdict |
|---|---:|---:|---:|---:|---:|---:|---|---|
| student_teacher_ratio_at_12 | 0.04756 | 0.0040 | 10.446 | 0.0315 | 0.1066 | 5641 | FALSE | WRONG_SIGN |
| mean_student_teacher_ratio_age7_15 | 0.08130 | 0.0174 | 6.669 | 0.2543 | 0.1878 | 2095 | FALSE | WRONG_SIGN |
| teachers_per_student_at_12 | -18.62494 | 0.0295 | 5.455 | -0.0666 | 0.0996 | 5641 | FALSE | WRONG_SIGN |
| student_teacher_ratio_at_15 | 0.02377 | 0.0378 | 4.915 | 0.2163 | 0.0946 | 7862 | FALSE | WRONG_SIGN |
| school_closure_rate_at_15 | 1.08789 | 0.0896 | 3.168 | 0.0616 | 0.1041 | 7145 | FALSE | WRONG_SIGN |
| school_growth_rate_at_15 | -1.08789 | 0.0896 | 3.168 | 0.0616 | 0.1041 | 7145 | FALSE | WRONG_SIGN |
| student_teacher_ratio_at_17 | 0.01381 | 0.1764 | 1.957 | 0.0421 | 0.0743 | 9077 | FALSE | WRONG_SIGN |
| school_closure_rate_at_12 | -0.73915 | 0.1783 | 1.940 | 0.2434 | 0.1891 | 4910 | TRUE | WEAK |
| school_growth_rate_at_12 | 0.73915 | 0.1783 | 1.940 | 0.2434 | 0.1891 | 4910 | TRUE | WEAK |
| mean_teachers_per_student_age7_15 | -15.78987 | 0.1796 | 1.928 | 0.1112 | 0.2032 | 2095 | FALSE | WRONG_SIGN |

## Recommended IV
- No school-supply IV is viable under corrected FE.

## Warnings And Limitations
- Raw school, student, and teacher counts were not used as main IVs.
- National age-group population is not aimag-level, so school-age population normalization was not used.
- IV-specific N is limited by school-supply year coverage and birth-year exposure timing.
- Do not recommend any IV with wrong corrected-FE sign or F driven only by region + wave.
