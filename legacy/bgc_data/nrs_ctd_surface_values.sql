-- Extract the near-surface measurements of temperature, salinity and chlorophyll
-- from each CTD profile matched up with an NRS sampling trip in nrs_depth_binned_ctd_data
-- The values extracted are those measured nearest to 10m depth (and at least between 5m and 15m).
CREATE VIEW nrs_ctd_surface_values AS
  SELECT DISTINCT ON (trip_code)
      trip_code,
      "SampleDepth_m",
      abs("SampleDepth_m" - 10) AS depth_diff,
      CASE WHEN "Temperature_flag" IN ('3', '4') THEN NULL
           ELSE "Temperature_degC"
          END AS "CTDSST_degC",
      CASE WHEN "Chla_flag" IN ('3', '4') THEN NULL
           ELSE "Chla_mgm3"
          END AS "CTDChlaSurf_mgm3",
      CASE WHEN "Salinity_flag" IN ('3', '4') THEN NULL
           ELSE "Salinity_psu"
          END AS "CTDSalinity_psu"
  FROM nrs_depth_binned_ctd_data
  WHERE abs("SampleDepth_m" - 10) <= 5
  ORDER BY trip_code, depth_diff
;
