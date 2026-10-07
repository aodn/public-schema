-- Test fixture transform: always fails (references a table that doesn't exist), for testing
-- failure handling without relying on malformed SQL syntax.
CREATE OR REPLACE TABLE bgc_tss_data AS
   SELECT * FROM nonexistent_table
;
