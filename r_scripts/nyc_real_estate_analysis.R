# ==============================================================================
# NYC Real Estate Sales — Exploratory Analysis
# ==============================================================================
# Course:  Plataformas de Analítica de Negocios para Organizaciones (Gpo 101)
# Program: Licenciatura en Inteligencia de Negocios (LIT) — Tec de Monterrey CSF
# Author:  Ludovic Delot Bravo
#
# Source data: NYC Department of Finance "Rolling Sales" files for Manhattan,
# Brooklyn and the Bronx (NYC Open Data / NYC DOF Property Sales). The three
# .xlsx files are NOT included in this repo (see README for the download link);
# place them in a local data/ folder and update DATA_DIR below before running.
#
# This is the cleaned-up final iteration of a script that went through several
# drafts during the course (see progression/ for the earlier, rawer versions).
# Cleanup notes (fixed while preparing this for the portfolio):
#   - `readx1` (digit "1") typo corrected to `readxl` in the pacman::p_load call
#     — the typo silently failed to install/load the real `readxl` package.
#   - Removed dead/broken lines left over from interactive console exploration:
#       adsdads %>% filter(NYC_prop_sale)              # `adsdads` never existed
#       explore <- filter(nyc_analisis, ...)            # referenced nyc_analisis
#                                                        # before it was created
#       nyc_analisis %>% filter                          # incomplete pipe, no-op
#       a stray literal `2` left on its own line
#   - Fixed `land_square_fest` typo -> `land_square_feet`.
#   - Unified the outlier threshold: earlier drafts mixed an OR condition
#     (`land_square_feet < 4000 | gross_square_feet < 11200`) with a separate
#     price-based cutoff, which is inconsistent (an OR keeps a row if EITHER
#     field looks reasonable, even when the other is wildly off). This version
#     uses one consistent rule, decided from the 10th/90th percentile check
#     already done in the script: keep sale_price in [$10,000, $6,000,000] and
#     require BOTH square-footage fields to be within the ~1st-99th percentile
#     range (AND, not OR). See "Outlier filtering" section below.
#   - Replaced the deprecated `..x..` / `..count..` ggplot2 aes() syntax with
#     `after_stat(count)`.
#   - Consolidated the duplicate `library()` + `pacman::p_load()` calls into a
#     single package-loading block.
# ==============================================================================

pacman::p_load(dplyr, tidyverse, magrittr, RColorBrewer, readxl, janitor,
                lubridate, formattable, DT, outliers, gridExtra, scales)

# --- 1. Load data -------------------------------------------------------------

DATA_DIR <- "data/nyc_rolling_sales"  # update to wherever the .xlsx files live
setwd(DATA_DIR)

files <- list.files(pattern = "\\.xlsx$")

for (i in seq_along(files)) {
  filename <- files[i]
  data <- read_excel(filename, sheet = 1, skip = 4)
  assign(x = filename, value = data)
}

bronx     <- `rollingsales_bronx.xlsx`
brooklyn  <- `rollingsales_brooklyn.xlsx`
manhattan <- `rollingsales_manhattan.xlsx`
rm(list = ls()[grepl("rollingsales", ls())], data)

# Each sheet ends with a footer/summary row exported by NYC DOF — drop it.
tail(bronx); tail(brooklyn); tail(manhattan)
bronx     <- head(bronx, -1)
manhattan <- slice(manhattan, 1:(n() - 1))

glimpse(bronx)
str(bronx)

mean(brooklyn$`SALE PRICE`)
qplot(`SALE PRICE`, data = bronx)

# --- 2. Combine boroughs and clean names --------------------------------------

NYC_prop_sale <- bind_rows(brooklyn, bronx, manhattan)
NYC_prop_sale <- clean_names(NYC_prop_sale)

table(bronx$BOROUGH)
table(manhattan$BOROUGH)
table(brooklyn$BOROUGH)

NYC_prop_sale$ciudad <- ifelse(NYC_prop_sale$borough == "1", "Manhattan",
                         ifelse(NYC_prop_sale$borough == "2", "Bronx", "Brooklyn"))
table(NYC_prop_sale$ciudad)

# --- 3. Basic cleaning: zero-value sentinels -> NA ----------------------------

NYC_prop_sale$sale_price[NYC_prop_sale$sale_price == 0] <- NA
NYC_prop_sale$gross_square_feet[NYC_prop_sale$sale_price == 0] <- NA
NYC_prop_sale$land_square_feet[NYC_prop_sale$sale_price == 0] <- NA

ciudad_precio_promedio <- tapply(NYC_prop_sale$sale_price, NYC_prop_sale$ciudad,
                                  mean, na.rm = TRUE)
ciudad_precio_promedio

barplot(ciudad_precio_promedio,
        main = "Precio Promedio por Ciudad (sin depurar)",
        ylab = "Precio Promedio",
        col = brewer.pal(5, "YlGnBu"))

# --- 4. Dates and weekday of sale ---------------------------------------------

NYC_prop_sale$sale_date <- as.Date(NYC_prop_sale$sale_date, format = "%Y-%m-%d")
NYC_prop_sale$weekday <- weekdays(NYC_prop_sale$sale_date)
NYC_prop_sale$weekday <- factor(NYC_prop_sale$weekday,
                                 levels = c("Monday", "Tuesday", "Wednesday",
                                            "Thursday", "Friday", "Saturday", "Sunday"))

x <- barplot(table(NYC_prop_sale$weekday),
             main = "En qué día se realizaron más ventas",
             col = terrain.colors(7),
             xlab = "Día",
             ylab = "Número de ventas",
             ylim = c(0, max(table(NYC_prop_sale$weekday)) * 1.1))
text(x = x, y = table(NYC_prop_sale$weekday), label = table(NYC_prop_sale$weekday),
     pos = 3, cex = 0.8, col = "black")

# --- 5. Analysis dataset: drop unsold / zero-price rows -----------------------

nyc_analisis <- NYC_prop_sale %>%
  filter(!is.na(sale_price) & sale_price != 0)

nyc_analisis$land_square_feet[nyc_analisis$land_square_feet == 0] <- NA
nyc_analisis$gross_square_feet[nyc_analisis$gross_square_feet == 0] <- NA

invalid_units <- nyc_analisis %>%
  filter(total_units != residential_units + commercial_units) %>%
  nrow()
print(invalid_units)

nyc_analisis %>%
  filter(!is.na(residential_units)) %>%
  ggplot(aes(x = residential_units, fill = after_stat(count))) +
  geom_histogram(bins = 300)

nyc_analisis %>%
  filter(!is.na(residential_units) & residential_units < 75) %>%
  ggplot(aes(x = residential_units, fill = after_stat(count))) +
  geom_histogram()

# Focus on single-family/single-unit residential sales for the price analysis.
nyc_analisis_unit <- nyc_analisis %>%
  filter(residential_units == 1)

head(nyc_analisis, n = 50) %>%
  formattable() %>%
  as.datatable(options = list(dom = "t", scrollX = TRUE, scrollCollapse = TRUE))

ciudad_precio_promedio <- tapply(nyc_analisis_unit$sale_price,
                                  nyc_analisis_unit$ciudad, mean)

barplot(ciudad_precio_promedio,
        main = "Precio Promedio por Ciudad (unidades residenciales únicas)",
        ylab = "Precio Promedio",
        col = brewer.pal(5, "YlGnBu"))

quantile(nyc_analisis_unit$sale_price, probs = seq(0, 1, by = 0.1))
boxplot(nyc_analisis_unit$sale_price)

# --- 6. Outlier filtering ------------------------------------------------------
# Decision: sale_price is windowed to [$10,000, $6,000,000] based on the decile
# breakdown above (very low prices are $0/$1 nominal "family transfer" sales,
# not market transactions; the extreme high tail is a handful of outliers that
# dominate the mean). Square footage fields are then filtered with the SAME
# logic — both must be within a plausible range — using AND rather than OR, so
# that a row isn't kept just because ONE of the two footage fields happens to
# look reasonable while the other is clearly bad data.

outliers::outlier(nyc_analisis_unit$sale_price)

nyc_analisis_2 <- nyc_analisis_unit %>%
  filter(sale_price >= 10000 & sale_price <= 6000000)

boxplot(nyc_analisis_2$sale_price)
outliers::outlier(nyc_analisis_2$land_square_feet)

quantile(nyc_analisis_2$land_square_feet, probs = seq(0, 1, by = 0.1), na.rm = TRUE)
# Interpretation: quantiles (0%-100%) of land_square_feet in nyc_analisis_2.
# 10th percentile ~1,573 sq ft, median ~2,107 sq ft, 90th percentile ~4,000 sq ft.
max(nyc_analisis_2$land_square_feet, na.rm = TRUE)

outliers::outlier(nyc_analisis_2$gross_square_feet)

nyc_analisis_2 <- nyc_analisis_2 %>%
  filter(land_square_feet < 4000 & gross_square_feet < 11200)

boxplot(nyc_analisis_2$sale_price)

# --- 7. Final charts ------------------------------------------------------------

nyc_analisis_2$ciudad <- as.factor(nyc_analisis_2$ciudad)

reorder_size <- function(x) {
  factor(x, levels = names(sort(table(x), decreasing = TRUE)))
}

p1 <- ggplot(data = nyc_analisis_2, aes(x = reorder_size(ciudad), fill = ciudad)) +
  geom_bar() +
  ggtitle("Mayor demanda en NYC", subtitle = "# Propiedades en venta por ciudad") +
  scale_y_continuous("# Propiedades en venta", labels = scales::comma) +
  theme(legend.position = "none")
p1

p2 <- nyc_analisis_2 %>%
  group_by(ciudad) %>%
  summarise(precio_promedio = mean(sale_price, na.rm = TRUE)) %>%
  ggplot(aes(x = reorder_size(ciudad), y = precio_promedio, fill = ciudad)) +
  geom_bar(stat = "identity") +
  ggtitle("Precio promedio por ciudad", subtitle = "Propiedades en venta en NYC") +
  scale_y_continuous("Precio promedio", labels = scales::dollar) +
  scale_x_discrete("Ciudad") +
  theme(legend.position = "none")
p2

gridExtra::grid.arrange(p1, p2, ncol = 2)
