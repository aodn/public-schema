--create materialized view for chemistry
--includes metadata
CREATE MATERIALIZED VIEW bgc_chemistry_data AS
   SELECT
      bm."Project",
      bm."StationName",
      bm."TripCode",
      bm."TripDate_UTC",
      to_char(che.sampledatelocal, 'YYYY-MM-DD HH24:MI:SS') AS "SampleTime_Local",
      bm."Latitude",
      bm."Longitude",
      bm."SecchiDepth_m",
      CONCAT(che.trip_code,'_',che.sampledepth_m) AS "SampleID",
      che.sampledepth_m AS "SampleDepth_m",
      che.salinity_psu AS "Salinity",
      che.salinity_flag AS "Salinity_flag",
      che.dic_umolkg AS "DIC_umolkg",
      che.carbon_flag AS "DIC_flag",
      che.talkalinity_umolkg AS "Alkalinity_umolkg",
      che.alkalinity_flag AS "Alkalinity_flag",
      che.oxygen_umoll AS "Oxygen_umolL",
      che.oxygen_flag AS "Oxygen_flag",
      che.ammonium_umoll AS "Ammonium_umolL",
      che.ammonium_flag AS "Ammonium_flag",
      che.nitrate_umoll AS "Nitrate_umolL",
      che.nitrate_flag AS "Nitrate_flag",
      che.nitrite_umoll AS "Nitrite_umolL",
      che.nitrite_flag AS "Nitrite_flag",
      che.phosphate_umoll AS "Phosphate_umolL",
      che.phosphate_flag AS "Phosphate_flag",
      che.silicate_umoll AS "Silicate_umolL",
      che.silicate_flag AS "Silicate_flag",
      che.microbiomesample_id AS "AustralianMicrobiomeId",
      bm.geom
   FROM bgc_chemistry che
      INNER JOIN combined_bgc_map bm USING (trip_code)
;

