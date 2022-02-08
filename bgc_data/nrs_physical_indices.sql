-- Physical properties to include in the NRS Derived Indices product

WITH ctd_data AS (
    SELECT trip_code,
           "Depth_m",
           "Temperature_degC",
           "Salinity_psu",
           "Chla_mgm3",
           CASE WHEN substr(trip_code, 1, 3) IN ('DAR', 'YON') THEN 5
                ELSE 10
               END AS target_ref_depth
    FROM nrs_depth_binned_ctd_data
), ref_values AS (
    -- set reference depth, temp & sal from nearest data to target ref depth
    -- for MLD estimates (Ref: Condie & Dunn 2006)
    SELECT DISTINCT ON (trip_code)
        trip_code,
        "Depth_m" AS ref_depth,
        abs("Depth_m" - target_ref_depth) AS depth_diff,
        "Temperature_degC" - 0.4 AS ref_temp,
        "Salinity_psu" - 0.03 AS ref_sal
  FROM ctd_data
  ORDER BY trip_code, depth_diff
), mld_temp AS (
    -- temp-based MLD estimate
    -- the depth with temperature closest to ref temp (and > ref_depth)
    SELECT DISTINCT ON (trip_code)
        trip_code,
        abs(c."Temperature_degC" - r.ref_temp) as temp_diff,
        c."Depth_m" AS "MLDtemp_m"
    FROM ctd_data c LEFT JOIN ref_values r USING (trip_code)
    WHERE c."Depth_m" > r.ref_depth
    ORDER BY trip_code, temp_diff
), mld_sal AS (
    -- salinity-based MLD estimate
    -- the depth with salinity closest to ref salinity (and > ref_depth)
    SELECT DISTINCT ON (trip_code)
        trip_code,
        abs(c."Salinity_psu" - r.ref_sal) as sal_diff,
        c."Depth_m" AS "MLDsal_m"
    FROM ctd_data c LEFT JOIN ref_values r USING (trip_code)
    WHERE c."Depth_m" > r.ref_depth
    ORDER BY trip_code, sal_diff
), dcm AS (
    -- DCM is the depth corresponding to maximum Chlorophyll concentration
    -- at depth > ref_depth
    SELECT DISTINCT ON (trip_code)
        trip_code,
        c."Depth_m" AS "DCM_m"
    FROM ctd_data c LEFT JOIN ref_values r USING (trip_code)
    WHERE c."Depth_m" > r.ref_depth
    ORDER BY trip_code, "Chla_mgm3" DESC
), ctd_surface AS (
    -- take the average of the top 15m as surface values
    SELECT trip_code,
           avg("Temperature_degC") AS "CTDTemperature_degC",
           avg("Chla_mgm3") AS "CTDChlaF_mgm3",
           avg("Salinity_psu") AS "CTDSalinity_PSU"
    FROM nrs_depth_binned_ctd_data
    WHERE "Depth_m" < 15
    GROUP BY trip_code
), chemistry_avg AS (
    -- select the chemical parameters we need, filter out bad data (keep only flags 0, 1, 2)
    -- average over all depths for each trip
    SELECT trip_code,
           avg(silicate_umoll) FILTER ( WHERE silicate_flag < 3 ) AS "Silicate_umolL",
           avg(phosphate_umoll) FILTER ( WHERE phosphate_flag < 3 ) AS "Phosphate_umolL",
           avg(ammonium_umoll) FILTER ( WHERE ammonium_flag < 3 ) AS "Ammonium_umolL",
           avg(nitrate_umoll) FILTER ( WHERE nitrate_flag < 3 ) AS "Nitrate_umolL",
           avg(nitrite_umoll) FILTER ( WHERE nitrite_flag < 3 ) AS "Nitrite_umolL",
           avg(oxygen_umoll) FILTER ( WHERE oxygen_flag < 3 ) AS "Oxygen_umolL",
           avg(dic_umolkg) FILTER ( WHERE carbon_flag < 3 ) AS "DIC_umolkg",
           avg(talkalinity_umolkg) FILTER ( WHERE alkalinity_flag < 3 ) AS "Alkalinity_umolkg"
    FROM bgc_chemistry
    GROUP BY trip_code
), pigments_avg AS (
    -- extract Chlorophyll a from raw pigments data
    -- average over measurements taken at depths < 25m
    SELECT trip_code,
           avg(dv_cphl_a_and_cphl_a) AS "PigmentChla_mgm3"
    FROM bgc_pigments
    WHERE sampledepth_m != 'WC' AND sampledepth_m::numeric < 25
    GROUP BY trip_code
)

SELECT trip_code AS "TripCode",
       mt."MLDtemp_m",
       ms."MLDsal_m",
       d."DCM_m",
       ctd."CTDTemperature_degC",
       ctd."CTDChlaF_mgm3",
       ctd."CTDSalinity_PSU",
       ch."Silicate_umolL",
       ch."Phosphate_umolL",
       ch."Ammonium_umolL",
       ch."Nitrate_umolL",
       ch."Nitrite_umolL",
       ch."Oxygen_umolL",
       ch."DIC_umolkg",
       ch."Alkalinity_umolkg",
       pig."PigmentChla_mgm3"
FROM mld_temp mt JOIN mld_sal ms USING (trip_code)
                 JOIN dcm d USING (trip_code)
                 LEFT JOIN ctd_surface ctd USING (trip_code)
                 LEFT JOIN chemistry_avg ch USING (trip_code)
                 LEFT JOIN pigments_avg pig USING (trip_code)
ORDER BY trip_code
;