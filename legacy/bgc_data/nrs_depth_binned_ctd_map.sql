-- View for nrs depth binned ctd product metadata (not actually used as a map layer)
CREATE VIEW nrs_depth_binned_ctd_map AS

--modify the site code to match with the deployments table
--filter only for NRS stations
WITH nrs_trips AS (
      SELECT
         trip_code,
         sampledateutc,
         -- Manually adjust site code for VBM station
         CASE
             WHEN stationcode = 'VBM' THEN 'VBM100'
             ELSE CONCAT(projectname, stationcode)
         END AS site_code
      FROM imos_bgc_db.bgc_trip
      WHERE projectname = 'NRS'
),
--calculate the absolute time difference 
--match the site code and time
ctd_profiles AS (
      SELECT
         nt.trip_code,
         dp.file_id,
         dp.time_coverage_start AT TIME ZONE 'UTC' AS cast_time,
         GREATEST((nt.sampledateutc - dp.time_coverage_start AT TIME ZONE 'UTC'),
                  -(nt.sampledateutc - dp.time_coverage_start AT TIME ZONE 'UTC'))
             AS absolute_time_difference
      FROM nrs_trips nt INNER JOIN anmn_nrs_ctd_profiles.deployments dp
         ON dp.time_coverage_start AT TIME ZONE 'UTC' BETWEEN (nt.sampledateutc - INTERVAL '1' DAY) AND
                                                              (nt.sampledateutc + INTERVAL '1' DAY)
         AND dp.site_code = nt.site_code
),
--for each trip, pick the cast that is closest in time
matched_profiles AS (
      SELECT DISTINCT ON (trip_code) *
      FROM ctd_profiles
      ORDER BY trip_code, absolute_time_difference
)
--create the final list for the materialised view
      SELECT
         bt."Project", --required for filter in Geoserver (step 2 portal)
         bt."StationName",
         trip_code AS "TripCode",
         mp.cast_time AS "CastTimeUTC",
         -- TODO: CastTimeLocal,
         bt."Latitude",
         bt."Longitude",
         -- last 4 columns only included for joining to other tables and filtering on the Portal
         mp.file_id,
         bt."SampleTime_Local",
         bt."SampleTime_UTC", --required for filter in Geoserver (step 2 portal)
         trip_code,
         bt.geom
      FROM bgc_trip_metadata bt
         INNER JOIN matched_profiles mp USING (trip_code)
;
