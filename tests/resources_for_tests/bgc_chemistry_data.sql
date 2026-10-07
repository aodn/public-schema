-- Test fixture transform: depends on bgc_trip_metadata.
CREATE OR REPLACE TABLE bgc_chemistry_data AS
   SELECT TRIP_CODE FROM bgc_trip_metadata
;
