-- This view is the basis for the WMS layer (seen on step 2 on AODN Portal).
-- It also provides the metadata columns for all the phytoplankton products.
CREATE MATERIALIZED VIEW cpr_phytoplankton_map AS
  SELECT
    s.trip_code AS "TripCode",
    --TODO: Route
    s.latitude AS "Latitude",
    s.longitude AS "Longitude",
    s.sampledateutc AS "SampleDate_UTC",
    --TODO extract(year from s.sampledatelocal)::int AS "Year_local",
    --TODO extract(month from s.sampledatelocal)::int AS "Month_local",
    --TODO extract(day from s.sampledatelocal)::int AS "Day_local"
    --TODO: to_char(sampledatelocal, 'HH24:MI') AS "Time_local24hr",
    --TODO: SatSST_degC 
    --TODO: SatChlaSurf_mgm3 
    s.pci AS "PCI",
    s.biomass_mgm3 AS "BiomassIndex_mgm3 ",
    trip_code,
    sample,
    st_geomfromtext('POINT(' || longitude::text || ' ' || latitude::text || ')', 4326) AS geom
    FROM cpr_samp s
    WHERE sampletype LIKE '%P%' AND
          trip_code IN (SELECT DISTINCT trip_code from cpr_phyto_raw)
;
