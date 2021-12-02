-- This view is the basis for the WMS layer (seen on step 2 on AODN Portal).
-- It also provides the metadata columns for all the bgc products.
--set search_path = imos_bgc_db, public;
CREATE MATERIALIZED VIEW combined_bgc_map AS
  SELECT
    "Project",
    "StationName",
    "TripCode",
    "SampleTime_local"::timestamp::date AS "SampleDate_Local",
--  TODO: "SampleTime_UTC",
    "Latitude",
    "Longitude",
    bt.secchi_m AS "SecchiDepth_m",
    geom
  FROM bgc_trip_metadata bt
;

