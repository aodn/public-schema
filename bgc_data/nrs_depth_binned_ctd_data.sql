-- Materialized view for nrs depth binned ctd product
CREATE MATERIALIZED VIEW nrs_depth_binned_ctd_data AS
WITH
--modify the site code to match with the deployments table
--consider only NRS stations
  nrs_trips AS (
      SELECT
         z.stationname AS "StationName",
         z.trip_code AS "TripCode",
         z.latitude AS "Latitude", 
         z.longitude AS "Longitude",
         z.sampledatelocal AS trip_time_local,
	 CONCAT(z.projectname,z.stationcode) AS bgc_trip_site_code_match
      FROM imos_bgc_db.bgc_trip z
      WHERE z.projectname = 'NRS'
),
--identify file_id obtained from NRS stations
--match file_id from NRS stations with the measurements table
  measurements_mod AS(
      SELECT dp.site_code,
         dp.site_code AS site_code_match,
         ms.file_id,
         ms."TIME"
      FROM anmn_nrs_ctd_profiles.deployments dp
      LEFT JOIN anmn_nrs_ctd_profiles.measurements ms ON ms.file_id = dp.file_id
      WHERE dp.site_code LIKE 'NRS%'
--useful to group by here as there are multiple depths that are all associated with the same file_id
      GROUP BY ms.file_id, dp.site_code, ms."TIME"
),
--calculate the absolute time difference 
--match the site code and time
ctd_profiles AS (
      SELECT
         nt.trip_time_local,
         nt."StationName",
         nt."TripCode",
         nt."Latitude",
         nt."Longitude",
         mm."TIME" AS ctd_time_utc,
         mm.site_code_match,
         nt.bgc_trip_site_code_match,
         mm.file_id,
         GREATEST((nt.trip_time_local - mm."TIME"),-(nt.trip_time_local - mm."TIME")) AS absolute_time_difference
      FROM nrs_trips nt 
      LEFT JOIN measurements_mod mm 
	  ON mm."TIME" BETWEEN (nt.trip_time_local - INTERVAL '1' DAY) AND (nt.trip_time_local + INTERVAL '1' DAY)
	  AND mm.site_code_match = nt.bgc_trip_site_code_match
),
--select the minimum absolute difference in time 
  ctd_selection AS (
      SELECT
         cp.file_id,
         MIN(cp.absolute_time_difference) AS minimum_absolute_time_difference
      FROM ctd_profiles cp
      GROUP BY cp.file_id
),
--select the ctd files id to list and the information needed from the original bgc trip table
  identify_files_id AS (
      SELECT
         cs.file_id,
         cp."StationName",
         cp."TripCode",
         cp."Latitude",
         cp."Longitude"
      FROM ctd_selection cs 
      LEFT JOIN ctd_profiles cp ON cs.file_id = cp.file_id 
      AND (cs.minimum_absolute_time_difference =  cp.absolute_time_difference OR cs.minimum_absolute_time_difference IS NULL)
)
--create the final list for the materialised view
      SELECT
         ii."StationName",
         ii."TripCode",
         cc."TIME" AS "CastTimeUTC",
         ii."Latitude",
         ii."Longitude",
         cc."DEPTH" AS "Depth_m",
         cc."PSAL" AS "Salinity_psu",
         cc."PSAL_quality_control" AS "Salinity_flag",
         cc."TEMP" AS "Temperature_degC", 
         cc."TEMP_quality_control" AS "Temperature_flag", 
         cc."DOX2" AS "DissolvedOxygen_umolkg", 
         cc."DOX2_quality_control" AS "DissolvedOxygen_flag",
         cc."CPHL" AS "Chla_mgm3",
         cc."CPHL_quality_control" AS "Chla_flag", 
         cc."TURB" AS "Turbidity_NTU", 
         cc."TURB_quality_control" AS "Turbidity_flag", 
         cc."CNDC" AS "Conductivity_Sm", 
         cc."CNDC_quality_control" AS "Conductivity_flag", 
         cc."DENS" AS "WaterDensity_kgm3", 
         cc."DENS_quality_control" AS "WaterDensity_flag" 
      FROM anmn_nrs_ctd_profiles.measurements cc
      INNER JOIN identify_files_id ii on ii.file_id = cc.file_id
;
