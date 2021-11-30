--create materialized view for chemistry
--includes metadata
CREATE MATERIALIZED VIEW bgc_chemistry_data AS
   SELECT
      bt."Project", 
      bt."StationName", 
      bt."TripCode",
      bt."SampleTime_local"::timestamp::date AS "SampleDate_Local",
--TO DO: SampleDate_UTC
      bt."Latitude",
      bt."Longitude",
      bt.secchi_m AS "SecchiDepth_m",
      che.sampledepth_m AS "Depth_m",
      che.salinity_psu AS "Salinity_psu",
      che.salinity_flag AS "Salinity_flag",
      che.dic_umolkg AS "DIC_umolkg",
      che.carbon_flag AS "DIC_flag",
      che.talkalinity_umolkg AS "Alkalinity_umolkg",
      che.alkalinity_flag AS "Alkalinity_flag",
      che.oxygen_umoll AS "Oxygen_umolL",
      che.oxygen_flag AS "Oxygen_flag",
      che.ammonium_umoll AS "NH4_umolL",
      che.ammonium_flag AS "NH4_flag",
      che.nitrite_umoll AS "NO3_umolL",
      che.nitrite_flag AS "NO3_flag",
      che.phosphate_umoll AS "PO4_umoL",
      che.phosphate_flag AS "PO4_flag",
      che.silicate_umoll AS "SiO4_umolL",
      che.silicate_flag AS "SiO4_flag",
      che.microbiomesample_id AS "MicroBiomeSa BPA mple_id" 
   FROM bgc_chemistry che
      INNER JOIN bgc_trip_metadata bt USING (trip_code)
;

