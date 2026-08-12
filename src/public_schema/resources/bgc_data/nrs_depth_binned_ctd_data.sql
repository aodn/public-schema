-- Materialized view for nrs depth binned ctd product
CREATE MATERIALIZED VIEW nrs_depth_binned_ctd_data AS

--create the final list for the materialised view
      SELECT
         m.*,
         cc."DEPTH" AS "SampleDepth_m",
         cc."PSAL" AS "Salinity_psu",
         cc."PSAL_quality_control" AS "Salinity_flag",
         cc."TEMP" AS "Temperature_degC", 
         cc."TEMP_quality_control" AS "Temperature_flag", 
         cc."DOX2" AS "DissolvedOxygen_umolkg", 
         cc."DOX2_quality_control" AS "DissolvedOxygen_flag",
         cc."CPHL" AS "Chla_mgm3",
         cc."CPHL_quality_control" AS "Chla_flag", 
         cc."TURB" AS "Turbidity_NTU", 
         cc."TURB_quality_control" AS "Turbidity_flag", 
         cc."CNDC" AS "Conductivity_Sm", 
         cc."CNDC_quality_control" AS "Conductivity_flag", 
         cc."DENS" AS "WaterDensity_kgm3", 
         cc."DENS_quality_control" AS "WaterDensity_flag" 
      FROM nrs_depth_binned_ctd_map m
          INNER JOIN anmn_nrs_ctd_profiles.measurements cc USING (file_id)
;

