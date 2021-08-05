CREATE VIEW bgc_trip_common AS
  SELECT
    projectname AS "Project",
    station AS "StationName",
    stationcode AS "StationCode",
    latitude AS "Latitude",
    longitude AS "Longitude",
    trip_code AS "TripCode",
  --  TODO: sampledatelocal AT TIME ZONE "UTC" AS "SampleTime_UTC",
    sampledatelocal AS "SampleTime_local",
  --  TODO: year/month/day/time24hr:
  --  "Year_local",
  --  "Month_local",
  --  "Day_local",
  --  "Time_local24hr",
  --  TODO: "SampleDepth_m",
  --  TODO: CTD derived params:
  --  "CTDSST_degC",
  --  "CTDChlaSurf_mgm3",
  --  "CTDSalinity_psu",
    sampletype,
    st_geomfromtext('POINT(' || longitude::text || ' ' || latitude::text || ')', 4326) AS geom
  FROM bgc_trip
;