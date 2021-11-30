--create materialized view for picoplankton, including metadata
CREATE MATERIALIZED VIEW bgc_picoplankton_data AS
--make average of all picoplankton required measurements with same trip_code, depth and flag numbers
--set up a rank system for flags from good to bad data with increasing numbers (i.e., lower the number -> better the data)
--every of the 3 picoplankton (prochlorococcus, synecochoccus and picoeukaryotes) has to be treated separetely because of GROUP BY  
WITH prochl_avg_tmp AS ( 
   SELECT 
      trip_code,
      sampledepth_m,
      prochlorococcus_flag,
      AVG(prochlorococcus_cellsml) AS prochl_avgs,
      (CASE WHEN prochlorococcus_flag='1' THEN '1' -- Good data
            WHEN prochlorococcus_flag='2' THEN '2' -- Probably good data
            WHEN prochlorococcus_flag='8' THEN '3' -- Interpoleted value
            WHEN prochlorococcus_flag='5' THEN '4' -- Value changed
            WHEN prochlorococcus_flag='6' THEN '5' -- Below detection limit
            WHEN prochlorococcus_flag='3' THEN '6' -- Bad data that are potentially correctable 
            WHEN prochlorococcus_flag='4' THEN '7' -- Bad data
            WHEN prochlorococcus_flag='0' THEN '8' -- No QC performed  
            WHEN prochlorococcus_flag='9' THEN '9' END) AS prochl_ranked_flags -- Missing value
   FROM bgc_picoplankton
   GROUP BY trip_code, sampledepth_m, prochlorococcus_flag
),
syneco_avg_tmp AS (	
   SELECT 
      trip_code,
      sampledepth_m,
      synecochoccus_flag,
      AVG(synecochoccus_cellsml) AS syneco_avgs,
      (CASE WHEN synecochoccus_flag='1' THEN '1' -- Good data
            WHEN synecochoccus_flag='2' THEN '2' -- Probably good data
            WHEN synecochoccus_flag='8' THEN '3' -- Interpoleted value
            WHEN synecochoccus_flag='5' THEN '4' -- Value changed
            WHEN synecochoccus_flag='6' THEN '5' -- Below detection limit
            WHEN synecochoccus_flag='3' THEN '6' -- Bad data that are potentially correctable 
            WHEN synecochoccus_flag='4' THEN '7' -- Bad data
            WHEN synecochoccus_flag='0' THEN '8' -- No QC performed  
            WHEN synecochoccus_flag='9' THEN '9' END) AS syneco_ranked_flags -- Missing value
   FROM bgc_picoplankton
   GROUP BY trip_code, sampledepth_m, synecochoccus_flag
), 
picoeuk_avg_tmp AS (	
   SELECT 
      trip_code,
      sampledepth_m,
      picoeukaryotes_flag,
      AVG(picoeukaryotes_cellsml) AS picoeuk_avgs,
      (CASE WHEN picoeukaryotes_flag='1' THEN '1' -- Good data
            WHEN picoeukaryotes_flag='2' THEN '2' -- Probably good data
            WHEN picoeukaryotes_flag='8' THEN '3' -- Interpoleted value
            WHEN picoeukaryotes_flag='5' THEN '4' -- Value changed
            WHEN picoeukaryotes_flag='6' THEN '5' -- Below detection limit
            WHEN picoeukaryotes_flag='3' THEN '6' -- Bad data that are potentially correctable 
            WHEN picoeukaryotes_flag='4' THEN '7' -- Bad data
            WHEN picoeukaryotes_flag='0' THEN '8' -- No QC performed  
            WHEN picoeukaryotes_flag='9' THEN '9' END) AS picoeuk_ranked_flags -- Missing value
   FROM bgc_picoplankton
   GROUP BY trip_code, sampledepth_m, picoeukaryotes_flag
),
--pick the best flag associated with a trip code, thus selecting a single trip code (i.e., best flag from replicate/s and/or replicates average)
prochl_flag_selection AS (
   SELECT 
      trip_code,
      sampledepth_m,
      MIN(prochl_ranked_flags) AS prochl_flag_match
   FROM prochl_avg_tmp
   GROUP BY trip_code, sampledepth_m
),
syneco_flag_selection AS (
   SELECT 
      trip_code,
      sampledepth_m,
      MIN(syneco_ranked_flags) AS syneco_flag_match
   FROM syneco_avg_tmp
   GROUP BY trip_code, sampledepth_m
),
picoeuk_flag_selection AS (
   SELECT 
      trip_code,
      sampledepth_m,
      MIN(picoeuk_ranked_flags) AS picoeuk_flag_match
   FROM picoeuk_avg_tmp
   GROUP BY trip_code, sampledepth_m
),
--select the data associated with the best flag for each of the 3 picoplankton
prochl_tmp AS (
   SELECT 
      tt.trip_code,
      tt.sampledepth_m,
      tt.prochl_avgs, 
      tt.prochlorococcus_flag
   FROM prochl_avg_tmp tt
      INNER JOIN prochl_flag_selection fsl ON fsl.trip_code = tt.trip_code
      AND fsl.prochl_flag_match = tt.prochl_ranked_flags
      AND fsl.sampledepth_m = tt.sampledepth_m
   GROUP BY tt.trip_code, tt.sampledepth_m, tt.prochl_avgs, tt.prochlorococcus_flag
),
syneco_tmp AS (
   SELECT 
      tt.trip_code,
      tt.sampledepth_m,
      tt.syneco_avgs, 
      tt.synecochoccus_flag
   FROM syneco_avg_tmp tt
      INNER JOIN syneco_flag_selection fsl ON fsl.trip_code = tt.trip_code
      AND fsl.syneco_flag_match = tt.syneco_ranked_flags
      AND fsl.sampledepth_m = tt.sampledepth_m
   GROUP BY tt.trip_code, tt.sampledepth_m, tt.syneco_avgs, tt.synecochoccus_flag
),
picoeuk_tmp AS (
   SELECT 
      tt.trip_code,
      tt.sampledepth_m,
      tt.picoeuk_avgs, 
      tt.picoeukaryotes_flag
   FROM picoeuk_avg_tmp tt
      INNER JOIN picoeuk_flag_selection fsl ON fsl.trip_code = tt.trip_code
      AND fsl.picoeuk_flag_match = tt.picoeuk_ranked_flags
      AND fsl.sampledepth_m = tt.sampledepth_m
   GROUP BY tt.trip_code, tt.sampledepth_m, tt.picoeuk_avgs, tt.picoeukaryotes_flag
)
--combine all required 3 picoplankton selected data with metadata for materialised view
   SELECT
      bt."Project", 
      bt."StationName", 
      bt."TripCode",
      bt."SampleTime_local"::timestamp::date AS "SampleDate_Local",
--TO DO: SampleDate_UTC
      bt."Latitude",
      bt."Longitude",
      bt.secchi_m AS "SecchiDepth_m",
      prt.sampledepth_m AS "Depth_m",
      prt.prochl_avgs AS "Prochlorc_cellsmL",
      prt.prochlorococcus_flag AS "Prochlorc_flag",
      st.syneco_avgs AS "Synechoc_cellsmL", 
      st.synecochoccus_flag AS "Synechoc_flag",
      pt.picoeuk_avgs AS "Picoeukar_cellsmL",
      pt.picoeukaryotes_flag AS "Picoeukar_flag"
   FROM prochl_tmp prt
      INNER JOIN syneco_tmp st ON prt.trip_code = st.trip_code
      INNER JOIN picoeuk_tmp pt ON pt.trip_code = st.trip_code
          AND prt.trip_code = pt.trip_code
          AND prt.sampledepth_m = st.sampledepth_m
          AND pt.sampledepth_m = st.sampledepth_m
          AND prt.sampledepth_m = pt.sampledepth_m
      INNER JOIN  bgc_trip_metadata bt ON bt.trip_code = prt.trip_code
;

