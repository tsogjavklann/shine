# НҮТС өгөгдлийг энэ судалгаанд ашиглах боломжийн дүгнэлт

Generated: 2026-04-27

## Гол дүгнэлт

НҮТС/SISS 2013, 2018, 2023 өгөгдлийг энэ төслийн үндсэн цалин-өгөөжийн регрессийн гол sample-д шууд нийлүүлэх нь тохиромжгүй. Учир нь одоогийн гол outcome нь HSES 2020-2024 дээрх 25-60 насны цалинтай ажиллагчдын `lwage`, харин НҮТС нь хүүхэд, өрх, эмэгтэй/эрэгтэй 15-49 насны олон үзүүлэлттэй cross-section судалгаа бөгөөд HSES-ийн хувь хүнтэй individual-level холбоос байхгүй.

Гэхдээ НҮТС-ийг ашиглавал судалгаанд бодит давуу тал нэмнэ: гол үр дүнгийн ард буй механизм, school-supply threshold-ийн construct validity, parental education/family background-ийн external benchmark, болон appendix robustness-ийг хүчтэй болгоно. Иймээс НҮТС-ийг main causal design биш, auxiliary validation/mechanism evidence байдлаар ашиглахыг зөвлөж байна.

## Төслийн одоогийн байдал

- Үндсэн судалгааны outcome: `lwage`.
- Гол regressor: `educ_years`.
- Одоогийн ажиллаж буй илүү тогтвортой IV: `parent_educ_mean`.
- Threshold variable-ийн хамгийн сүүлийн pipeline: `student_teacher_ratio_avg_16_18`.
- Сүүлийн pipeline-ийн sample: N = 3,113; parent education first-stage F = 427.24; OLS beta = 0.0468; 2SLS beta = 0.1057.
- Threshold heterogeneity evidence нь болгоомжтой: `beta_high - beta_low = 0.0224`, percentile CI zero агуулаагүй боловч centered bootstrap p-value = 0.1103.

Энд НҮТС хамгийн сайн нэмэх зүйл нь “яагаад student-teacher ratio / school environment wage return-ийг өөрчилж болох вэ?” гэдэг механизмын нотолгоо.

## НҮТС өгөгдлийн inventory

Local files:

| Wave | File | Rows | Columns | Useful modules |
|---|---:|---:|---|
| 2013 | `Household list.sav` | 50,973 | 71 | household roster, education, parents, wealth |
| 2013 | `Household.sav` | 15,500 | 167 | household characteristics, wealth |
| 2013 | `Women.sav` | 13,457 | 574 | women 15-49, education, fertility |
| 2013 | `Men.sav` | 6,883 | 237 | men 15-49, education |
| 2013 | `Child.sav` | 6,137 | 350 | under-5 child outcomes |
| 2018 | `2. Household List.sav` | 49,839 | 67 | roster education, parents, wealth |
| 2018 | `8. Child age 5-17.sav` | 7,628 | 275 | school attendance, child labour, parental involvement, foundational learning |
| 2023 | `hl - MN.sav` | 43,940 | 70 | roster education, parents, wealth |
| 2023 | `fs - MN.sav` | 6,868 | 385 | 5-17 child outcomes, foundational learning, child labour, parental involvement |
| 2023 | `ftu - MN.sav` | 26,987 | 45 | child time use |
| 2023 | `hh - MN.sav` | 13,850 | 212 | household characteristics, wealth |
| 2023 | `wm - MN.sav` | 9,788 | 446 | women 15-49, education, employment/training modules |

Important variables observed:

- Education roster: `ED4`, `ED5A`, `ED5B`, `ED6`, `ED9`, `ED10A`, `ED10B`, `ED15`, `ED16A`, `ED16B`.
- Parent links/background: `MLINE`, `FLINE`, `melevel`, `felevel`, `helevel`.
- Wealth: `wscore`, `windex5`, `windex10`, urban/rural wealth scores.
- Geography/design: `HH1`, `HH2`, `HH6`, `HH7`, `HH7A`/`province`, `area`, survey weights.
- 5-17 module: `CL*` child labour, `PR*` parental/school involvement, `FL*` foundational learning, `FSAGE`, `fselevel`, `fsweight`.

## Recommended use cases

### 1. Mechanism/validation section: school environment and learning

Build province/region by survey-year indicators from 2018 and 2023 child 5-17 modules:

- current school attendance: `ED9`;
- education level/grade: `ED10A`, `ED10B`, `fselevel`;
- foundational reading/math proxy: `FL*`, especially `FL14` and related items;
- parental school involvement: `PR3`, `PR5`, `PR6`, `PR7`-`PR11`;
- child labour/time burden: `CL1A`, `CL3`, `CL7`, `CL8`;
- wealth quintile: `windex5`.

Then compare these aggregates with the project’s school-supply measures (`student_teacher_ratio`, schools/students, teachers/students) at matching province/region and year. This would not prove causality, but it tests whether the threshold variable is actually associated with observed learning environment and child constraints.

Recommended output:

- Appendix table: `student_teacher_ratio` vs MICS/SISS school attendance, foundational learning, child labour.
- Scatter plot: province-level student-teacher ratio against foundational learning/attendance.
- Short text: “The wage-return heterogeneity threshold is consistent/inconsistent with contemporaneous child learning-environment gradients.”

### 2. External benchmark for parental education IV

The current strongest IV is `parent_educ_mean`, but its exclusion restriction is conceptually fragile because parental education affects networks, ability formation, aspirations, and family resources. НҮТС cannot fix that, but it can benchmark:

- distribution of father/mother education by cohort/region/wealth;
- correlation between parent education and child school attendance/learning;
- whether HSES co-resident parent education sample looks selective relative to НҮТС roster patterns.

This is useful for reviewer defence: it shows the paper is honest about family-background channels and does not oversell parental education as cleanly exogenous.

### 3. Wealth and household environment as heterogeneity descriptors

НҮТС has harmonized wealth index variables (`wscore`, `windex5`) and household services. These are valuable for descriptive heterogeneity:

- rural/urban wealth gradient in school attendance and learning;
- whether crowded-school regions are also poorer or more rural;
- whether threshold regimes differ in household environment.

This should stay as descriptive/context evidence, because HSES wage sample cannot be individually assigned an exact НҮТС household wealth score.

### 4. Possible but lower-priority: non-wage adult outcomes

Women/men files include adult 15-49 education and some employment/training-related modules. They can support a side appendix on education and non-wage outcomes, but this is not as valuable as the child-learning mechanism because:

- wage outcome is not comparable to HSES hourly wage;
- age coverage is 15-49, not the same 25-60 wage sample;
- it risks distracting the paper from returns-to-schooling.

## What not to do

- Do not merge НҮТС individuals into the HSES wage sample as if they are the same people.
- Do not use НҮТС 2023 child outcomes as childhood exposure for current HSES adult workers; the timing is wrong for most adult cohorts.
- Do not introduce НҮТС variables into the main 2SLS/IVTR table unless the merge level and interpretation are explicitly aggregate/proxy-based.
- Do not claim НҮТС validates causal wage returns; it validates mechanisms and measurement plausibility.

## Best implementation plan

Add one script:

`R/25_siss_external_validation.R`

Responsibilities:

1. Read SISS/NUTS 2013, 2018, 2023 `.sav` files with `haven`.
2. Harmonize keys: survey year, region, aimag/province where available, area, weights.
3. Create child education indicators:
   - attendance/enrolment;
   - grade/level progression or over-age proxy;
   - foundational reading/math indicators from `FL*`;
   - child labour/time burden from `CL*`;
   - parental involvement from `PR*`.
4. Aggregate to `aimag/province x area x survey_year` when possible; otherwise `region x area x survey_year`.
5. Merge with `data/cleaned/school_supply_panel.rds` or `data/auxiliary/school_density_by_aimag.csv`.
6. Export:
   - `output/tables/T12_siss_external_validation.csv`;
   - `output/figures/siss_school_environment_validation.png`;
   - `output/reports/siss_external_validation_summary.md`.

## Recommended framing in the paper

Use wording like:

“Because the wage sample itself cannot observe respondents’ childhood learning environment in detail, we use Mongolia’s Social Indicator Sample Surveys as an external validation exercise. The exercise does not enter the causal wage-return specification; instead, it tests whether the school-supply threshold used in the HSES analysis is aligned with independently observed child education, learning, and household-background gradients.”

## Bottom-line answer

НҮТС-ийг ашиглах нь нэмэлт давуу талтай. Гэхдээ давуу тал нь main causal estimate-ийг “илүү causal” болгохдоо биш, харин:

- threshold variable-ийн утга агуулгыг хамгаалах;
- mechanism story нэмэх;
- parent education IV-ийн сул талыг ил тод benchmark хийх;
- судалгааг илүү үнэмшилтэй, reviewer-д хамгаалахад хялбар болгох;
- appendix/robustness хэсгийг баяжуулахад оршино.

Тиймээс зөв шийдэл: НҮТС-ийг үндсэн HSES regression-д хүчээр оруулахгүй, харин external validation + mechanism evidence хэлбэрээр нэмэх.

## Sources checked

- Local data: `data/НҮТС-2013`, `data/НҮТС-2018`, `data/НҮТС-2023`.
- Local metadata: `data/НҮТС-2023/DDI-MNG-NSO-MN-SISS-2023-v1.0.xml`.
- UNICEF Mongolia, “Нийгмийн үзүүлэлтийн түүвэр судалгаа - 2023”: https://www.unicef.org/mongolia/mn/reports/нийгмийн-үзүүлэлтийн-түүвэр-судалгаа-2023
- NSO NADA metadata, “НҮТС - 2023”: https://nada.nso.mn/mn/index.php/catalog/121


