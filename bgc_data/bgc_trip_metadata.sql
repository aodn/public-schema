-- This view provides common trip metadata columns for all bgc products
CREATE VIEW bgc_trip_metadata AS
  SELECT
    projectname AS "Project",
    stationname AS "StationName",
    stationcode AS "StationCode",
    latitude AS "Latitude",
    longitude AS "Longitude",
    trip_code AS "TripCode",
    sampledateutc AS "SampleTime_UTC",
    to_char(sampledatelocal, 'YYYY-MM-DD HH24:MI:SS') AS "SampleTime_Local",
    extract(year from sampledatelocal)::int AS "Year_Local",
    extract(month from sampledatelocal)::int AS "Month_Local",
    extract(day from sampledatelocal)::int AS "Day_Local",
    to_char(sampledatelocal, 'HH24:MI') AS "Time_Local24hr",
    phytosampledepth_m,
    zoopsampledepth_m,
    biomass_mgm3 AS "Biomass_mgm3",
    ashfreebiomass_mgm3 AS "AshFreeBiomass_mgm3",
    secchi_m,
    sampletype,
    trip_code,
    st_geomfromtext('POINT(' || longitude::text || ' ' || latitude::text || ')', 4326) AS geom
  FROM bgc_trip
;
