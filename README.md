# NYC Real Estate & CitiBike Analytics — R + Snowflake Pipeline

Coursework from **Plataformas de Analítica de Negocios para Organizaciones
(Gpo 101)**, Licenciatura en Inteligencia de Negocios (LIT), Tecnológico de
Monterrey — Campus CSF (Aug–Dec 2024 semester).

This repo collects R-based exploratory data analysis scripts built during the
course, plus a documented data lakehouse pipeline built in Snowflake as a
team project. **The code has been cleaned up from the original submitted
drafts** — see "What was fixed" below — so that it actually runs, while the
`progression/` folder keeps a couple of the earlier, rawer drafts to show how
the main script evolved.

## Contents

```
r_scripts/
  nyc_real_estate_analysis.R       # main script: NYC property sales EDA
  citibike_geospatial.Rmd          # CitiBike trip data + sf/tigris maps
  sql_embedded_titanic.Rmd         # embedded SQL (sqldf) queries over Titanic
  ecommerce_customers_regression.Rmd  # linear regression + stepwise selection
docs/
  snowflake_pipeline.md            # documented Snowflake data lakehouse pipeline
progression/
  2024_08_14_nyc_v1_draft.R        # first working draft of the NYC script
  2024_08_20_nyc_v2_draft.R        # second draft
```

The NYC real estate script went through (at least) three dated iterations
during the course (Aug 14, Aug 20, Aug 21). `r_scripts/nyc_real_estate_analysis.R`
is the cleaned-up final (Aug 21) iteration — it has the most complete
analysis (outlier filtering, per-borough comparisons, weekday-of-sale
breakdown). The two earlier drafts are kept under `progression/` unmodified,
as-submitted, to show the progression from "just get the files loading" to
the fuller analysis.

## What each script does

- **`nyc_real_estate_analysis.R`** — loads the three NYC Department of
  Finance "Rolling Sales" Excel files (Manhattan, Brooklyn, Bronx), combines
  and cleans them, maps borough codes to names, converts zero-price sales to
  `NA`, breaks down sales by weekday, filters outliers on price and square
  footage, and compares average sale price and listing volume across the
  three boroughs.
- **`citibike_geospatial.Rmd`** — cleans a month of CitiBike trip data
  (duration outlier filtering), computes summary stats per rideable type, and
  plots trip-start density over NYC using `sf` + `tigris` census block
  geometry.
- **`sql_embedded_titanic.Rmd`** — six SQL queries (via `sqldf`) run directly
  against the classic Titanic dataset inside an R Markdown report, covering
  filtering, ordering, and NULL handling.
- **`ecommerce_customers_regression.Rmd`** — exploratory correlation/pairs
  plots and a multiple linear regression (with stepwise AIC selection)
  predicting yearly customer spend from engagement metrics.

## What was fixed before publishing

The original submitted scripts had several bugs typical of live, interactive
RStudio console work that never got cleaned up before submission. Since the
goal here is a portfolio piece that a reader could actually run, these were
fixed in `r_scripts/`:

- `readx1` (digit "1", not the letter "l") typo in a `pacman::p_load()` call
  — silently failed to load the real `readxl` package.
- `apha` typo for `alpha` in a `ggpairs(mapping = aes(...))` call (Ecommerce
  regression script) — the transparency setting was silently ignored.
- Dead/broken lines from interactive console exploration removed, e.g.
  `adsdads %>% filter(NYC_prop_sale)` (`adsdads` was never defined) and a
  filter referencing `nyc_analisis` before that object was created.
- `land_square_fest` typo corrected to `land_square_feet`.
- The outlier-filtering threshold was inconsistent across the original
  script (an `OR` condition on two square-footage fields, plus a separately
  reasoned price cutoff). Unified into one explicit rule — sale price windowed
  to \$10,000–\$6,000,000 and both square-footage fields required (via `AND`)
  to fall within their plausible range — documented in a comment in the
  script at the point of the decision.
- `dev.off` missing parentheses (never actually closed the graphics device)
  fixed to `dev.off()`.
- Deprecated ggplot2 `aes(fill = ..count..)` / `..x..` syntax updated to
  `after_stat(count)`.
- A buggy `aes(y = mean(sale_price))` bar chart (which plotted the same
  height for every bar, since `mean()` was applied to the whole column
  instead of per group) fixed to a proper `group_by()` + `summarise()`.

The `progression/` drafts are left exactly as submitted (including their
bugs) — they're there to document how the analysis evolved, not to be run.

## Data sources

Datasets are **not** checked into this repo (see `.gitignore`); scripts
expect them under a local `data/` folder.

- **NYC property sales**: NYC Department of Finance "Rolling Sales" files,
  published via [NYC Open Data](https://www.nyc.gov/site/finance/property/property-rolling-sales-data.page).
- **CitiBike trips**: [CitiBike System Data](https://citibikenyc.com/system-data)
  (public monthly trip exports).
- **Titanic**: the standard open Titanic passenger dataset used widely in
  teaching (e.g. via Kaggle/Seaborn sample data).
- **Ecommerce Customers**: a synthetic teaching dataset commonly used in R
  regression tutorials.

## Snowflake data lakehouse pipeline — important data source note

`docs/snowflake_pipeline.md` documents a Snowflake pipeline built as a
**team project** ("Evidencia 1") that joins CitiBike trip data with NYC
weather data inside Snowflake. There is no separate `.sql`/`.py` file for
this — the team's evidence was an 11-page PDF report, so the pipeline has
been transcribed into readable Markdown + SQL for this repo.

**The S3 buckets referenced in that pipeline
(`s3://snowflake-workshop-lab/citibike-trips` and
`s3://snowflake-workshop-lab/weather-nyc`) are Snowflake's own public
"Snowflake Quickstart" sample dataset** — the same bucket Snowflake uses in
its official onboarding tutorials. This is **not** data collected or hosted
by the team; it's the standard practice dataset the course exercise was built
on top of.

### Team attribution

The Snowflake pipeline (data model + SQL) documented in
`docs/snowflake_pipeline.md` was built collaboratively for a team course
project by:

- P. Gustavo Adolfo Santana Torrellas
- P. Gabriela Yáñez Martínez
- P. Jose Reyes Eslava Zavaleta
- Delot Bravo Ludovic (A01663977)

The R scripts in `r_scripts/` are Ludovic's individual coursework from the
same class, done separately from the Snowflake team project.

## Requirements

R (tested conceptually against packages current as of 2024–2025):
`dplyr`, `tidyverse`, `magrittr`, `RColorBrewer`, `readxl`, `janitor`,
`lubridate`, `formattable`, `DT`, `outliers`, `gridExtra`, `scales`, `sf`,
`tigris`, `rnaturalearth`, `rnaturalearthdata`, `hms`, `sqldf`, `GGally`,
`MASS`. Installed most easily via `pacman::p_load(...)`, which each script
uses at the top.
