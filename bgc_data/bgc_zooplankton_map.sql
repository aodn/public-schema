-- This view is the basis for the WMS layer (seen on step 2 on AODN Portal).
-- It also provides the metadata columns for all the zooplankton products.
CREATE MATERIALIZED VIEW bgc_zooplankton_map AS
SELECT
    projectname AS "Project",
    stationname AS "StationName",
    stationcode AS "StationCode",
    latitude AS "Latitude",
    longitude AS "Longitude",
    trip_code AS "TripCode",
  --  TODO: sampledatelocal AT TIME ZONE "UTC" AS "SampleTime_UTC",
    sampledatelocal AS "SampleTime_local",
    extract(year from sampledatelocal)::int AS "Year_local",
    extract(month from sampledatelocal)::int AS "Month_local",
    extract(day from sampledatelocal)::int AS "Day_local",
    to_char(sampledatelocal, 'HH24:MI') AS "Time_local24hr",
    zoopsampledepth_m AS "SampleDepth_m",
  --  TODO: CTD derived params:
  --  "CTDSST_degC",
  --  "CTDChlaSurf_mgm3",
  --  "CTDSalinity_psu",
    biomass_mgm3,
    trip_code,
    st_geomfromtext('POINT(' || longitude::text || ' ' || latitude::text || ')', 4326) AS geom
  FROM bgc_trip
  WHERE sampletype LIKE '%Z%' AND
        trip_code IN (SELECT DISTINCT trip_code from bgc_zoop_raw)
;
