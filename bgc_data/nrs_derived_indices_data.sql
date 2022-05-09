-- Materialized view for the NRS Derived Indices product
-- To be served as a WFS layer by Geoserver
CREATE MATERIALIZED VIEW nrs_derived_indices_data AS
WITH

-- Zooplankton temp tables ------------------------------------------------------------------------
zoopinfo_mod AS (
    -- reclassify diet column in zoopinfo
    SELECT taxon_name,
           length_mm,
           CASE WHEN zi.diet = 'Carnivore' THEN 'CC'
                WHEN zi.diet = 'Omnivore' THEN 'CO'
                WHEN zi.diet = 'Herbivore' THEN 'CO'
               END AS diet
    FROM zoopinfo zi
),
zoop_by_trip AS (
    -- per-trip stats for all zooplankton
    SELECT trip_code,
           sum(zoop_abundance_m3) AS "ZoopAbundance_m3"
    FROM bgc_zoop_raw
    GROUP BY trip_code
),
copepods_by_trip AS (
    -- per-trip stats for all copepods
    SELECT zr.trip_code,
           sum(zr.zoop_abundance_m3) AS "CopeAbundance_m3",
           sum(zr.zoop_abundance_m3 * zi.length_mm) AS "CopeSumAbundanceLength",
           sum(zr.zoop_abundance_m3) FILTER ( WHERE zi.diet = 'CC') AS "CC",
           sum(zr.zoop_abundance_m3) FILTER ( WHERE zi.diet = 'CO') AS "CO"
    FROM bgc_zoop_raw zr LEFT JOIN zoopinfo_mod zi USING (taxon_name)
    WHERE zr.copepod = 'COPEPOD'
    GROUP BY trip_code
),
copepod_species_by_trip_species AS (
    -- zooplankton raw data filtered to include only correctly identified copepod species
    -- taxon_name updated to identify each unique species
    -- grouped by trip_code & taxon_name
    SELECT trip_code,
           genus || ' ' || substring(species, '^\w+') AS taxon_name,
           nullif(sum(taxon_count), 0) AS taxon_count
    FROM bgc_zoop_raw
    WHERE copepod = 'COPEPOD' AND
          species != 'spp.' AND
          species NOT LIKE '%cf.%' AND
          species NOT LIKE '%/%' AND
          species NOT LIKE '%grp%' AND
          species NOT LIKE '%complex%'
    GROUP BY trip_code, genus || ' ' || substring(species, '^\w+')
),
copepod_species_by_trip AS (
    -- count number of copepod species
    SELECT trip_code,
           count(*) AS "NoCopepodSpecies_Sample",
           sum(taxon_count) AS total_taxon_count,
           sum(taxon_count * ln(taxon_count)) AS total_n_logn
    FROM copepod_species_by_trip_species
    GROUP BY trip_code
),

-- Phytoplankton temp tables ----------------------------------------------------------------------
phyto_filtered AS (
    -- filter out taxon_group "Other" from raw phyto data
    -- create genus_species field for counting valid species
    -- convert biovolume of cells to Carbon based on taxon_group
    SELECT *,
           CASE WHEN (species = 'spp.' OR
                      species LIKE '%cf.%' OR
                      species LIKE '%/%' OR
                      species LIKE '%complex%' OR
                      species LIKE '%type%' OR
                      species LIKE '%cyst%') THEN NULL
                ELSE genus || ' ' || substring(species, '^\w+')
               END AS genus_species,
           CASE WHEN cell_l = 0 THEN 0
                WHEN taxon_group = 'Dinoflagellate' THEN cell_l * 0.76 * (biovolume_um3l/cell_l)^0.819
                WHEN taxon_group = 'Ciliate' THEN cell_l * 0.22 * (biovolume_um3l/cell_l)^0.939
                WHEN taxon_group = 'Cyanobacteria' THEN cell_l * 0.2
                ELSE cell_l * 0.288 * (biovolume_um3l/cell_l)^0.811
               END AS carbon_pgl,
           taxon_group LIKE '%diatom' AS is_diatom
    FROM bgc_phyto_raw
    WHERE taxon_group != 'Other'
    -- TODO: Is it valid to filter out biovolume = 0/NULL and cell_l = 0 here ??
),
phyto_by_trip AS (
    SELECT trip_code,
           sum(carbon_pgl) AS "PhytoBiomassCarbon_pgL",
           sum(cell_l) AS "PhytoAbundance_CellsL",
           sum(cell_l) FILTER ( WHERE is_diatom ) AS diatom_l,
           sum(cell_l) FILTER ( WHERE taxon_group = 'Dinoflagellate' ) AS dino_l,
           sum(biovolume_um3l) / nullif(sum(cell_l), 0) AS "AvgCellVol_um3",
           count(DISTINCT genus_species) AS "NoPhytoSpecies_Sample",
           count(DISTINCT genus_species) FILTER ( WHERE is_diatom ) AS "NoDiatomSpecies_Sample",
           count(DISTINCT genus_species) FILTER ( WHERE taxon_group = 'Dinoflagellate' ) AS "NoDinoSpecies_Sample",
           sum(cell_l) FILTER ( WHERE genus_species IS NOT NULL ) AS total_species_abundance,
           sum(cell_l) FILTER ( WHERE genus_species IS NOT NULL AND is_diatom ) AS total_diatom_abundance,
           sum(cell_l) FILTER ( WHERE genus_species IS NOT NULL AND taxon_group = 'Dinoflagellate' )
               AS total_dino_abundance
    FROM phyto_filtered
    GROUP BY trip_code
),
phyto_species_by_trip_species AS (
    SELECT trip_code,
           pf.genus_species,
           sum(pf.cell_l / pt.total_species_abundance) AS species_relative_abundance,
           sum(pf.cell_l / pt.total_diatom_abundance) FILTER ( WHERE is_diatom ) AS diatom_relative_abundance,
           sum(pf.cell_l / pt.total_dino_abundance) FILTER ( WHERE taxon_group = 'Dinoflagellate' )
               AS dino_relative_abundance
    FROM phyto_filtered pf LEFT JOIN phyto_by_trip pt USING (trip_code)
    WHERE genus_species IS NOT NULL
    GROUP BY trip_code, genus_species
),
phyto_species_by_trip AS (
    SELECT trip_code,
           -1 * sum(species_relative_abundance * ln(species_relative_abundance)) AS "ShannonPhytoDiversity",
           -1 * sum(diatom_relative_abundance * ln(diatom_relative_abundance)) AS "ShannonDiatomDiversity",
           -1 * sum(dino_relative_abundance * ln(dino_relative_abundance)) AS "ShannonDinoDiversity"
    FROM phyto_species_by_trip_species
    GROUP BY trip_code
),

-- CTD-derived temp tables ------------------------------------------------------------------------
ctd_data AS (
    SELECT trip_code,
           "SampleDepth_m",
           "Temperature_degC",
           "Salinity_psu",
           "Chla_mgm3",
           CASE WHEN substr(trip_code, 1, 3) IN ('DAR', 'YON') THEN 5
                ELSE 10
               END AS target_ref_depth
    FROM nrs_depth_binned_ctd_data
),
ref_values AS (
    -- set reference depth, temp & sal from nearest data to target ref depth
    -- for MLD estimates (Ref: Condie & Dunn 2006)
    SELECT DISTINCT ON (trip_code)
        trip_code,
        "SampleDepth_m" AS ref_depth,
        abs("SampleDepth_m" - target_ref_depth) AS depth_diff,
        "Temperature_degC" - 0.4 AS ref_temp,
        "Salinity_psu" - 0.03 AS ref_sal
  FROM ctd_data
  ORDER BY trip_code, depth_diff, "SampleDepth_m"
),
mld_temp AS (
    -- temp-based MLD estimate
    -- the depth with temperature closest to ref temp (and > ref_depth)
    SELECT DISTINCT ON (trip_code)
        trip_code,
        abs(c."Temperature_degC" - r.ref_temp) as temp_diff,
        c."SampleDepth_m" AS "MLDtemp_m"
    FROM ctd_data c LEFT JOIN ref_values r USING (trip_code)
    WHERE c."SampleDepth_m" > r.ref_depth
    ORDER BY trip_code, temp_diff, "SampleDepth_m"
),
mld_sal AS (
    -- salinity-based MLD estimate
    -- the depth with salinity closest to ref salinity (and > ref_depth)
    SELECT DISTINCT ON (trip_code)
        trip_code,
        abs(c."Salinity_psu" - r.ref_sal) as sal_diff,
        c."SampleDepth_m" AS "MLDsal_m"
    FROM ctd_data c LEFT JOIN ref_values r USING (trip_code)
    WHERE c."SampleDepth_m" > r.ref_depth
    ORDER BY trip_code, sal_diff, "SampleDepth_m"
),
dcm AS (
    -- DCM is the depth corresponding to maximum Chlorophyll concentration
    -- at depth > ref_depth
    SELECT DISTINCT ON (trip_code)
        trip_code,
        c."SampleDepth_m" AS "DCM_m"
    FROM ctd_data c LEFT JOIN ref_values r USING (trip_code)
    WHERE c."SampleDepth_m" > r.ref_depth
    ORDER BY trip_code, "Chla_mgm3" DESC, "SampleDepth_m"
),
ctd_surface AS (
    -- take the average of the top 10m as surface values
    SELECT trip_code,
           avg("Temperature_degC") AS "CTDTemperature_degC",
           avg("Chla_mgm3") AS "CTDChlaF_mgm3",
           avg("Salinity_psu") AS "CTDSalinity_PSU"
    FROM nrs_depth_binned_ctd_data
    WHERE "SampleDepth_m" < 10
    GROUP BY trip_code
),

-- Chemistry & pigments temp tables ---------------------------------------------------------------
chemistry_avg AS (
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
),
pigments_avg AS (
    -- extract Chlorophyll a from raw pigments data
    -- average over measurements taken at depths < 25m
    SELECT trip_code,
           avg(dv_cphl_a_and_cphl_a) AS "PigmentChla_mgm3"
    FROM bgc_pigments
    WHERE sampledepth_m != 'WC' AND sampledepth_m::numeric < 25
    GROUP BY trip_code
)

-- Main query -------------------------------------------------------------------------------------
SELECT m."Project",
       m."StationName",
       m."TripCode",
       m."SampleTime_Local"::date AS "SampleDateLocal",
       m."SampleTime_UTC",
       m."Latitude",
       m."Longitude",
       m."Biomass_mgm3",
       m."AshFreeBiomass_mgm3",
       m.secchi_m as "Secchi_m",

       -- zooplankton indices
       zt."ZoopAbundance_m3",
       ct."CopeAbundance_m3",
       ct."CopeSumAbundanceLength" / ct."CopeAbundance_m3" AS "AvgTotalLengthCopepod_mm",
       ct."CO" / (ct."CO" + ct."CC") AS "OmnivoreCarnivoreCopepodRatio",
       cst."NoCopepodSpecies_Sample",
       ln(cst.total_taxon_count) - (cst.total_n_logn/cst.total_taxon_count) AS "ShannonCopepodDiversity",
       (ln(cst.total_taxon_count) - (cst.total_n_logn/cst.total_taxon_count)) /
           nullif(ln(nullif(cst."NoCopepodSpecies_Sample", 0)), 0) AS "CopepodEvenness",

       -- phytoplankton indices
       pt."PhytoBiomassCarbon_pgL",
       pt."PhytoAbundance_CellsL", 
       pt.diatom_l / (pt.diatom_l + pt.dino_l) AS "DiatomDinoflagellateRatio",
       pt."AvgCellVol_um3",
       pt."NoPhytoSpecies_Sample",
       pst."ShannonPhytoDiversity",
       pst."ShannonPhytoDiversity" / nullif(ln(nullif(pt."NoPhytoSpecies_Sample", 0)), 0) AS "PhytoEvenness",
       pt."NoDiatomSpecies_Sample",
       pst."ShannonDiatomDiversity",
       pst."ShannonDiatomDiversity" / nullif(ln(nullif(pt."NoDiatomSpecies_Sample", 0)), 0) AS "DiatomEvenness",
       pt."NoDinoSpecies_Sample",
       pst."ShannonDinoDiversity",
       pst."ShannonDinoDiversity" / nullif(ln(nullif(pt."NoDinoSpecies_Sample", 0)), 0) AS "DinoflagellateEvenness",

       -- CTD-derived indices
       mt."MLDtemp_m",
       ms."MLDsal_m",
       d."DCM_m",
       ctd."CTDTemperature_degC",
       ctd."CTDChlaF_mgm3",
       ctd."CTDSalinity_PSU",

       -- chemistry & pigments
       ch."Silicate_umolL",
       ch."Phosphate_umolL",
       ch."Ammonium_umolL",
       ch."Nitrate_umolL",
       ch."Nitrite_umolL",
       ch."Oxygen_umolL",
       ch."DIC_umolkg",
       ch."Alkalinity_umolkg",
       pig."PigmentChla_mgm3",

       m.geom

FROM bgc_trip_metadata m LEFT JOIN zoop_by_trip zt USING (trip_code)
                         LEFT JOIN copepods_by_trip ct USING (trip_code)
                         LEFT JOIN copepod_species_by_trip cst USING (trip_code)
                         LEFT JOIN phyto_by_trip pt USING (trip_code)
                         LEFT JOIN phyto_species_by_trip pst USING (trip_code)
                         LEFT JOIN mld_temp mt USING (trip_code)
                         LEFT JOIN mld_sal ms USING (trip_code)
                         LEFT JOIN dcm d USING (trip_code)
                         LEFT JOIN ctd_surface ctd USING (trip_code)
                         LEFT JOIN chemistry_avg ch USING (trip_code)
                         LEFT JOIN pigments_avg pig USING (trip_code)
WHERE m."Project" = 'NRS'
;
