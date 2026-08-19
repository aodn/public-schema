-- This view is the basis for the WMS layer (seen on step 2 on AODN Portal).
-- It also provides the metadata columns for all the phytoplankton products.
CREATE OR REPLACE TABLE cpr_phytoplankton_map AS
  SELECT DISTINCT
    s.trip_code AS "TripCode",
    s.sample AS "Sample_ID",
    s.region AS "Region",
    s.latitude AS "Latitude",
    s.longitude AS "Longitude",
    s.sampledateutc AS "SampleTime_UTC",
    strftime(s.sampledatelocal, '%Y-%m-%d %H:%M:%S') AS "SampleTime_Local",
    extract(year from s.sampledatelocal)::int AS "Year_Local",
    extract(month from s.sampledatelocal)::int AS "Month_Local",
    extract(day from s.sampledatelocal)::int AS "Day_Local",
    strftime(sampledatelocal, '%H:%M') AS "Time_Local24hr",
    ghrsst_6d_degc AS "SatSST_degC", 
    chloc3_mgm3 AS "SatChlaSurf_mgm3",
    s.pci AS "PCI",
    v.sampvol_m3 AS "SampleVolume_m3",
    trip_code,
    sample,
    ST_AsWKB(ST_GeomFromText('POINT(' || longitude::text || ' ' || latitude::text || ')')) AS geom
    FROM cpr_samp s JOIN cpr_phyto_raw v USING (sample)
    WHERE sampletype LIKE '%P%'
;
