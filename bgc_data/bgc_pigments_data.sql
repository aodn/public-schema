--create materialized view for pigments
--includes metadata
CREATE MATERIALIZED VIEW bgc_pigments_data AS 
   SELECT
      bm."Project",
      bm."StationName",
      bm."TripCode",
      to_char(pig.sampledatelocal, 'YYYY-MM-DD HH24:MI:SS') AS "SampleTime_Local",
      bm."Latitude",
      bm."Longitude",
      bm."SecchiDepth_m",
      CONCAT(pig.trip_code,'_',pig.sampledepth_m) AS "SampleID",
      pig.sampledepth_m AS "SampleDepth_m",
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
      pig.cphl_c3 AS "CphlC3_mgm3",
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
      bm.geom
   FROM bgc_pigments pig
      INNER JOIN combined_bgc_map bm USING (trip_code)
;

