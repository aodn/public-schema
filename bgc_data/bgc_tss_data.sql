--create materialized view for tss
CREATE MATERIALIZED VIEW bgc_tss_data AS

--make average of all tss required measurements with same trip_code, depth and flag numbers
--set up a rank system for flags from good to bad data with increasing numbers (i.e., lower the number -> better the data)
WITH 
tss_avg_tmp AS (
   SELECT 
      trip_code,
      tss_flag,
      sampledepth_m,
      (CASE WHEN tss_flag='1' THEN '1' -- Good data
            WHEN tss_flag='2' THEN '2' -- Probably good data
            WHEN tss_flag='0' THEN '3' -- No QC performed  
            WHEN tss_flag='8' THEN '4' -- Interpoleted value
            WHEN tss_flag='5' THEN '5' -- Value changed
            WHEN tss_flag='6' THEN '6' -- Below detection limit
            WHEN tss_flag='3' THEN '7' -- Bad data that are potentially correctable
            WHEN tss_flag='4' THEN '8' -- Bad data
            WHEN tss_flag='9' THEN '9' END) AS ranked_flags, -- Missing value
      AVG(tss_mgl) AS tss_avgs,
      AVG(inorganicfraction_mgl) AS inorganic_avgs,
      AVG(organicfraction_mgl) AS organic_avgs
   FROM bgc_tss 
      GROUP BY trip_code, tss_flag, sampledepth_m
),
--pick the best flag associated with a trip code, thus selecting a single trip code (i.e., best flag from replicate/s and/or replicates average)
tss_flag_selection AS (
   SELECT 
      trip_code,
      sampledepth_m,
      MIN(ranked_flags) AS flag_match
   FROM tss_avg_tmp
   GROUP BY trip_code, sampledepth_m  --need to group by sample depth as 1 sample has 2 depths: WC and 0
)
--list tss averages and metadata for materialised view
   SELECT 
      bt.projectname AS "ProjectName", 
      bt.stationname AS "StationName", 
      bt.trip_code AS "TripCode",
      bt.sampledatelocal AS "SampleDate_Local",
      bt.latitude AS "Latitude",
      bt.longitude AS "Longitude",
      bt.secchi_m AS "SecchiDepth_m",
      tt.sampledepth_m AS "Depth_m",
      tt.organic_avgs AS "TSSorganic_mgL",
      tt.inorganic_avgs AS "TSSinorganic_mgL",
      tt.tss_avgs AS "TSS_mgL",
      tt.tss_flag AS "TSSall_flag"
   FROM tss_avg_tmp tt
      INNER JOIN tss_flag_selection fsl ON fsl.trip_code = tt.trip_code
      AND fsl.flag_match = tt.ranked_flags
      AND fsl.sampledepth_m = tt.sampledepth_m
      INNER JOIN bgc_trip bt ON bt.trip_code = fsl.trip_code
;

