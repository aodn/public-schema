-- This view is the basis for the WMS layer (seen on step 2 on AODN Portal).
-- It also provides the metadata columns for the larval fish product.
CREATE MATERIALIZED VIEW bgc_larval_fish_map AS
   SELECT DISTINCT
      lfs.projectname AS "Project",
      lfs.stationname AS "StationName",
      btm."StationCode",
      lfs.latitude AS "Latitude",
      lfs.longitude AS "Longitude",
      lfs.trip_code AS "TripCode",
  --  TODO: sampledatelocal AT TIME ZONE "UTC" AS "SampleTime_UTC",
      lfs.sampledatelocal AS "SampleTime_local",
      extract(year from lfs.sampledatelocal)::int AS "Year_local",
      extract(month from lfs.sampledatelocal)::int AS "Month_local",
      extract(day from lfs.sampledatelocal)::int AS "Day_local",
      to_char(lfs.sampledatelocal, 'HH24:MI') AS "Time_local24hr",
      lfs.geardepth_m AS "SampleDepth_m",
      lfs.trip_code,  
      lfs.i_sample_id,
  --  TODO: CTD derived params:
  --  "CTDSST_degC",
  --  "CTDChlaSurf_mgm3",
  --  "CTDSalinity_psu",
      lfs.sampvol_m3 AS "Volume_m3", 
      lfs.vessel AS "Vessel", 
      lfs.towtype AS "TowType",
      lfs.gearmesh_um AS "GearMesh_um",
      lfs.depth_m AS "Bathymetry_m", 
      lfs.qc_flag AS "QC_flag", 
      st_geomfromtext('POINT(' || longitude::text || ' ' || latitude::text || ')', 4326) AS geom
   FROM bgc_lfish_samples lfs
   LEFT JOIN bgc_trip_metadata btm ON btm."TripCode" = lfs.trip_code
;
