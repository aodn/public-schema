--create materialized view for picoplankton, including metadata
CREATE MATERIALIZED VIEW bgc_picoplankton_data AS
   SELECT
      bm.*,
      prt.sampledepth_m AS "Depth_m",
      prt.replicate AS "Replicate",
      prt.prochlorococcus_cellsml AS "Prochlorc_cellsmL",
      prt.prochlorococcus_flag AS "Prochlorc_flag",
      prt.synecochoccus_cellsml AS "Synechoc_cellsmL", 
      prt.synecochoccus_flag AS "Synechoc_flag",
      prt.picoeukaryotes_cellsml AS "Picoeukar_cellsmL",
      prt.picoeukaryotes_flag AS "Picoeukar_flag",
      prt.pico_comments AS "PicoplankComments",
      prt.analysis_location AS "AnalysisLocation",
      prt.analysis_date AS "AnalysisDate",
      prt.analyst_name AS "AnalystName",
      prt.temp_thawed_degc AS "TempThawed_DegC",
      prt.internal_standard AS "InternalStandard",
      prt.instrument_brand_model AS "InstrumentBrandModel",
      prt.instrument_serial_number AS "InstrumentSerialNumber",
      prt.laser_nm AS "Laser_nm",
      prt.mode_type AS "ModeType",
      prt.analysis_volume_ul AS "AnalysisVolume_uL",
      prt.flow_rate_ul_per_min AS "Flowrate_uLmin",
      prt.analysis_time_minutes AS "AnalysisTime_min",
      prt.batch_comments AS "BatchComments"
   FROM bgc_picoplankton_meta prt
      INNER JOIN combined_bgc_map bm USING (trip_code)
;
