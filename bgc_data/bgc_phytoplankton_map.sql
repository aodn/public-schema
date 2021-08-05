CREATE MATERIALIZED VIEW bgc_phytoplankton_map AS
(
  SELECT *
  FROM bgc_trip_common
  WHERE sampletype LIKE '%P%'
)
;
