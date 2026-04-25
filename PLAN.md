# PLAN.md — IV-Threshold шинжилгээний 4 долоо хоногийн ажлын төлөвлөгөө

**Сэдэв:** Монгол Улсад боловсролын бодит өгөөжийн босготой үнэлгээ — HSES 2020-2024 микро өгөгдөл, Caner & Hansen (2004) IVTR арга

**Багц:** R 4.4.x (tidyverse, fixest, ivreg, AER, sandwich, lmtest, boot, sampleSelection, NSO1212/mongolstats, haven)

**Эх үндсэн шавхалт:** HSES 2020, 2021, 2022, 2024 (4 wave). **2023 wave хасагдсан** — энэ нь labour-force-only sub-sample бөгөөд education (q0210, q0213), birth_aimag (q0114a/q0118a), wage decomposition (q0436a/b, q0427, q0437-9) variables-уудыг агуулдаггүй (R/02 codebook verification дээр илэрсэн). **main_sample (25-60 нас)** ба **alt_sample (22-60 нас, robustness)** хоёулангийн final N эмпирикээр `R/07_merge_final.R`-д тогтоогдоно. R/02_import-ийн inventory: **pre-filter individual-row counts** (бүх нас, цалинтай эсэх hасаагүй): 2020 ≈ 59,737; 2021 ≈ 40,129; 2022 ≈ 80,926; 2024 ≈ 53,898. **25-60 насны цалинтай subset** эмпирикээр R/07_merge_final.R-д тогтоогдоно (өмнөх 5-wave inventory-аас wage-panel ойролцоо тооцоо: 2020 ~ 11,143; 2021 ~ 6,771; 2024 ~ 10,325).

---

## 1. Эконометрик загвар

### 1.1 Үндсэн загварын тэгшитгэл

Mincer-ийн уламжлалт log-цалингийн тэгшитгэл:

ln(w_it) = α + β · educ_it + γ · X_it + μ_r + δ_t + ε_it      [1]

- **w_it: real hourly wage.** Nominal hourly wage нь §1.4-ийн **2-tier томъёогоор** тооцогдоно. Real hourly wage = nominal_hourly ÷ (CPI / 100), **CPI tier-аас хамаарна:** Tier 1 → annual-average CPI (2020 base); Tier 2 → previous-month CPI (2020 base).
- educ_it: schooling years
- X_it: age, age², gender, marital status, location (4-category), region FE μ_r, wave FE δ_t

**Two specifications-аар тайлагнана (location нь bad-control эрсдэлтэй):**
- **Main A** — demographic controls + region FE + wave FE (location-гүй; raw schooling-to-wage)
- **Main B** — Main A + location FE (residential sorting-д хяналттай)

Боловсрол → миграц → location гэсэн mediator path байж болзошгүй учир хоёр specification-ийг T2-д side-by-side тайлагнана. T6 col (8)-д Main B үндсэн дээр alt-thresholds харьцуулна.

**Wage construction-ийн дараалал:**
1. nominal_hourly — §1.4 дэх **2-tier тооцоо** (Tier 1 = q0436b (annual cash, "сүүлийн 12 сард") / (q0437×q0438×q0439); Tier 2 = q0436a (monthly cash, "сүүлийн сард") / (q0427 × 4.33) fallback)
2. real_hourly:
   - **Tier 1:** real_hourly = q0436b / annual_hours / (cpi_annual_avg_2020 / 100)
   - **Tier 2:** real_hourly = q0436a / (q0427 × 4.33) / (cpi_prev_month_2020 / 100)
3. lwage = ln(real_hourly)
4. β-ийг "real return per year of schooling" гэж тайлбарлана

**CPI эх үүсвэрийн дараалал:** (1) NSO1212 API-аас аймаг × сар түвшний CPI series; (2) олдохгүй бол улсын нийт CPI сар тус бүрд (downgrade 1); (3) улсын CPI жилийн дундаж (downgrade 2); (4) бүгд бүтэхгүй бол гарын CSV fallback (`data/aux/cpi_manual.csv`).

### 1.2 Endogeneity ба IV

Educ_it endogenous → 2004 онд эхэлсэн **11 жилийн тогтолцооны (10 → 11 жил шилжилт)** шинэчлэлийн exposure-ийг IV болгоно. Cutoff cohort-ийн эргэн тойронд (1996, 1997) **donut design** ашиглана — энэ хоёр оны cohort-ыг үндсэн шинжилгээнээс хасч partial-treatment ambiguity-аас зайлсхийнэ.

**Үндсэн IV — `reform_main` (donut design):**

- Z_i = 1 хэрэв төрсөн он ≥ **1998**
- Z_i = 0 хэрэв төрсөн он ≤ **1995**
- Z_i = NA (sample-аас хасна) хэрэв төрсөн он ∈ {1996, 1997}

**Robustness IV — `reform_fuzzy` (T6-д харьцуулах):**

- Z_i = 0   хэрэв төрсөн он ≤ 1995
- Z_i = 0.5 хэрэв төрсөн он ∈ {1996, 1997} (partial exposure)
- Z_i = 1   хэрэв төрсөн он ≥ 1998

**First stage:** educ_it = π₀ + π₁ · Z_i + γ · X_it + FE + v_it      [2]

**Alternative cutoffs (robustness, эх сурвалжийн зөрөөг шалгах):**

2004 reform-ийн эхэлсэн он эх сурвалжаас хамаарч 1997-1999 хооронд тодорхой бус (Asian Development Bank vs ReviewSep зэрэг эх сурвалжуудын зөрөө). Энэ түүхэн тодорхойгүй байдлыг шалгах үүднээс **alternative IV cutoff** хувилбаруудыг үүсгэнэ:

- `reform_alt_1997`: Z=0 if birth ≤ 1994, Z=1 if birth ≥ 1997, NA if 1995-1996
- `reform_alt_1999`: Z=0 if birth ≤ 1996, Z=1 if birth ≥ 1999, NA if 1997-1998

`R/06_iv_construction.R`-д **4 IV хувилбар** үүсгэгдэнэ: `reform_main`, `reform_fuzzy`, `reform_alt_1997`, `reform_alt_1999`. Үндсэн загварт `reform_main`, T6 col (4)-д `reform_alt_1997`, T6 col (4b)-д `reform_alt_1999`, T6 col (5)-д `reform_fuzzy` хэрэглэнэ.

**Caveat — first-stage strength нь main empirical risk:** 2004 reform-treated cohort (1998+ онд төрсөн) нь main 25-60 sample-д зөвхөн 2023, 2024 wave-д л 25-26 насны хэлбэрээр оршино. Энэ нь first-stage F-statistic-ийг дорой болгож магадгүй. Үүнийг шийдэх бэлэн стратеги:

1. **Alternative sample:** `R/07_merge_final.R`-д **age 22-60 alt_sample** үүсгэж treated cohort-ыг өргөтгөнө (R/19_subsample_iv.R-д T7-д тусгана)
2. `reform_alt_1997` cutoff нь treated cohort-ыг 27+ нас руу татна — main sample-д хүчтэйгээр харагдана
3. Weak-IV-robust estimator (LIML, Fuller-1) ба Anderson-Rubin CI-г үндсэн загварт хамт тайлагнана
4. F-statistic-уудыг (KP, AR p-value, AR CI) `iv_diagnostics.log`-д бүрэн log-лоно

### 1.3 Caner-Hansen (2004) IV-Threshold

Босгот хувьсагч q_i = school_access_i — тухайн хүний 6-17 нас байхад **төрсөн аймгийнхаа** ЕБС-ийн нягтралын **12 жилийн дундаж**:

q_i = (1/12) × Σ_{t = birth_year+6}^{birth_year+17} school_density_{home_aimag, t}      [3a]

**Үндсэн `school_density` тодорхойлолт:**

school_density_{a,t} = ЕБС_тоо_{a,t} / (сурагч_тоо_{a,t} / 1000)      [3b]

(нэгж: 1000 сурагчид ногдох ЕБС-ийн тоо; "schools per 1000 students" а аймагт, t онд). Энэ нь Card (2001), Duflo (2001) loa-аар education supply / access-ийн **proxy** хэмжүүр.

**Тайлбар (proxy caveat):** school_density (schools per 1000 students) нь education supply / access-ийн **PROXY** бөгөөд direct measure of distance-to-school БИШ. Энэ хэмжүүр нь сургуулийн хэмжээ, хүн амын тархалт, аймгийн sparsity-ийг хольсон complex measure юм. Threshold interpretation-ыг үүний дагуу болгоомжтой ойлгоно.

Бусад тодорхойлолтууд (teacher density, student-teacher ratio, ЕБС-ийн дундаж хэмжээ) нь **§4.1 alt thresholds-д** үлдэнэ — education supply-ийн өөр өөр facet-уудыг тусгана.

**Aimag хувьсагч (childhood schooling environment proxy):**

R/02 codebook verification (n=85K of 235K row-level coverage = ~26%) дээр илрүүлэгдсэнээр:

- **2020-2022 wave:** birth_aimag = `q0114a` ("[НЭР] хаана төрсөн бэ? Аймаг")
- **2024 wave:** birth_aimag = `q0118a` (асуулт 1.18 руу шилжсэн, ижил утгатай)
- **2023 wave:** N/A (entire wave хасагдсан — §header)

**Caveat (measurement error):** birth_aimag ≠ 6-17 насанд амьдарсан газар. Хүүхэд ахуйн миграц байсан хүмүүст energy байж болзошгүй; threshold inteprretation-ыг proxy гэж ойлгоно.

**Хосолсон стратеги (R/05_education_supply.R-д шийдэгдэнэ):**

1. **MAIN MODEL:** birth_aimag-ийн available subsample (~26% × wage panel) — Card (2001) / Duflo (2001) cleanest "childhood school access" identification. N бага → Anderson-Rubin CI онцгой чухал
2. **ROBUSTNESS T6 col (7):** newaimag (current residence) full sample — migration noise-той, "current-residence supply" interpretation. Хоёрын зөрөөг paper-д "migration selection sensitivity" гэж тусгана

**Empirically determined fallback rule** (R/05-д бичигдэнэ, log-д тэмдэглэгдэнэ):

- Хэрэв home_aimag wage-panel N **≥ 10,000:** home_aimag MAIN, newaimag robustness (recommended)
- Хэрэв N **< 10,000 ба ≥ 5,000:** decision-ыг хэрэглэгчээс асууна (RESULTS_LOG.md checkpoint)
- Хэрэв N **< 5,000:** home_aimag-аар threshold estimation хүрэлцэхгүй → newaimag MAIN, home_aimag subsample robustness; identification claim "supply-side proxy at current residence"-ээр soft-болгоно

**Threshold загвар:**

ln(w_it) = (α₁ + β₁ · educ_it + γ₁ · X_it) · 1{q_i ≤ γ}
         + (α₂ + β₂ · educ_it + γ₂ · X_it) · 1{q_i > γ}
         + ε_it                                                     [3]

- 2-step GMM: (i) reduced-form residual-аар threshold γ хайх, (ii) **interaction-based pooled IVTR fit (sample split БИШ)**
- Bootstrap p-value (1000 replication, parallel-ize-сан) — threshold-effect H₀: нэг регим vs threshold
- γ-ийн 95% CI: **Hansen (2000) inverted LR statistic** (BCa CI нь optional, гол биш — γ-ийн distribution nonstandard)

**Implementation (R, fixest — interaction-based pooled IVTR):**

```r
# γ̂ хайсны дараа:
df <- df |>
  mutate(
    regime_low  = as.integer(q <= gamma_hat),
    regime_high = as.integer(q >  gamma_hat),
    D1 = educ * regime_low,    # low-regime endogenous
    D2 = educ * regime_high,   # high-regime endogenous
    Z1 = reform * regime_low,  # low-regime instrument
    Z2 = reform * regime_high  # high-regime instrument
  )

feols(lwage ~ controls_X * regime_high | region + wave |
        D1 + D2 ~ Z1 + Z2,
      weights = ~hhweight,
      cluster = ~aimag + wave,
      data = df)
```

β₁, β₂ нь D1, D2-ийн coefficient. Wald test: H₀ β₁ = β₂. **Sample split нь threshold parameter inference-ийг эвдэх учир ашиглахгүй.**

### 1.4 Hourly wage-ийн нарийвчилсан тооцоо (tier-аар)

HSES 2020-2024 codebook-ийн дагуу Q4.36 нь sub-part хэлбэртэй (А=сүүлийн сард, Б=сүүлийн 12 сард — q0212a/b, q0209a/b-тэй ижил pattern). Тиймээс **hourly wage-ийг 2-tier хэлбэрээр** тооцоолно (хоёулаа 2020-2024 main sample-д хүчинтэй):

**Tier 1 (тэргүүн сонголт, full annual decomposition):**

- q0436b = жилийн нийт мөнгөн орлого үндсэн ажлаас (annual cash earnings, MNT, "Б. Сүүлийн 12 сард")
- q0437 = жилд хэдэн сар ажилласан (months/year, ердийн утга 1-12)
- q0438 = сард хэдэн өдөр (days/month, ердийн утга 1-31)
- q0439 = өдөрт хэдэн цаг (hours/day, ердийн утга 1-24)

annual_hours = q0437 × q0438 × q0439
hourly_nominal = q0436b / annual_hours      [4a]

**Tier 2 (fallback, q0437/q0438/q0439-ийн аль нэг NA бол):**

- q0436a = өнгөрсөн сард авсан үндсэн цалин (monthly cash, MNT, "А. Сүүлийн сард")
- q0427 = сүүлийн 7 хоногт үндсэн ажилд зарцуулсан цаг (hrs/week)

monthly_hours_approx = q0427 × 4.33      (4.33 ≈ 52 / 12)
hourly_nominal = q0436a / (q0427 × 4.33)      [4b]

`R/04_wage_construction.R`-д `wage_method` багана нэмж аль арга ашигласнаас сонгож тэмдэглэнэ (tier1 / tier2); T1 descriptive-д tier-аар хуваарилалт тайлагнагдана.

### 1.5 Identification таамаглалууд

- Z_i ⊥ ε_it | X_it (cohort exposure нь genuine-хэн exogenous)
- school_access_i нь хүүхэд ахуйд тогтсон, насанд хүрсний өгөөжтэй weak-correlation
- Threshold variable q_i exogenous (Caner-Hansen А1 шаардлага)

**Sampling weights (hhweight) — заавал ашиглах:** HSES survey-ийн нэгж жин (`hhweight`, basicvars-аас) нь бүх OLS, 2SLS, IVTR loaded-д `weights = ~hhweight` хэлбэрээр заавал орно (population-representative point estimates). Unweighted regression-уудыг T6-д sensitivity column нэмж тайлагнана (R/18c_unweighted.R).

### 1.6 Cluster-robust standard error-ийн стратеги

Бүх OLS, 2SLS, IVTR үнэлгээнд **two-way cluster-robust SE**-г стандарт болгоно. Энэ нь aimag-цохилт болон wave-цохилт хоёр түвшний correlation-ийг зэрэг хүлээн зөвшөөрнө.

- **Cluster level:** `aimag` (cross-section) **ба** `wave` (time) — fixest нотацид `cluster = ~aimag + wave` (жинхэнэ two-way clustering; `^`-тэй бичих нь interaction cluster болж буруу унших)
- **Хэрэгжүүлэлт (R) — weights = ~hhweight ЗААВАЛ:**
  ```r
  feols(lwage ~ educ + age + age2 + ... | region + wave,
        weights = ~hhweight,
        cluster = ~aimag + wave, data = df)

  feols(lwage ~ ... | region + wave | educ ~ Z, # 2SLS
        weights = ~hhweight,
        cluster = ~aimag + wave, data = df)
  ```
- **Регим бүрт IVTR-д:** subset feols-ийг ижил `cluster = ~aimag + wave`-аар үнэлнэ; threshold-аар хуваагдсан хоёр sample дээр degrees-of-freedom-ийн засвартай (`dof = dof(adj = TRUE, cluster.adj = TRUE)`)
- **Сонголтот шалгалт:** one-way (зөвхөн `~aimag`) ба two-way SE-ийг хооронд нь `iv_diagnostics.log`-д тусгаж эх эх SE-ийн strait-ийг тогтоо
- **Шалтгаан:** Cohort exposure нь aimag-аар жигд бус roll-out хийгдсэн; оны wage shocks (CPI, FX, COVID) бүх aimag-д ижил нөлөөлсөн → хоёр түвшинд серийн correlation байна гэсэн a priori үндэслэлтэй
- **Caveat (few-cluster bias):** Wave dimension-д зөвхөн **4 cluster** (2020, 2021, 2022, 2024 — 2023 хасагдсан) байгаа учир Cameron & Miller (2015), MacKinnon & Webb (2017)-ийн дагуу two-way clustering нь tail behavior-д sensitivity-тэй. Тиймээс sensitivity check болгож **3 SE-ийг нэгэн зэрэг тайлагнана:**
  - Main: `cluster = ~aimag + wave` (two-way)
  - Sensitivity 1: `cluster = ~aimag` (one-way)
  - Sensitivity 2: HC3 robust (heteroskedasticity-only)
  Гурвын зөрүүг `iv_diagnostics.log`-д тэмдэглэнэ. Хэрэв тэдгээр SE-уудын зөрөө >2× бол paper-д "few-cluster bias-ийн caveat" нэмж бичинэ

---

## 2. Долоо хоногийн ажлын дараалал

### Долоо хоног 1 — Өгөгдлийн бэлтгэл (2026-04-26 → 05-02)

**Гарц:** clean panel `data/processed/hses_pooled_2020_2024.rds`

| # | Скрипт | Нэр | Гарц |
|---|---|---|---|
| 1.1 | `R/01_setup.R` | Pkg суулгах, lib() helper, paths.R үүсгэх | session ready |
| 1.2 | `R/02_import_hses.R` | 5 wave × 3 файл (basicvars, hhold, indiv) → raw_list | `data/raw/hses_raw.rds` |
| 1.3 | `R/03_harmonize.R` | Хувьсагчийн нэр, кодлогдсон утгыг waves хооронд нэгтгэх (educ, age, sex, marital, location, aimag, urban_rural, region) | `data/processed/hses_harmonized.rds` |
| 1.4 | `R/04_wage_construction.R` | **Nominal hourly wage** 2-tier тооцоо: Tier 1 = q0436b (annual) / (q0437×q0438×q0439); Tier 2 (fallback) = q0436a (monthly) / (q0427 × 4.33); `wage_method` багана нэмэх; filter (working_for_wage=1, 22-60 нас — main_flag=1 if 25-60); ln(nominal_hourly) | `data/processed/wage_nominal.rds` |
| 1.4b | `R/04b_cpi_deflator.R` | NSO1212 API-аас CPI series татах (тэргүүн: аймаг × сар; fallback: улсын сар; downgrade улсын жил; manual CSV); **суурь 2020 = 100**-аар rebase; **ХОЁР CPI series үүсгэнэ:** (a) `cpi_annual` — aimag × year (Tier 1 q0436b annual deflation-д); (b) `cpi_monthly` — aimag × (year, month-1) (Tier 2 q0436a previous-month deflation-д). Tier-аар сонголт: `wage_method == "tier1"` бол cpi_annual, `tier2` бол cpi_monthly | `data/aux/cpi_annual_2020base.rds`, `data/aux/cpi_monthly_2020base.rds`, `data/processed/wage_real.rds` |
| 1.5 | `R/05_education_supply.R` | NSO1212/mongolstats API-аас аймаг × жилийн ЕБС тоо, сурагчийн тоо, багшийн тоо татах; **home_aimag**-ийг q0118a-аар тэргүүн авах, NA бол newaimag-аар нөхөх; q_i = (1/12) × Σ school_density_{home_aimag, t}, t ∈ [birth_year+6, birth_year+17] | `data/aux/school_density_by_cohort.rds` |
| 1.6 | `R/06_iv_construction.R` | **4 IV хувилбар:** (a) `reform_main` (donut: Z=1 if birth ≥ 1998, Z=0 if ≤ 1995, NA if 1996-1997); (b) `reform_fuzzy` (0/0.5/1 partial); (c) `reform_alt_1997` (1997 cutoff); (d) `reform_alt_1999` (1999 cutoff); exposure_intensity (8-р анги хэдэн жилд хүрэх) | `data/processed/iv_assignment.rds` |
| 1.7 | `R/07_merge_final.R` | Бүх файл merge → **ХОЁР sample**: (a) `main_sample` age 25-60 (стандарт Mincer); (b) `alt_sample` age 22-60 (treated cohort-ыг өргөтгөх — first-stage strength sensitivity-д) | `data/processed/analysis_sample.rds` (нэг файл, `sample_flag` баганатай) |

**Acceptance (тооцоо амжилттай дууссан, бүх диагностик тайлагнагдсан):** Эцсийн analysis sample-ийн N эмпирикээр тогтоогдоно; reform_main, reform_alt_1997, reform_alt_1999, reform_fuzzy 4 IV-ийн 0/1 хуваарилалт T1-д тусгана; missing rate-уудыг тайлагнана (cutoff болгож drop хийхгүй); CPI series-ийн coverage 2019M12-аас 2024M12 хүртэлх period-д тулгуурлан logged; home_aimag coverage R/05-д бичигдэж, fallback стратегийг (§1.3-ийн дагуу) flag-лана

### Долоо хоног 2 — Diagnostics ба OLS-IV baseline (2026-05-03 → 05-09)

**Гарц:** `output/tables/T1_descriptive.csv`, `T2_ols_iv_main.csv`, `output/logs/iv_diagnostics.log`

| # | Скрипт | Нэр | Гарц |
|---|---|---|---|
| 2.1 | `R/08_descriptive.R` | T1: түүвэрийн mean/sd/median, by reform cohort | `output/tables/T1_descriptive.csv` |
| 2.2 | `R/09_balance_check.R` | Pre-trend, cohort balance (1990-1996 vs 1997-2003), **cohort density and composition check around reform cutoffs** (McCrary RD test нь birth-year manipulation боломжгүй учир invalid; харин раш cohort distribution-ийн uniformity-ийг визуал шалгалт) | `output/figures/F1_cohort_balance.png` |
| 2.3 | `R/10_ols_baseline.R` | Mincer OLS, **two-way cluster SE `~aimag + wave`**, region+wave FE; +sensitivity (drop urban-only, drop UB-only) | T2 col (1)-(3) |
| 2.4 | `R/11_iv_2sls.R` | 2SLS-аар [1]+[2]; **cluster `~aimag + wave` + weights `~hhweight`**; first-stage **Kleibergen-Paap rk Wald F (cluster-robust)**; **Anderson-Rubin (AR) weak-IV-robust CI — GOL inference**. Stock-Yogo critical нь homoskedastic assumption-той учир cluster-robust setting-д report хийхгүй. One-way vs two-way SE + HC3 хосыг log-д | T2 col (4)-(5), `iv_diagnostics.log` |
| 2.5 | `R/12_iv_robustness.R` | Limited info ML (LIML), Fuller-1, alternative IV (буфер cohort оруулах/орхих); бүгд `cluster = ~aimag + wave` | `output/tables/T3_iv_robustness.csv` |

**Acceptance (тооцоо амжилттай тайлагнагдсан, p-hacking-аас зайлсхийсэн):** OLS ба 2SLS coefficient-ууд cluster-robust SE-ийн хамт тайлагнагдана; first-stage F (Kleibergen-Paap), Stock-Yogo critical value, Anderson-Rubin CI, Durbin-Wu-Hausman endogeneity test бүгд `iv_diagnostics.log`-д бичигдэнэ. Үр дүнгийн чиглэл, хэмжээг **weak-IV diagnostics-ийн контекстэд тайлбарлана** — preset effect size-аар шүүхгүй.

### Долоо хоног 3 — IVTR үндсэн үнэлгээ (2026-05-10 → 05-16)

**Гарц:** `output/tables/T4_ivtr_main.csv`, `T5_threshold_ci.csv`, `output/figures/F2_threshold_lr.png`

| # | Скрипт | Нэр | Гарц |
|---|---|---|---|
| 3.1 | `R/13_threshold_grid.R` | school_access-ийн grid (5-95 percentile, 100 алхам); GMM Q(γ) function | `data/processed/threshold_grid.rds` |
| 3.2 | `R/14_caner_hansen_main.R` | IVTR γ̂ хайх; **interaction-based pooled fit** (D1/D2/Z1/Z2 §1.3-аар; **sample split БИШ**); cluster `~aimag + wave` + weights `~hhweight`; F-зурагт γ̂ дугуйлах. Sample split нь threshold parameter inference-ийг эвдэж магадгүй учир заавал interaction approach | T4, F2 |
| 3.3 | `R/15_threshold_bootstrap.R` | **1000 replication** бүхий wild bootstrap **threshold-effect H₀: нэг регим vs threshold** test-ийн p-value-нд зориулагдсан (γ-ийн CI энд биш — R/16-д inverted LR). `parallel::mclapply` (Linux/Mac) + `parallel::parLapply` (Windows fallback). **Convergence check:** effective_N = 1000 × accept_rate; accept < 0.5 бол `bootstrap.log`-д WARNING + STOP, хэрэглэгч `BOOTSTRAP_REPS=2000`-аар дахин ажиллуулна (manual approval) | T5, `output/logs/bootstrap.log` |
| 3.4 | `R/16_threshold_inverse_lr.R` | LR statistic inverted-с γ-ийн 95% CI | T5-нэмэлт мөр |
| 3.5 | `R/17_regime_table.R` | β₁, β₂, |Δβ|, Wald-тэст β₁ = β₂; T4 footer-т: "γ̂ CI: Hansen (2000) inverted LR (R/16); bootstrap p-value: threshold-effect test (R/15)" гэж тэмдэглэнэ | T4 footer |

**Acceptance (full reporting, suppression-гүй):** γ̂, β₁, β₂, |Δβ|, Wald test β₁=β₂, **bootstrap p-value (threshold-effect H₀ test, R/15)**, **Hansen (2000) inverted LR CI for γ̂ (гол inference, R/16)** бүгдийг тайлагнана. BCa CI optional sensitivity check, гол биш. γ̂ нь grid-ийн corner-т (5%/95%) бол warning тэмдэглэнэ. Sign болон significance-аас тайлбар үүднэ — preset direction-аар шүүхгүй.

### Долоо хоног 4 — Robustness, бичвэр (2026-05-17 → 05-23)

**Гарц:** `output/tables/T6_sensitivity.csv`, T7_subsamples.csv, **T8_heckman.csv**, `F3-F5`, `paper/draft.md`

| # | Скрипт | Нэр | Гарц |
|---|---|---|---|
| 4.1 | `R/18_alt_thresholds.R` | school_access орлуулах: (1) teacher density, (2) student-teacher ratio, (3) ЕБС хэмжээ, **(3a) PCA asset index**, **(3b) per-capita real consumption**; threshold үр дүнг харьцуулах | T6 col (1)-(3b) |
| 4.1b | `R/18b_nominal_wage_check.R` | **Nominal wage + wave FE** регресс — real-wage үндсэн үр дүнтэй харьцуулах. β_nominal vs β_real-ийн зөрүү тайлбарлагдана | T6 col (6) "nominal-FE" |
| 4.1c | `R/18c_unweighted.R` | **Unweighted vs weighted** regression — `weights = ~hhweight`-гүйгээр үндсэн загвар; weighted vs unweighted β зөрөө тайлбарлагдана | T6 col (6b) "unweighted" |
| 4.1d | `R/18d_aimag_robustness.R` | **newaimag full-sample** vs main home_aimag subsample; main vs newaimag-аар threshold үр дүн харьцуулагдана (migration selection sensitivity) | T6 col (7) "newaimag full" |
| 4.1e | `R/18e_main_b_location.R` | **Main B specification** — Main A (location-гүй) дээр location FE нэмэн (residential sorting-д хяналт) | T6 col (8) "Main B (loc FE)" |
| 4.2 | `R/19_subsample_iv.R` | Subsamples: gender, urban/rural, aimag-cluster sample size > 100, **age 22-60 alt_sample** (treated cohort-ыг өргөтгөх sensitivity); бүгд `cluster = ~aimag + wave` | T7 (col "age 22-60" нэмэгдсэн) |
| 4.3 | `R/20_alt_iv.R` | Орлуулах IV: (a) `reform_alt_1997` (cutoff 1997, T6 col 4); (b) `reform_alt_1999` (cutoff 1999, T6 col 4b); (c) `reform_fuzzy` (donut-гүй partial, T6 col 5); (d) 2008 **12 жилийн тогтолцоо** (11 → 12) — **caveat:** 2008 cohort нь 2024-д 22 настай учир labour-market exposure хязгаарлагдмал, **зөвхөн weak benchmark** | T6 col (4)-(5) |
| 4.3b | `R/20b_heckman.R` | **Heckman two-step selection.** Selection eq: `working_for_wage ~ age + age² + gender + marital + n_young_kids + region + wave` — **exclusion restriction = `n_young_kids`** (өрхийн 0-5 настай хүүхдийн тоо: labour-supply-д шууд нөлөөтэй, гэхдээ бүтээмжээр шууд нөлөөгүй; Mroz 1987 аргачлал). Outcome eq: ln(real_wage) + IMR + `gender × IMR` interaction. **ВАЖНО: Heckman correction нь wage-sample selection-д зориулагдсан, schooling endogeneity-г бүрэн засахгүй — IV estimates-ийг орлуулах биш, нэмэлт evidence**. λ-ийн significance + IMR-corrected β T8-д тусгана | `output/tables/T8_heckman.csv` |
| 4.4 | `R/21_placebo.R` | Placebo: 1985, 1992 онуудад жинхэнэ reform болоогүй; псевдо cutoff-оор `reform_placebo` үүсгэж first-stage болон IVTR ажиллуулна. **Лоджик:** жинхэнэ identification бол first-stage F < 5 ба IVTR threshold p > 0.20 байх ёстой (null result expected) | `output/logs/placebo.log` |
| 4.5 | `R/22_figures.R` | **F2 (улам сайжруулсан, double-panel — Hansen 2000 стандарт):** дээд panel = school_access histogram γ̂ нь босоо шугамтайгаар тэмдэглэгдсэн, доод panel = LR statistic curve 95% threshold zone-той; F3: regime-specific Mincer curve, F4: marginal effect at q, F5: IVTR vs OLS-Quantile compare | F2 (rebuild), F3-F5 |
| 4.6 | `R/23_tables_export.R` | T1-T8 LaTeX/Markdown export, decimal формат стандартчилах | `output/tables/all_tables.md` |
| 4.7 | `R/99_replication.R` | end-to-end replication entry-point | `R/99_replication.R` |

**Acceptance (full reporting, suppression-гүй):** Бүх alternative threshold + alt IV (1997, 1999, fuzzy, 2008) + nominal-FE + unweighted + newaimag full + Main B (location FE) үр дүн T6-д col 1-8-д бүгдээрээ тайлагнана; **placebo үр дүн (first-stage F, IVTR threshold p) suppression-гүй тайлагнагдана** (null result expected); Heckman λ-ийн significance + IMR-corrected β T8-д ("schooling endogeneity-г бүрэн засахгүй" caveat-тай); 2008 reform IV "weak benchmark"; figures 300 dpi; tables-ийг paper-д шууд оруулж болно

---

## 3. Гарцын хяналтын файл

```
output/
├── tables/
│   ├── T1_descriptive.csv
│   ├── T2_ols_iv_main.csv
│   ├── T3_iv_robustness.csv
│   ├── T4_ivtr_main.csv
│   ├── T5_threshold_ci.csv
│   ├── T6_sensitivity.csv
│   ├── T7_subsamples.csv
│   └── T8_heckman.csv
├── figures/
│   ├── F1_cohort_balance.png
│   ├── F2_threshold_lr.png
│   ├── F3_regime_mincer.png
│   ├── F4_marginal_at_q.png
│   └── F5_ivtr_vs_quantile.png
└── logs/
    ├── iv_diagnostics.log
    ├── bootstrap.log
    └── placebo.log
```

---

## 4. Эрсдэл ба урьдчилан шийдэх асуудлууд

| Эрсдэл | Магадлал | Үр дагавар | Шийдэл |
|---|---|---|---|
| HSES wage variable нь wave хооронд код өөрчлөгдсөн | Дунд | Том | `02_import` дээр variable codebook validate, ddi PDF-ыг шалгах |
| NSO1212 API-д education supply data байхгүй / дутуу | Дунд | Дунд | `mongolstats` package; back-up: 1212.mn вэбээс гараар татах |
| 2004 шинэчлэлийн cohort exposure нь aimag-аар жигд бус | Бага | Дунд | Province-level rollout date + интерактив IV-нэмэх |
| First-stage **Kleibergen-Paap rk Wald F** < 10 | **ӨНДӨР** | Том | (1) Age sample 22-60 (`alt_sample`); (2) `reform_alt_1997` cutoff treated cohort-ыг 27+ нас руу; (3) LIML, Fuller-1 weak-IV-robust estimator; (4) **Anderson-Rubin (AR) weak-IV-robust CI — гол inference** (Stock-Yogo critical нь cluster-robust setting-д invalid); (5) KP-F нийтэд < 5 бол IVTR-ийг exploratory гэж тооцож OLS-Quantile heterogeneity-ыг гол үр дүн руу шилжих |
| Bootstrap convergence удаан (1000 rep × grid 100) | Өндөр | Бага | `parallel::mclapply` (Linux/Mac) ба `parallel::parLapply` (Windows) — 8 core-аар; яаралтай тохиолдолд rep-ийг 500 болгох эсвэл grid-ийг 50 алхам болгох |
| Windows-д `mclapply` зөвхөн 1 core-оор ажиллана | Өндөр | Дунд | `parallel::makeCluster()` + `parLapply()` ашиглах; `R/15_threshold_bootstrap.R`-д OS-detection хийж branching |
| Heckman selection: identification дутуу (exclusion restriction сулар) | Дунд | Дунд | **`n_young_kids` (өрхийн 0-5 настай хүүхдийн тоо)** нь labour-supply-д шууд нөлөөтэй ч хувь хүний бүтээмжид шууд нөлөөгүй гэх таамаглалтай (Mroz 1987-той ижил аргачлал). hhsize-ыг exclusion-д ашиглахгүй (wage-тэй endogenous болзошгүй) |
| γ̂ нь grid-ийн corner-т (5% эсвэл 95%) | Дунд | Дунд | Threshold variable-ийг log/Box-Cox transform; sample-аар нөхцөлдүүлэх |

---

## 5. Reproducibility-ийн шалгуурууд

- **`renv::init()` нь Долоо хоног 1, `R/01_setup.R`-д хийгдэнэ** (lockfile эртхэн tagged болно)
- Долоо хоног 2-аас хойш зөвхөн **`renv::snapshot()`** (шинэ багц нэмэгдэх үед)
- Долоо хоног 3-р шатанд lockfile-ыг final-locked болгож commit-д тэмдэглэнэ
- Бүх random seed `set.seed(2026)` тогтмол
- `R/99_replication.R` дарааллаар 01-23 скриптийг ажиллуулна
- Output файлуудыг `output/manifest.json`-д hash + ажиллуулсан хугацаатай тэмдэглэх

### Бодит runtime estimate (8-core Windows, 16 GB RAM)

| Алхам | Хугацаа |
|---|---|
| Setup + data prep (01-07) | ~30 мин |
| Diagnostics + 2SLS (08-12) | ~15 мин |
| IVTR grid search (13-14, 16-17) | ~30 мин |
| **Bootstrap (15) — 1000 rep × 100 grid, 8-core parallel** | **~3-5 цаг** |
| Robustness (18-21: Heckman, alt thresholds, placebo) | ~30 мин |
| Tables + figures (22-23) | ~10 мин |
| **Нийт (full mode)** | **~5-7 цаг** |
| Fast mode (Bootstrap-гүйгээр) | ~1.5 цаг |

`R/99_replication.R`-д `Sys.setenv(IVTR_FAST_MODE = "1")` тохиргоо хийвэл bootstrap-ийг алгасна.

---

## 6. Эх сурвалж (методологийн цөм)

- Caner, M., & Hansen, B. E. (2004). Instrumental Variable Estimation of a Threshold Model. *Econometric Theory*, 20(5), 813-843.
- Card, D. (2001). Estimating the Return to Schooling: Progress on Some Persistent Econometric Problems. *Econometrica*, 69(5), 1127-1160.
- Hansen, B. E. (2000). Sample Splitting and Threshold Estimation. *Econometrica*, 68(3), 575-603.
- Heckman, J. J., Lochner, L. J., & Todd, P. E. (2006). Earnings Functions, Rates of Return and Treatment Effects. In *Handbook of the Economics of Education*, Vol. 1, 307-458.
