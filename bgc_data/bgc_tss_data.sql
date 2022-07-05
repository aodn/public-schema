--create materialized view for tss metadata that includes all replicates
CREATE MATERIALIZED VIEW bgc_tss_data AS
   SELECT 
      bm."Project",
      bm."StationName",
      bm."TripCode",
      bm."TripDate_UTC",
      to_char(tt.sampledatelocal, 'YYYY-MM-DD HH24:MI:SS') AS "SampleTime_Local",
      bm."Latitude",
      bm."Longitude",
      bm."SecchiDepth_m",
      CONCAT(tt.trip_code,'_',tt.sampledepth_m) AS "SampleID",
      tt.sampledepth_m AS "SampleDepth_m",
      tt.replicate AS "Replicate",
      tt.organicfraction_mgl AS "TSSorganic_mgL", 
      tt.inorganicfraction_mgl AS "TSSinorganic_mgL", 
      tt.tss_mgl AS "TSS_mgL", 
      tt.tss_flag AS "TSSall_flag",
      tt.tss_comments AS "TSScomments",
      tt.blankadjustavailable AS "BlankAdjustAvailable",
      bm.geom
   FROM bgc_tss_meta tt
      INNER JOIN combined_bgc_map bm USING (trip_code)
;
