-- This view provides common trip metadata columns for all bgc products
CREATE OR REPLACE VIEW bgc_trip_metadata AS
  SELECT
    projectname AS "Project",
    stationname AS "StationName",
    stationcode AS "StationCode",
    latitude AS "Latitude",
    longitude AS "Longitude",
    trip_code AS "TripCode",
    sampledateutc AS "SampleTime_UTC",
    strftime(sampledatelocal, '%Y-%m-%d %H:%M:%S') AS "SampleTime_Local",
    extract(year from sampledatelocal)::int AS "Year_Local",
    extract(month from sampledatelocal)::int AS "Month_Local",
    extract(day from sampledatelocal)::int AS "Day_Local",
    strftime(sampledatelocal, '%H:%M') AS "Time_Local24hr",
    phytosampledepth_m,
    zoopsampledepth_m,
    biomass_mgm3 AS "Biomass_mgm3",
    ashfreebiomass_mgm3 AS "AshFreeBiomass_mgm3",
    secchi_m,
    sampletype,
    trip_code,
    ST_AsWKB(ST_GeomFromText('POINT(' || longitude::text || ' ' || latitude::text || ')')) AS geom
  FROM bgc_trip
;
