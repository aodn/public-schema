-- This view is the basis for the WMS layer (seen on step 2 on AODN Portal).
-- It also provides the metadata columns for all the zooplankton products.
CREATE MATERIALIZED VIEW cpr_zooplankton_map AS
SELECT
    s.trip_code AS "TripCode",
    s.region AS "Region",
    s.latitude AS "Latitude",
    s.longitude AS "Longitude",
    s.sampledateutc AS "SampleDate_UTC",
    extract(year from s.sampledateutc)::int AS "Year_UTC",
    extract(month from s.sampledateutc)::int AS "Month_UTC",
    extract(day from s.sampledateutc)::int AS "Day_UTC",
    to_char(sampledateutc, 'HH24:MI') AS "Time_UTC24hr",
    --TODO: SatSST_degC 
    --TODO: SatChlaSurf_mgm3 
    s.pci AS "PCI",
    s.biomass_mgm3 AS "BiomassIndex_mgm3 ",
    trip_code,
    sample,
    st_geomfromtext('POINT(' || longitude::text || ' ' || latitude::text || ')', 4326) AS geom
    FROM cpr_samp s
    WHERE sampletype LIKE '%Z%' AND
          trip_code IN (SELECT DISTINCT trip_code from cpr_phyto_raw)
;
