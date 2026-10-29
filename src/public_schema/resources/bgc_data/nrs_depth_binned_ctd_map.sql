-- View for nrs depth binned ctd product metadata (not actually used as a map layer)
CREATE OR REPLACE VIEW nrs_depth_binned_ctd_map AS

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
      FROM bgc_trip
      WHERE projectname = 'NRS'
),
ctd_debployments AS (
      SELECT DISTINCT
         site_code,
         filename,
         time::timestamp AS cast_time
      FROM nrs_ctd_profiles_from_parquet
      WHERE site_code LIKE 'NRS%'
),
--calculate the absolute time difference
--match the site code and time
ctd_profiles AS (
      SELECT
         nt.trip_code,
         dp.filename,
         dp.cast_time,
         GREATEST((nt.sampledateutc - dp.cast_time), -(nt.sampledateutc - dp.cast_time))
             AS absolute_time_difference
      FROM nrs_trips nt INNER JOIN ctd_debployments dp
         ON dp.cast_time BETWEEN (nt.sampledateutc - INTERVAL '1' DAY) AND
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
         bt."Project",
         bt."StationName",
         trip_code AS "TripCode",
         mp.cast_time AS "CastTimeUTC",
         -- TODO: CastTimeLocal,
         bt."Latitude",
         bt."Longitude",
         -- last 4 columns only included for joining to other tables and filtering on the Portal
         mp.filename,
         bt."SampleTime_Local",
         bt."SampleTime_UTC",
         trip_code,
         bt.geom
      FROM bgc_trip_metadata bt
         INNER JOIN matched_profiles mp USING (trip_code)
;
