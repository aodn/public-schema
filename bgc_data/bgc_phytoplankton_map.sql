-- This view is the basis for the WMS layer (seen on step 2 on AODN Portal).
-- It also provides the metadata columns for all the phytoplankton products.
CREATE MATERIALIZED VIEW bgc_phytoplankton_map AS
  SELECT
    "Project",
    "StationName",
    "StationCode",
    "Latitude",
    "Longitude",
    "TripCode",
    "SampleTime_UTC",
    "SampleTime_Local",
    "Year_Local",
    "Month_Local",
    "Day_Local",
    "Time_Local24hr",
    phytosampledepth_m AS "SampleDepth_m",
    "CTDSST_degC",
    "CTDChlaSurf_mgm3",
    "CTDSalinity_psu",
    p.methods AS "Method",
    trip_code,
    geom
  FROM bgc_trip_metadata t LEFT JOIN nrs_ctd_surface_values c USING (trip_code)
                           LEFT JOIN bgc_phyto_raw p USING (trip_code)
  WHERE sampletype LIKE '%P%' AND
        trip_code IN (SELECT DISTINCT trip_code from bgc_phyto_raw)
;
