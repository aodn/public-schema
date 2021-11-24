-- Materialized view for nrs depth binned ctd product
CREATE MATERIALIZED VIEW nrs_depth_binned_ctd_data AS

--modify the site code to match with the deployments table
--filter only for NRS stations
WITH nrs_trips AS (
      SELECT
         trip_code,
         sampledatelocal,
         CONCAT(projectname, stationcode) AS site_code
      FROM bgc_trip
      WHERE projectname = 'NRS'
),
--calculate the absolute time difference 
--match the site code and time
ctd_profiles AS (
      SELECT
         nt.trip_code,
         dp.file_id,
         dp.time_coverage_start AT TIME ZONE 'UTC' AS cast_time,
         GREATEST((nt.sampledatelocal - dp.time_coverage_start AT TIME ZONE 'UTC'),
                  -(nt.sampledatelocal - dp.time_coverage_start AT TIME ZONE 'UTC'))
             AS absolute_time_difference
      FROM nrs_trips nt 
         LEFT JOIN anmn_nrs_ctd_profiles.deployments dp
         ON dp.time_coverage_start AT TIME ZONE 'UTC' BETWEEN (nt.sampledatelocal - INTERVAL '1' DAY) AND
                                                              (nt.sampledatelocal + INTERVAL '1' DAY)
             AND dp.site_code = nt.site_code
),
--select the minimum absolute difference in time for every trip_code
ctd_selection AS (
      SELECT
         cp.trip_code,
         MIN(cp.absolute_time_difference) AS minimum_absolute_time_difference
      FROM ctd_profiles cp
      GROUP BY cp.trip_code
),
--identify the ctd files id to join on the measurements table
identify_files_id AS (
      SELECT
         cp.file_id,
         cp.trip_code
      FROM ctd_selection cs 
        LEFT JOIN ctd_profiles cp
            ON cs.trip_code = cp.trip_code
            AND (cs.minimum_absolute_time_difference = cp.absolute_time_difference
                 OR cs.minimum_absolute_time_difference IS NULL)
)
--create the final list for the materialised view
      SELECT
         bt."StationName",
         trip_code AS "TripCode",
         cc."TIME" AS "CastTimeUTC",
         bt."Latitude",
         bt."Longitude",
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
      FROM bgc_trip_metadata bt
         INNER JOIN identify_files_id ii USING (trip_code)
         LEFT JOIN anmn_nrs_ctd_profiles.measurements cc USING (file_id)
;

