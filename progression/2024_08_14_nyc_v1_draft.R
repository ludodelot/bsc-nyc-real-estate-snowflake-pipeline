library(dplyr)
library(tidyverse)
library(magrittr)
library(RColorBrewer)
library(readxl)
library(janitor)
library(lubridate)



pacman::p_load(dplyr,tidyverse,magrittr,RColorBrewer, readx1)

setwd("/Users/ludovicdelotbravo/Documents/S5 - LIT - DELOT B. LUDOVIC/S5P1_PLAT_ANALITICA_NEG_ORG/03_RECURSOS/test_1")

bronx <- read_excel("rollingsales_bronx.xlsx", skip = 4)

files <- list.files(pattern = ".xlsx")

for(i in 1:length(files)) {
  filename <- files[i]
  data <- read_excel(filename, sheet = 1, skip = 4)
  assign(x = filename, value = data)
}

rm(data, bronx)
bronx <- rollingsales_bronx.xlsx
brooklyn <- rollingsales_brooklyn.xlsx
manhattan <- rollingsales_manhattan.xlsx
ls()
rm(list = ls()[grepl("rollingsales", ls())])

tail(bronx)
tail(brooklyn)
tail(manhattan)

bronx <- head(bronx, -1)
manhattan <- slice(manhattan, 1:(n()-1))
glimpse(bronx)
str(bronx)

mean(brooklyn$`SALE PRICE`)
qplot(`SALE PRICE` , data = bronx)
NYC_prop_sale <- bind_rows(brooklyn, bronx, manhattan)

clean_names(NYC_prop_sale) 

table(bronx$BOROUGH)
table(manhattan$BOROUGH)
table(brooklyn$BOROUGH)



NYC_prop_sale <- clean_names(NYC_prop_sale)

colnames(NYC_prop_sale)

NYC_prop_sale$ciudad <- ifelse(NYC_prop_sale$borough == '1', 'Manhattan',
                               ifelse(NYC_prop_sale$borough == '2', 'Bronx', 'Brooklyn'))


table(NYC_prop_sale$ciudad)


NYC_prop_sale$sale_price[NYC_prop_sale$sale_price == 0] <-NA
ciudad_precio_promedio <-
  tapply(NYC_prop_sale$sale_price, NYC_prop_sale$ciudad, mean,na.rm = TRUE)

ciudad_precio_promedio



a = barplot(ciudad_precio_promedio,
            main = "PPC",
            ylab = "Precio Promedio",
            col = brewer.pal(5,"YlGnBu"))


NYC_prop_sale$sale_date <- as.Date(NYC_prop_sale$sale_date, format = "%Y-%m-%d")

# Convertir la columna 'sale_date' a tipo Date (asegúrate de que la fecha esté en el formato correcto)
NYC_prop_sale$sale_date <- as.Date(NYC_prop_sale$sale_date, format = "%Y-%m-%d")

# Obtener el día de la semana de cada fecha de venta
NYC_prop_sale$weekday <- weekdays(NYC_prop_sale$sale_date)

# Ordenar los niveles de los días de la semana
NYC_prop_sale$weekday <- factor(NYC_prop_sale$weekday,
                                levels = c("Monday", "Tuesday", "Wednesday", "Thursday",
                                           "Friday", "Saturday", "Sunday"))

# Crear la gráfica de barras
x <- barplot(table(NYC_prop_sale$weekday), 
             main = "En qué día se realizaron más ventas",
             col = terrain.colors(7),
             xlab = "Día",
             ylab = "Número de ventas",
             ylim = c(0, max(table(NYC_prop_sale$weekday)) * 1.1))

# Añadir etiquetas a las barras
text(x = x, 
     y = table(NYC_prop_sale$weekday), 
     label = table(NYC_prop_sale$weekday), 
     pos = 3, 
     cex = 0.8, 
     col = "black")
























