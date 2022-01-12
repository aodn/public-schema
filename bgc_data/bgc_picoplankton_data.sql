--create materialized view for picoplankton, including metadata
CREATE MATERIALIZED VIEW bgc_picoplankton_data AS
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
      prt.replicate AS "Replicate",
      prt.prochlorococcus_cellsml AS "Prochlorc_cellsmL",
      prt.prochlorococcus_flag AS "Prochlorc_flag",
      prt.synecochoccus_cellsml AS "Synechoc_cellsmL", 
      prt.synecochoccus_flag AS "Synechoc_flag",
      prt.picoeukaryotes_cellsml AS "Picoeukar_cellsmL",
      prt.picoeukaryotes_flag AS "Picoeukar_flag"
   FROM bgc_picoplankton_meta prt
      INNER JOIN  bgc_trip_metadata bt ON bt.trip_code = prt.trip_code
;
