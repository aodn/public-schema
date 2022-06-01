-- This view is the basis for the WMS layer (seen on step 2 on AODN Portal).
-- It also provides the metadata columns for all the phytoplankton products.
CREATE MATERIALIZED VIEW cpr_phytoplankton_map AS
  SELECT DISTINCT
    s.trip_code AS "TripCode",
    s.region AS "Region",
    s.latitude AS "Latitude",
    s.longitude AS "Longitude",
    s.sampledateutc AS "SampleTime_UTC",
    to_char(s.sampledatelocal, 'YYYY-MM-DD HH24:MI:SS') AS "SampleTime_Local",
    extract(year from s.sampledatelocal)::int AS "Year_Local",
    extract(month from s.sampledatelocal)::int AS "Month_Local",
    extract(day from s.sampledatelocal)::int AS "Day_Local",
    to_char(sampledatelocal, 'HH24:MI') AS "Time_Local24hr",
    NULL AS "SatSST_degC", --to be updated
    NULL AS "SatChlaSurf_mgm3", --to be updated
    s.pci AS "PCI",
    v.sampvol_m3 AS "SampleVolume_m3",
    trip_code,
    sample,
    st_geomfromtext('POINT(' || longitude::text || ' ' || latitude::text || ')', 4326) AS geom
    FROM cpr_samp s JOIN cpr_phyto_raw v USING (sample)
    WHERE sampletype LIKE '%P%'
;
