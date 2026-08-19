-- This view is the basis for the WMS layer (seen on step 2 on AODN Portal).
-- It also provides the metadata columns for the larval fish product.
CREATE OR REPLACE TABLE bgc_larval_fish_map AS
   SELECT 
      lfs.projectname AS "Project",
      lfs.stationname AS "StationName",
      lfs.latitude AS "Latitude",
      lfs.longitude AS "Longitude",
      lfs.trip_code AS "TripCode",
      lfs.sampledateutc AS "SampleTime_UTC",
      strftime(lfs.sampledatelocal, '%Y-%m-%d %H:%M:%S') AS "SampleTime_Local",
      extract(year from lfs.sampledatelocal)::int AS "Year_Local",
      extract(month from lfs.sampledatelocal)::int AS "Month_Local",
      extract(day from lfs.sampledatelocal)::int AS "Day_Local",
      strftime(lfs.sampledatelocal, '%H:%M') AS "Time_Local24hr",
      lfs.geardepth_m AS "SampleDepth_m",
      COALESCE(lfs.temperature_c, sv."CTDSST_degC") AS "Temperature_degC",
      COALESCE(lfs.salinity_psu, sv."CTDSalinity_psu") AS "Salinity_psu",
      lfs.sampvol_m3 AS "Volume_m3", 
      lfs.vessel AS "Vessel", 
      lfs.towtype AS "TowType",
      lfs.gearmesh_um AS "GearMesh_um",
      lfs.depth_m AS "Bathymetry_m", 
      lfs.qc_flag AS "QC_flag", 
      lfs.i_sample_id,
      ST_AsWKB(ST_GeomFromText('POINT(' || longitude::text || ' ' || latitude::text || ')')) AS geom
   FROM bgc_lfish_samples lfs LEFT JOIN nrs_ctd_surface_values sv USING (trip_code)
;

