-- This view is the basis for the WMS layer (seen on step 2 on AODN Portal).
-- It also provides the metadata columns for all the bgc products.
CREATE MATERIALIZED VIEW combined_bgc_map AS
  SELECT
    "Project",
    "StationName",
    "TripCode",
    "SampleTime_Local",
    "SampleTime_UTC",
    "Latitude",
    "Longitude",
    bt.secchi_m AS "SecchiDepth_m",
    trip_code,
    geom
  FROM bgc_trip_metadata bt
  WHERE trip_code IN (SELECT DISTINCT trip_code from bgc_chemistry) OR
        trip_code IN (SELECT DISTINCT trip_code from bgc_picoplankton) OR
        trip_code IN (SELECT DISTINCT trip_code from bgc_pigments) OR
        trip_code IN (SELECT DISTINCT trip_code from bgc_tss)
;

