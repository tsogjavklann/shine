# Instrumental Forest Exploratory Heterogeneity Analysis

Generated: 2026-04-28 14:44:05.877517

## Design

- Outcome: `lwage`.
- Endogenous regressor: `educ_years`.
- Instrument: `parent_educ_mean`.
- Features: age, gender, marital status, urban status, student-teacher ratio, school access, birth aimag, birth cohort, and survey wave.
- This is an exploratory heterogeneity map, not a replacement for the main IV-threshold model.

## Main Outputs

- Sample size: 3188.
- Number of trees: 2000.
- Mean predicted local IV return: 11.35%.
- Median predicted local IV return: 10.58%.
- 10th-90th percentile range: 6.92% to 16.84%.

## Threshold-Regime Comparison

# A tibble: 2 × 8
  threshold_regime     N mean_tau_log mean_return_pct median_student_teacher_r…¹
  <chr>            <int>        <dbl>           <dbl>                      <dbl>
1 Доод STR регим    1051        0.112            12.0                       17.8
2 Дээд STR регим    2137        0.104            11.0                       22.6
# ℹ abbreviated name: ¹​median_student_teacher_ratio_17_18
# ℹ 3 more variables: urban_share <dbl>, female_share <dbl>, mean_age <dbl>

## Interpretation For The Report

The main IV-threshold regression tests whether returns differ across a specific school-environment threshold. The Instrumental Forest exercise asks the related question in a more data-driven way: do predicted IV returns vary across observed characteristics without forcing all heterogeneity into one pre-selected split? The results should be presented as exploratory evidence of heterogeneity, because the exclusion restriction for parental education remains a substantive identifying assumption.

## Suggested Mongolian Wording

Үндсэн ХХБР загвар боловсролын өгөөж 17-18 насны сурагч-багшийн харьцааны босгоор ялгаатай эсэхийг шалгасан бол нэмэлтээр Instrumental Forest аргыг ашиглан өгөөжийн ялгаатай байдлыг урьдчилан нэг босго оноохгүйгээр, өгөгдөлд суурилсан эрэл хайгуулын байдлаар үнэлэв. Энэхүү шинжилгээ нь үндсэн шалтгаант дүгнэлтийг орлохгүй, харин боловсролын өгөөжийн ялгаатай байдал сургуулийн орчин, бүс нутаг, хувь хүний шинжүүдтэй хэрхэн хавсарч байгааг дүрслэх зорилготой.

## Files

- `output/tables/T16_instrumental_forest_summary.csv`
- `output/tables/T16_instrumental_forest_tau_quartiles.csv`
- `output/tables/T16_instrumental_forest_threshold_regimes.csv`
- `output/tables/T16_instrumental_forest_variable_importance.csv`
- `output/figures/instrumental_forest_tau_distribution.png`
- `output/figures/instrumental_forest_tau_by_student_teacher_ratio.png`
- `output/figures/instrumental_forest_variable_importance.png`
