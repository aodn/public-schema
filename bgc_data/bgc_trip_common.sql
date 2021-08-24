CREATE VIEW bgc_trip_common AS
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
  --  TODO: "SampleDepth_m",
  --  TODO: CTD derived params:
  --  "CTDSST_degC",
  --  "CTDChlaSurf_mgm3",
  --  "CTDSalinity_psu",
    trip_code,
    sampletype,
    st_geomfromtext('POINT(' || longitude::text || ' ' || latitude::text || ')', 4326) AS geom
  FROM bgc_trip
;
