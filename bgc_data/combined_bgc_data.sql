set search_path = imos_bgc_db, public;
/* 
--tss cases checks
where trip_code = 'DAR20110627' 
OR trip_code = 'DAR20111005'
OR trip_code = 'DAR20210727'
OR trip_code = 'MAI20090907'
OR trip_code = 'YON20090909'
order by trip_code
--picoplankton cases checks
where trip_code = 'MAI20111214'
OR trip_code = 'DAR20171009'
OR trip_code = 'MAI20120119'
OR trip_code = 'DAR20120417'
order by trip_code
*/

--tss
--make average of all tss requred measurements with same trip_code, depth and flag numbers
--set up a rank system for flags from good to bad data with increasing numbers (i.e., lower the number -> better the data)
WITH 
tss_avg_tmp AS (
   SELECT 
      trip_code,
      tss_flag,
      sampledepth_m,
      (CASE WHEN tss_flag='1' THEN '1' -- Good data
            WHEN tss_flag='2' THEN '2' -- Probably good data
            WHEN tss_flag='0' THEN '3' -- No QC performed  
            WHEN tss_flag='8' THEN '4' -- Interpoleted value
            WHEN tss_flag='5' THEN '5' -- Value changed
            WHEN tss_flag='6' THEN '6' -- Below detection limit
            WHEN tss_flag='3' THEN '7' -- Bad data that are potentially correctable
            WHEN tss_flag='4' THEN '8' -- Bad data
            WHEN tss_flag='9' THEN '9' END) AS ranked_flags, -- Missing value
      AVG(tss_mgl) AS tss_avgs,
      AVG(inorganicfraction_mgl) AS inorganic_avgs,
      AVG(organicfraction_mgl) AS organic_avgs
   FROM bgc_tss 
      GROUP BY trip_code, tss_flag, sampledepth_m
),
--pick the best flag associated with a trip code, thus selecting a single trip code (i.e., best flag from replicate/s and/or replicates average)
tss_flag_selection AS (
   SELECT 
      trip_code,
      sampledepth_m,
      MIN(ranked_flags) AS flag_match
   FROM tss_avg_tmp
   GROUP BY trip_code, sampledepth_m  --need to group by sample depth as 1 sample has 2 depths: WC and 0
),
--create temporary table with required information for tss to join with other data for the final combined product
tss_final AS (
   SELECT 
      tt.trip_code,
      tt.sampledepth_m,
      tt.tss_avgs,
      tt.inorganic_avgs,
      tt.organic_avgs,
      tt.tss_flag
   FROM tss_avg_tmp tt
      INNER JOIN tss_flag_selection fsl ON fsl.trip_code = tt.trip_code
	  AND fsl.flag_match = tt.ranked_flags
      AND fsl.sampledepth_m = tt.sampledepth_m
   GROUP BY tt.trip_code, tt.sampledepth_m, tt.tss_avgs, tt.inorganic_avgs, tt.organic_avgs, tt.tss_flag
),
--picoplankton
--Make average of all picoplankton requred measurements with same trip_code, depth and flag numbers
--set up a rank system for flags from good to bad data with increasing numbers (i.e., lower the number -> better the data)
--Every of the 3 picoplankton (prochlorococcus, synecochoccus and picoeukaryotes) has to be treated separetely because of the GROUP BY  
prochl_avg_tmp AS ( 
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
--need to be done independently for each of the 3 picoplankton because of the GROUP BY 
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
--select the data associated with the best flag for each of the 3 picoplankton, need to be separate temporay tables because of the GROUP BY
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
),
--combine all required 3 picoplankton selected data in a temporary table to join with other data for the final combined product
picopl_final AS (
   SELECT 
      prt.trip_code,
      prt.sampledepth_m,
      prt.prochl_avgs, 
      prt.prochlorococcus_flag,
      st.syneco_avgs, 
      st.synecochoccus_flag,
      pt.picoeuk_avgs,
      pt.picoeukaryotes_flag
   FROM prochl_tmp prt
      INNER JOIN syneco_tmp st ON prt.trip_code = st.trip_code
         INNER JOIN picoeuk_tmp pt ON pt.trip_code = st.trip_code
	     AND prt.trip_code = pt.trip_code
	     AND prt.sampledepth_m = st.sampledepth_m
	     AND pt.sampledepth_m = st.sampledepth_m
	     AND prt.sampledepth_m = pt.sampledepth_m
),
--create temporaty table with any depths associated with trip codes
trip_depths AS (
   SELECT DISTINCT
      ppl.trip_code,
	  ppl.sampledepth_m
   FROM picopl_final ppl
UNION
	SELECT DISTINCT
      tss.trip_code,
	  tss.sampledepth_m 
   FROM tss_final tss
UNION
   SELECT DISTINCT
      pig.trip_code,
      pig.sampledepth_m
   FROM bgc_pigments pig 
UNION
  SELECT
      che.trip_code,
	  che.sampledepth_m::text 
   FROM bgc_chemistry che
)
SELECT
      bt.stationname AS "StationName", 
      bt.trip_code AS "TripCode",
      bt.sampledatelocal AS "SampleDate_Local",
      bt.latitude AS "Latitude",
      bt.longitude AS "Longitude",
	  td.sampledepth_m AS "Depth_m",
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
      tss.organic_avgs AS "TSSorganic_mgL",
      tss.inorganic_avgs AS "TSSinorganic_mgL",
      tss.tss_avgs AS "TSS_mgL",
      tss.tss_flag AS "TSSall_flag",
      bt.secchi_m AS "SecchiDepth_m",
      ppl.prochl_avgs AS "Prochlorc_cellsmL",
      ppl.prochlorococcus_flag AS "Prochlorc_flag",
      ppl.syneco_avgs AS "Synechoc_cellsmL",
      ppl.synecochoccus_flag AS "Synechoc_flag",
      ppl.picoeuk_avgs AS "Picoeukar_cellsmL",
      ppl.picoeukaryotes_flag AS "Picoeukar_flag",
      pig.allo AS "Allo_mgm3",
      pig.alpha_beta_car AS "AlphaBetaCar_mgm3",
      pig.anth AS "Anth_mgm3",
      pig.asta AS "Asta_mgm3",
      pig.beta_beta_car AS "BetaBetaCar_mgm3",
      pig.beta_epi_car AS "BetaEpiCar_mgm3",
      pig.but_fuco AS "Butfuco_mgm3",
      pig.cantha AS "Cantha_mgm3",
      pig.cphl_a AS "CphlA_mgm3",
      pig.cphl_b AS "CphlB_mgm3",
      pig.cphl_c1 AS "CphlC1_mgm3",
      pig.cphl_c2 AS "CphlC2_mgm3",
      pig.cphl_c1c2 AS "CphlC1C2_mgm3",
      pig.cphlide_a AS "CphlideA_mgm3",
      pig.diadchr AS "Diadchr_mgm3",
      pig.diadino AS "Diadino_mgm3",
      pig.diato AS "Diato_mgm3",
      pig.dino AS "Dino_mgm3",
      pig.dv_cphl_a_and_cphl_a AS "DvCphlA+CphlA_mgm3",
      pig.dv_cphl_a AS "DvCphlA_mgm3",
      pig.dv_cphl_b_and_cphl_b AS "DvCphlB+CphlB_mgm3",
      pig.dv_cphl_b AS "DvCphlB_mgm3",
      pig.echin AS "Echin_mgm3",
      pig.fuco AS "Fuco_mgm3",
      pig.gyro AS "Gyro_mgm3",
      pig.hex_fuco AS "Hexfuco_mgm3",
      pig.keto_hex_fuco AS "Ketohexfuco_mgm3",
      pig.lut AS "Lut_mgm3",
      pig.lyco AS "Lyco_mgm3",
      pig.mg_dvp AS "MgDvp_mgm3",
      pig.neo AS "Neo_mgm3",
      pig.perid AS "Perid_mgm3",
      pig.phide_a AS "PhideA_mgm3",
      pig.phytin_a AS "PhytinA_mgm3",
      pig.phytin_b AS "PhytinB_mgm3",
      pig.pras AS "Pras_mgm3",
      pig.pyrophide_a AS "PyrophideA_mgm3",
      pig.pyrophytin_a AS "PyrophytinA_mgm3",
      pig.viola AS "Viola_mgm3",
      pig.zea AS "Zea_mgm3",
      pig.pigments_flag AS "Pigments_flag",
      che.microbiomesample_id AS "MicroBiomeSa BPA mple_id" --happy to leave spaces here?
   FROM trip_depths td
      INNER JOIN bgc_trip bt ON td.trip_code = bt.trip_code
      LEFT JOIN tss_final tss ON td.trip_code = tss.trip_code
	  AND td.sampledepth_m = tss.sampledepth_m
	  LEFT JOIN picopl_final ppl ON td.trip_code = ppl.trip_code
	  AND td.sampledepth_m = ppl.sampledepth_m
	  LEFT JOIN bgc_chemistry che ON td.trip_code = che.trip_code
	  AND td.sampledepth_m = che.sampledepth_m::text
      LEFT JOIN bgc_pigments pig ON td.trip_code = pig.trip_code
	  AND td.sampledepth_m = pig.sampledepth_m

--group by ppl.sampledepth_m, tss.sampledepth_m, bt.trip_code, tss.organic_avgs, tss.inorganic_avgs, tss.inorganic_avgs, tss.tss_avgs, tss.tss_flag, ppl.picoeuk_avgs, ppl.picoeukaryotes_flag 
--      tss.trip_code,
--      tss.sampledepth_m,
--      prt.trip_code,
--      prt.sampledepth_m,
--where bt.trip_code='KAI20110427'
--order by bt.trip_code


--select * from picopl_final 
--select distinct trip_code, sampledepth_m from picopl_final
--select * from tss_final where trip_code= 'KAI20110427' 
--tss 2 depths

--select * from bgc_chemistry where sampledepth_m IS NULL
--select * from tss_final 
--select * from picopl_final 
--select * from trip_depths
--select distinct sampledepth_m from bgc_tss
--where td.trip_code= 'KAI20110427'
--or td.trip_code= 'MAI20111214'
--order by td.trip_code, td.sampledepth_m

