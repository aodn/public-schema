-- This view is the basis for the WMS layer (seen on step 2 on AODN Portal)
-- for the "Zooplankton and larval fish" collection.
CREATE MATERIALIZED VIEW bgc_zooplankton_and_larvalfish_map AS
  SELECT
    "Project",
    "StationName",
    "Latitude",
    "Longitude",
    "TripCode",
    "SampleTime_local",
    "SampleDepth_m"::text,
    'Zooplankton' AS sample_type,
    geom
  FROM bgc_zooplankton_map
      UNION ALL
  SELECT
    CASE WHEN "Project" LIKE '%NRS%' THEN 'NRS'
         ELSE "Project"
        END AS "Project",
    "StationName",
    "Latitude",
    "Longitude",
    "TripCode",
    "SampleTime_local",
    "SampleDepth_m"::text,
    'Larval Fish' AS sample_type,
    geom
  FROM bgc_larval_fish_map
;
