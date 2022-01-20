-- This view is the basis for the WMS layer (seen on step 2 on AODN Portal)
-- and provides the metadata columns for the NRS Derived Indices product.
SELECT "StationName",
       "TripCode",
       "SampleTime_local"::date AS "SampleDateLocal",
       --TODO: "SampleDateUTC",
       --TODO: Year/Month/Day/Time?
       "Latitude",
       "Longitude",
       "Biomass_mgm3",
       "AshFreeBiomass_mgm3",
       secchi_m as "Secchi_m",
       zoopsampledepth_m AS "ZSampleDepth_m",
       phytosampledepth_m AS "PSampleDepth_m",
       trip_code
FROM bgc_trip_metadata
WHERE "Project" = 'NRS'
;