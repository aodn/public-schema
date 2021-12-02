-- View for nrs depth binned ctd product metadata (not actually used as a map layer)
CREATE VIEW nrs_depth_binned_ctd_map AS

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
      FROM nrs_trips nt INNER JOIN anmn_nrs_ctd_profiles.deployments dp
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
         cp.cast_time,
         cp.trip_code
      FROM ctd_selection cs INNER JOIN ctd_profiles cp
            ON cs.trip_code = cp.trip_code
            AND cs.minimum_absolute_time_difference = cp.absolute_time_difference
)
--create the final list for the materialised view
      SELECT
         bt."StationName",
         trip_code AS "TripCode",
         ii.cast_time AS "CastTimeUTC",
         -- TODO: CastTimeLocal,
         bt."Latitude",
         bt."Longitude",
         -- last 4 columns only included for joining to other tables and filtering on the Portal
         ii.file_id,
         bt."SampleTime_local",
         trip_code,
         bt.geom
      FROM bgc_trip_metadata bt
         INNER JOIN identify_files_id ii USING (trip_code)
;
