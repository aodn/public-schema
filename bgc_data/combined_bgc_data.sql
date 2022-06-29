--create combined bgc product
CREATE MATERIALIZED VIEW combined_bgc_data AS 
--first create temporary table with averaged picoplankton data from bgc_picoplankton
WITH 
picoplankton_avg AS (
   SELECT
      prt.trip_code AS "TripCode",
      prt.sampledepth_m AS "SampleDepth_m",
      CONCAT(prt.trip_code,'_',prt.sampledepth_m) AS "SampleID",
      prt.prochlorococcus_cellsml AS "Prochlorococcus_cellsmL",
      prt.prochlorococcus_flag AS "Prochlorococcus_flag",
      prt.synecochoccus_cellsml AS "Synechococcus_cellsmL",
      prt.synecochoccus_flag AS "Synechococcus_flag",
      prt.picoeukaryotes_cellsml AS "Picoeukaryotes_cellsmL",
      prt.picoeukaryotes_flag AS "Picoeukaryotes_flag"
   FROM bgc_picoplankton prt
),
--then create temporary table with averaged tss data from bgc_tss
tss_avg AS (
   SELECT 
      tt.trip_code AS "TripCode",
      tt.sampledepth_m AS "SampleDepth_m",
      CONCAT(tt.trip_code,'_',tt.sampledepth_m) AS "SampleID",
      tt.organicfraction_mgl AS "TSSorganic_mgL", 
      tt.inorganicfraction_mgl AS "TSSinorganic_mgL", 
      tt.tss_mgl AS "TSS_mgL", 
      tt.tss_flag AS "TSSall_flag"
   FROM bgc_tss tt
),
--create temporary table with any depths associated with trip codes
trip_depths AS (
   SELECT 
      ppl."TripCode",
      ppl."SampleDepth_m",
      ppl."SampleID"
   FROM picoplankton_avg ppl
UNION
   SELECT 
      tss."TripCode",
      tss."SampleDepth_m",
      tss."SampleID"
   FROM tss_avg tss
UNION
   SELECT
      pig."TripCode",
      pig. "SampleDepth_m",
      pig."SampleID"
   FROM bgc_pigments_data pig 
UNION
   SELECT 
      che."TripCode",
      che."SampleDepth_m"::text,
      che."SampleID"
   FROM bgc_chemistry_data che
)
   SELECT
      bm.*,
      td."SampleDepth_m",
      td."SampleID",
      che."Salinity",
      che."Salinity_flag",
      che."DIC_umolkg",
      che."DIC_flag",
      che."Alkalinity_umolkg",
      che."Alkalinity_flag",
      che."Oxygen_umolL",
      che."Oxygen_flag",
      che."Ammonium_umolL",
      che."Ammonium_flag",
      che."Nitrate_umolL",
      che."Nitrate_flag",
      che."Nitrite_umolL",
      che."Nitrite_flag",
      che."Phosphate_umoL",
      che."Phosphate_flag",
      che."Silicate_umolL",
      che."Silicate_flag",
      tss."TSSorganic_mgL",
      tss."TSSinorganic_mgL",
      tss."TSS_mgL",
      tss."TSSall_flag",
      ppl."Prochlorococcus_cellsmL",
      ppl."Prochlorococcus_flag",
      ppl."Synechococcus_cellsmL",
      ppl."Synechococcus_flag",
      ppl."Picoeukaryotes_cellsmL",
      ppl."Picoeukaryotes_flag",
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
      pig."CphlC3_mgm3",
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
      che."AustralianMicrobiomeId"
   FROM trip_depths td
      INNER JOIN combined_bgc_map bm USING ("TripCode")
      LEFT JOIN tss_avg tss USING ("TripCode", "SampleDepth_m")
      LEFT JOIN picoplankton_avg ppl USING ("TripCode", "SampleDepth_m")
      LEFT JOIN bgc_pigments_data pig USING ("TripCode", "SampleDepth_m")
      LEFT JOIN bgc_chemistry_data che ON td."TripCode" = che."TripCode"
         AND td."SampleDepth_m" = che."SampleDepth_m"::text
   WHERE bm."Project" = 'NRS'
;

