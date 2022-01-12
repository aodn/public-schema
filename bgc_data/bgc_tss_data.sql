--create materialized view for tss metadata that includes all replicates
CREATE MATERIALIZED VIEW bgc_tss_data AS
   SELECT 
      bt."Project", 
      bt."StationName", 
      bt."TripCode",
      bt."SampleTime_local"::timestamp::date AS "SampleDate_Local",
--TO DO: SampleDate_UTC
      bt."Latitude",
      bt."Longitude",
      bt.secchi_m AS "SecchiDepth_m",
      tt.sampledepth_m AS "Depth_m",
      tt.replicate AS "Replicate",
      tt.organicfraction_mgl AS "TSSorganic_mgL", 
      tt.inorganicfraction_mgl AS "TSSinorganic_mgL", 
      tt.tss_mgl AS "TSS_mgL", 
      tt.tss_flag AS "TSSall_flag",
      tt.tss_comments AS "TSScomments",
      tt.blankadjustavailable AS "BlankAdjustAvailable"
   FROM bgc_tss_meta tt
      INNER JOIN bgc_trip_metadata bt ON bt.trip_code = tt.trip_code
;
