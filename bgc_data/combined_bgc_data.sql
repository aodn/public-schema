--create combined bgc product

CREATE MATERIALIZED VIEW combined_bgc_data AS 
--create temporary table with any depths associated with trip codes
WITH trip_depths AS (
   SELECT DISTINCT
      ppl."TripCode",
      ppl."Depth_m"
   FROM bgc_picoplankton_data ppl
UNION
   SELECT DISTINCT
      tss."TripCode",
      tss."Depth_m" 
   FROM bgc_tss_data tss
UNION
   SELECT DISTINCT
      pig."TripCode",
      pig. "Depth_m"
   FROM bgc_pigments_data pig 
UNION
   SELECT
      che."TripCode",
      che."Depth_m"::text 
   FROM bgc_chemistry_data che
)
   SELECT
      bt."Project", 
      bt."StationName", 
      bt."TripCode",
      bt."SampleTime_local"::timestamp::date AS "SampleDate_Local",
--TO DO: SampleDate_UTC
      bt."Latitude",
      bt."Longitude",
      td."Depth_m",
      che."Salinity_psu",
      che."Salinity_flag",
      che."DIC_umolkg",
      che."DIC_flag",
      che."Alkalinity_umolkg",
      che."Alkalinity_flag",
      che."Oxygen_umolL",
      che."Oxygen_flag",
      che."NH4_umolL",
      che."NH4_flag",
      che."NO3_umolL",
      che."NO3_flag",
      che."PO4_umoL",
      che."PO4_flag",
      che."SiO4_umolL",
      che."SiO4_flag",
      tss."TSSorganic_mgL",
      tss."TSSinorganic_mgL",
      tss."TSS_mgL",
      tss."TSSall_flag",
      bt.secchi_m AS "SecchiDepth_m",
      ppl."Prochlorc_cellsmL",
      ppl."Prochlorc_flag",
      ppl."Synechoc_cellsmL",
      ppl."Synechoc_flag",
      ppl."Picoeukar_cellsmL",
      ppl."Picoeukar_flag",
      pig."Allo_mgm3",
      pig."AlphaBetaCar_mgm3",
      pig."Anth_mgm3",
      pig."Asta_mgm3",
      pig."BetaBetaCar_mgm3",
      pig."BetaEpiCar_mgm3",
      pig."Butfuco_mgm3",
      pig."Cantha_mgm3",
      pig."CphlA_mgm3",
      pig."CphlB_mgm3",
      pig."CphlC1_mgm3",
      pig."CphlC2_mgm3",
      pig."CphlC1C2_mgm3",
      pig."CphlideA_mgm3",
      pig."Diadchr_mgm3",
      pig."Diadino_mgm3",
      pig."Diato_mgm3",
      pig."Dino_mgm3",
      pig."DvCphlA+CphlA_mgm3",
      pig."DvCphlA_mgm3",
      pig."DvCphlB+CphlB_mgm3",
      pig."DvCphlB_mgm3",
      pig."Echin_mgm3",
      pig."Fuco_mgm3",
      pig."Gyro_mgm3",
      pig."Hexfuco_mgm3",
      pig."Ketohexfuco_mgm3",
      pig."Lut_mgm3",
      pig."Lyco_mgm3",
      pig."MgDvp_mgm3",
      pig."Neo_mgm3",
      pig."Perid_mgm3",
      pig."PhideA_mgm3",
      pig."PhytinA_mgm3",
      pig."PhytinB_mgm3",
      pig."Pras_mgm3",
      pig."PyrophideA_mgm3",
      pig."PyrophytinA_mgm3",
      pig."Viola_mgm3",
      pig."Zea_mgm3",
      pig."Pigments_flag",
      che."MicroBiomeSa BPA mple_id"
   FROM trip_depths td
      INNER JOIN bgc_trip_metadata bt ON td."TripCode" = bt.trip_code
      LEFT JOIN bgc_tss_data tss ON td."TripCode" = tss."TripCode"
         AND td."Depth_m" = tss."Depth_m"
      LEFT JOIN bgc_picoplankton_data ppl ON td."TripCode" = ppl."TripCode"
         AND td."Depth_m" = ppl."Depth_m"
      LEFT JOIN bgc_chemistry_data che ON td."TripCode" = che."TripCode"
         AND td."Depth_m" = che."Depth_m"::text
      LEFT JOIN bgc_pigments_data pig ON td."TripCode" = pig."TripCode"
         AND td."Depth_m" = pig."Depth_m"
;

