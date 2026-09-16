# CitiBike + Weather — Snowflake Data Lakehouse Pipeline

> Transcribed and lightly reorganized from the team's "Evidencia 1" PDF
> (`Plataformas de Analítica de Negocios para Organizaciones`, Tec de
> Monterrey CSF). The original evidence is an 11-page PDF report, not a
> checked-in `.sql`/`.py` file, so this document reproduces the pipeline in
> readable Markdown + SQL for the portfolio.

## Team & attribution

This pipeline (data model, load scripts, and Snowflake SQL) was built as
**team work** for course project "Evidencia 1" by:

- P. Gustavo Adolfo Santana Torrellas
- P. Gabriela Yáñez Martínez
- P. Jose Reyes Eslava Zavaleta
- Delot Bravo Ludovic (A01663977) — author of this repository

The R-side data loading/cleaning scripts in `r_scripts/` are Ludovic's
individual work from the same course; the Snowflake SQL documented below was
written collaboratively by the team.

## IMPORTANT — data source disclaimer

The S3 buckets referenced in the `STAGE` definitions below
(`s3://snowflake-workshop-lab/citibike-trips` and
`s3://snowflake-workshop-lab/weather-nyc`) are **Snowflake's own public
"Snowflake Quickstart" / Snowflake Hands-On Lab sample dataset**, not data
collected or hosted by the team. This is the same bucket used across
Snowflake's official onboarding tutorials. No credentials or private
infrastructure are involved — the bucket is public/read-only and is only
referenced here for documentation purposes.

## 1. Goal

Combine NYC CitiBike trip data with NYC weather data inside Snowflake to
answer business questions about how weather conditions affect bike-share
usage (trip volume and trip duration).

## 2. Data model

Two entities, joined on a truncated-to-the-hour timestamp:

**`trips`** (structured, loaded from CSV)

| Column | Type |
|---|---|
| tripduration | INT |
| starttime | TIMESTAMP |
| stoptime | TIMESTAMP |
| start_station_id | INT |
| start_station_name | VARCHAR(50) |
| start_station_latitude | FLOAT |
| start_station_longitude | FLOAT |
| end_station_id | INT |
| end_station_name | VARCHAR(50) |
| end_station_latitude | FLOAT |
| end_station_longitude | FLOAT |
| bikeid | INT |
| membership_type | VARCHAR(10) |
| usertype | VARCHAR(10) |
| birth_year | INT |
| gender | INT |

**`json_weather_data_view`** (semi-structured, loaded from JSON as a single
`VARIANT` column, then flattened via a view)

| Column | Type | Notes |
|---|---|---|
| observation_time | TIMESTAMP | |
| city_id | INT | |
| city_name | VARCHAR(50) | |
| country | VARCHAR(2) | ISO country code |
| city_lat / city_lon | FLOAT | |
| clouds | INT | |
| temp_avg / temp_min / temp_max | FLOAT | **Converted from Kelvin to Celsius** (raw API value − 273.15) |
| weather | VARCHAR(20) | main condition, e.g. "Clouds", "Rain" |
| weather_desc | VARCHAR(50) | detailed description |
| weather_icon | VARCHAR(10) | |
| wind_dir | FLOAT | degrees |
| wind_speed | FLOAT | m/s |

Relationship: **1 weather timestamp → N trips** (many trips can fall inside
the same hourly weather observation window).

## 3. SQL pipeline

### 3.1 Structured data: `trips` from a CSV stage on S3

```sql
-- ================= CREATE DATABASE / TRIPS TABLE =================
CREATE DATABASE CITIBIKE;

CREATE OR REPLACE TABLE trips
 (tripduration INTEGER,
  starttime TIMESTAMP,
  stoptime TIMESTAMP,
  start_station_id INTEGER,
  start_station_name STRING,
  start_station_latitude FLOAT,
  start_station_longitude FLOAT,
  end_station_id INTEGER,
  end_station_name STRING,
  end_station_latitude FLOAT,
  end_station_longitude FLOAT,
  bikeid INTEGER,
  membership_type STRING,
  usertype STRING,
  birth_year INTEGER,
  gender INTEGER);

-- STAGE = a pointer to the file location (a public S3 bucket, in this case
-- Snowflake's own Quickstart sample data — see disclaimer above)
CREATE STAGE citibikes_trips URL = 's3://snowflake-workshop-lab/citibike-trips';
LIST @citibikes_trips;

-- File format definition for the CSV files
CREATE OR REPLACE FILE FORMAT csv TYPE = 'csv'
  COMPRESSION = 'auto' FIELD_DELIMITER = ',' RECORD_DELIMITER = '\n'
  SKIP_HEADER = 0 FIELD_OPTIONALLY_ENCLOSED_BY = '\042' TRIM_SPACE = FALSE
  ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE ESCAPE = 'NONE' ESCAPE_UNENCLOSED_FIELD = '\134'
  DATE_FORMAT = 'AUTO' TIMESTAMP_FORMAT = 'AUTO' NULL_IF = ('')
  COMMENT = 'file format for ingesting data for zero to snowflake';

SHOW FILE FORMATS IN DATABASE citibike;

-- Load. Recommendation: scale up the warehouse size for this COPY INTO.
COPY INTO trips FROM @citibikes_trips FILE_FORMAT = CSV ON_ERROR = SKIP_FILE;
```

### 3.2 Semi-structured data: `json_weather_data` from JSON on S3

```sql
-- ================= SEMI-STRUCTURED WEATHER DATA =================
-- ETL note: we transform the raw JSON via a VIEW rather than at load time —
-- the raw table only ever has ONE column, of type VARIANT.

CREATE OR REPLACE TABLE json_weather_data (v VARIANT); -- variant = schema-less

CREATE OR REPLACE STAGE nyc_weather URL = 's3://snowflake-workshop-lab/weather-nyc';
-- STAGE = pointer to a location, not an object itself; the URL lives on the
-- stage named nyc_weather

LIST @nyc_weather;

COPY INTO json_weather_data FROM @nyc_weather FILE_FORMAT = (TYPE = json);
-- We are not connecting to the bucket directly here — we copy the JSON files
-- referenced by the stage into the table we just created.

-- Pull out only the fields we actually need
CREATE OR REPLACE VIEW json_weather_data_view AS
SELECT
  v:time::timestamp AS observation_time,
  v:city.id::int AS city_id,
  v:city.name::string AS city_name,
  v:city.country::string AS country,
  v:city.coord.lat::float AS city_lat,
  v:city.coord.lon::float AS city_lon,
  v:clouds.all::int AS clouds,
  (v:main.temp::float) - 273.15 AS temp_avg,       -- Kelvin -> Celsius
  (v:main.temp_min::float) - 273.15 AS temp_min,   -- Kelvin -> Celsius
  (v:main.temp_max::float) - 273.15 AS temp_max,   -- Kelvin -> Celsius
  v:weather[0].main::string AS weather,
  v:weather[0].description::string AS weather_desc,
  v:weather[0].icon::string AS weather_icon,
  v:wind.deg::float AS wind_dir,
  v:wind.speed::float AS wind_speed
FROM json_weather_data
WHERE city_id = 5128638; -- New York City
```

### 3.3 Temporal join: trips × weather

```sql
-- ///////////////////////////// JOIN TABLES /////////////////////////////
-- Combine trip data with the weather in effect during that trip, matched by
-- truncating both timestamps down to the hour.

CREATE OR REPLACE VIEW trips_toge AS
SELECT
  t.tripduration,
  t.starttime,
  t.stoptime,
  t.start_station_id,
  t.start_station_name,
  t.start_station_latitude,
  t.start_station_longitude,
  t.end_station_id,
  t.end_station_name,
  t.end_station_latitude,
  t.end_station_longitude,
  t.bikeid,
  t.membership_type,
  t.usertype,
  t.birth_year,
  t.gender,
  w.weather,
  w.weather_desc,
  w.temp_avg,
  w.clouds,
  w.wind_speed
FROM trips t
LEFT JOIN json_weather_data_view w
  ON date_trunc('hour', t.starttime) = date_trunc('hour', w.observation_time)
WHERE w.city_id = 5128638; -- filter to New York City
```

## 4. Why this join matters (team's takeaway)

Joining `trips` and `json_weather_data_view` lets the team compare ride volume
and duration against concurrent weather conditions — e.g. whether ridership
drops in cold or rainy weather, and whether trips run longer on clear/sunny
days. That combined view is meant to support downstream business questions
about adjusting bike availability to match weather-driven demand.

## 5. Conclusion

By integrating CitiBike trip data with NYC weather data inside Snowflake, the
team produced a single queryable view (`trips_toge`) joining two previously
separate sources, intended to support weather-aware demand analysis for the
bike-share system.
