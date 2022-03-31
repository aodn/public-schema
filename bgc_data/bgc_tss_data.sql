--create materialized view for tss metadata that includes all replicates
CREATE MATERIALIZED VIEW bgc_tss_data AS
   SELECT 
      bm.*,
      CONCAT(tt.trip_code,'_',tt.sampledepth_m) AS "SampleID",
      tt.sampledepth_m AS "Depth_m",
      tt.replicate AS "Replicate",
      tt.organicfraction_mgl AS "TSSorganic_mgL", 
      tt.inorganicfraction_mgl AS "TSSinorganic_mgL", 
      tt.tss_mgl AS "TSS_mgL", 
      tt.tss_flag AS "TSSall_flag",
      tt.tss_comments AS "TSScomments",
      tt.blankadjustavailable AS "BlankAdjustAvailable"
   FROM bgc_tss_meta tt
      INNER JOIN combined_bgc_map bm USING (trip_code)
;
