-- This view is the basis for the WMS layer (seen on step 2 on AODN Portal).
-- It also provides the metadata columns for all the phytoplankton products.
CREATE MATERIALIZED VIEW cpr_phytoplankton_map AS
  SELECT
    s.trip_code AS "TripCode",
    s.region AS "Region",
    s.latitude AS "Latitude",
    s.longitude AS "Longitude",
    s.sampledateutc AT TIME ZONE 'UTC' AS "SampleDate_UTC",
    s.sampledatelocal::text AS "SampleDate_Local", 
    extract(year from s.sampledateutc)::int AS "Year_UTC",
    extract(month from s.sampledateutc)::int AS "Month_UTC",
    extract(day from s.sampledateutc)::int AS "Day_UTC",
    to_char(sampledateutc, 'HH24:MI') AS "Time_UTC24hr",
    NULL AS "SatSST_degC", --to be updated
    NULL AS "SatChlaSurf_mgm3", --to be updated
    s.pci AS "PCI",
    trip_code,
    sample,
    st_geomfromtext('POINT(' || longitude::text || ' ' || latitude::text || ')', 4326) AS geom
    FROM cpr_samp s
    WHERE sampletype LIKE '%P%' AND
          trip_code IN (SELECT DISTINCT trip_code from cpr_phyto_raw)
;
