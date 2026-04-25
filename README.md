# Монгол Улсад боловсролын бодит өгөөжийн босготой үнэлгээ

**HSES 2020-2024 микро өгөгдөл, Caner & Hansen (2004) IV-Threshold регрессийн шинжилгээ**

## Товч танилцуулга

Энэхүү репозиторт Монгол Улсын ӨНЭЗС-ийн (HSES) 2020-2024 оны микро өгөгдөл дээр боловсролын бодит өгөөжийг IV-threshold регрессийн аргаар үнэлсэн бүрэн ажлын урсгалыг агуулсан.

- **Y:** ln(real hourly wage), 2020 base CPI
- **Endogenous:** educ_years
- **Instrument:** 2004 онд эхэлсэн 12 жилийн боловсролын систем шилжилтийн cohort exposure (Z = 1{birth_year ≥ 1997})
- **Threshold variable:** school_access — тухайн хүний 6-17 нас байхад тухайн аймагт ЕБС-ийн нягтрал
- **Sample:** 25-60 насны цалинтай ажиллагсад

## Хавтасны бүтэц

```
shine/
├── PLAN.md              # 4 долоо хоногийн ажлын дэлгэрэнгүй төлөвлөгөө
├── README.md            # Энэ файл
├── data/
│   ├── raw/             # түүхий .rds (HSES wave-уудыг import хийсэн)
│   ├── processed/       # boловсруулсан analysis sample
│   ├── aux/             # NSO боловсролын supply data
│   └── hses_2020 ... hses_2024/   # анхдагч .dta файлууд
├── R/                   # 01_setup.R ... 99_replication.R
└── output/
    ├── tables/          # T1-T7
    ├── figures/         # F1-F5 (300 dpi PNG)
    └── logs/            # diagnostics, bootstrap, placebo
```

## Хэрхэн ажиллуулах

1. **Багц суулгах:** R Studio-д `R/01_setup.R`-г нэг удаа ажиллуулна.
2. **End-to-end replication:** `Rscript R/99_replication.R` (бүгд скрипт дарааллаар ажиллана, ~ 25-40 мин).
3. **Гар ажиллагаагаар:** `R/01_setup.R` → `02_import_hses.R` → ... → `23_tables_export.R` дарааллаар.

## Системийн шаардлага

- R 4.4.0+
- ~ 4 GB RAM (HSES merge үед оргил хэрэглээ ~ 2 GB)
- Internet холбоо (NSO1212 API-аас education supply data татах)

## Гол R багц

`tidyverse, haven, fixest, ivreg, AER, sandwich, lmtest, boot, NSO1212` (эсвэл `mongolstats`), `data.table` (том wave merge-д), `glue, here, fs`

## Холбоо барих

СЭЗИС, Эконометрикийн VIII Олимпиадын II шат — 2026.

## Лиценз

Зөвхөн академик зориулалттай. HSES микро өгөгдөл нь ҮСХ-ны өмч.
