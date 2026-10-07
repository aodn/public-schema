-- Test fixture transform: a simple table derived from bgc_trip, with no dependencies.
CREATE OR REPLACE TABLE bgc_trip_metadata AS
   SELECT TRIP_CODE FROM bgc_trip
;
