-- Materialized view for the NRS Derived Indices product
-- To be served as a WFS layer by Geoserver
-- CREATE MATERIALIZED VIEW nrs_derived_indices_data AS
WITH nrs_derived_indices_map AS (
    SELECT "TripCode",
           trip_code
    FROM bgc_trip_metadata
    WHERE "Project" = 'NRS'
          AND trip_code LIKE 'MAI%'  -- TODO: remove this!
), zoopinfo_mod AS (
    -- reclassify diet column in zoopinfo
    SELECT taxon_name,
           length_mm,
           CASE WHEN zi.diet = 'Carnivore' THEN 'CC'
                WHEN zi.diet = 'Omnivore' THEN 'CO'
                WHEN zi.diet = 'Herbivore' THEN 'CO'
               END AS diet
    FROM zoopinfo zi
), zoop_by_trip AS (
    -- per-trip stats for all zooplankton
    SELECT trip_code,
           sum(zoop_abundance_m3) AS "ZoopAbundance_m3"
    FROM bgc_zoop_raw
    GROUP BY trip_code
), copepods_by_trip AS (
    -- per-trip stats for all copepods
    SELECT zr.trip_code,
           sum(zr.zoop_abundance_m3) AS "CopeAbundance_m3",
           sum(zr.zoop_abundance_m3 * zi.length_mm) AS "CopeSumAbundanceLength",
           sum(zr.zoop_abundance_m3) FILTER ( WHERE zi.diet = 'CC') AS "CC",
           sum(zr.zoop_abundance_m3) FILTER ( WHERE zi.diet = 'CO') AS "CO"
    FROM bgc_zoop_raw zr LEFT JOIN zoopinfo_mod zi USING (taxon_name)
    WHERE zr.copepod = 'COPEPOD'
    GROUP BY trip_code
), copepod_species_by_trip_species AS (
    -- zooplankton raw data filtered to include only correctly identified copepod species
    -- taxon_name updated to identify each unique species
    -- grouped by trip_code & taxon_name
    SELECT trip_code,
           genus || ' ' || substring(species, '^\w+') AS taxon_name,
           sum(taxon_count) AS taxon_count
    FROM bgc_zoop_raw
    WHERE copepod = 'COPEPOD' AND
          species != 'spp.' AND
          species NOT LIKE '%cf.%' AND
          species NOT LIKE '%/%' AND
          species NOT LIKE '%grp%'
    GROUP BY trip_code, genus || ' ' || substring(species, '^\w+')
), copepod_species_by_trip AS (
    -- count number of copepod species
    SELECT trip_code,
           count(*) AS "NoCopepodSpecies_Sample",
           sum(taxon_count) AS total_taxon_count,
           sum(taxon_count * ln(taxon_count)) AS total_n_logn
    FROM copepod_species_by_trip_species
    GROUP BY trip_code
),

phyto_filtered AS (
    -- filter out taxon_group "Other" from raw phyto data
    SELECT *,
           biovolume_um3l / nullif(cell_l, 0) AS bv_cell,  -- biovolume of one cell
           CASE WHEN (species = 'spp.' AND
                      species LIKE '%cf.%' AND
                      species LIKE '%/%' AND
                      species LIKE '%grp%') THEN NULL
                ELSE genus || ' ' || substring(species, '^\w+')
               END AS genus_species
    FROM bgc_phyto_raw
    WHERE taxon_group != 'Other'
    -- TODO: Is it valid to filter out biovolume = 0/NULL and cell_l = 0 here ??
), phyto_with_carbon AS (
    -- convert biovolume of cell to Carbon based on taxon_group
    SELECT *,
           CASE WHEN taxon_group = 'Dinoflagellate' THEN cell_l * 0.76 * bv_cell^0.819
                WHEN taxon_group = 'Ciliate' THEN cell_l * 0.22 * bv_cell^0.939
                WHEN taxon_group = 'Cyanobacteria' THEN cell_l * 0.2
                ELSE cell_l * 0.288 * bv_cell^0.811
               END AS carbon_pgl
    FROM phyto_filtered
), phyto_by_trip AS (
    SELECT trip_code,
           sum(carbon_pgl) AS "PhytoBiomassCarbon_pgL",
           sum(cell_l) AS "PhytoAbund_CellsL",
           sum(cell_l) FILTER ( WHERE taxon_group LIKE '%diatom' ) AS diatom_l,
           sum(cell_l) FILTER ( WHERE taxon_group = 'Dinoflagellate' ) AS dinoflagellate_l,
           sum(biovolume_um3l) / nullif(sum(cell_l), 0) AS "AvgCellVol_um3",
           count(DISTINCT genus_species) AS "NoPhytoSpecies_Sample"
    FROM phyto_with_carbon
    GROUP BY trip_code
)

SELECT m.*,
       -- zooplankton indices
       zt."ZoopAbundance_m3",
       ct."CopeAbundance_m3",
       ct."CopeSumAbundanceLength" / zt."ZoopAbundance_m3" AS "AvgTotalLengthCopepod_mm",
       ct."CO" / (ct."CO" + ct."CC") AS "OmnivoreCarnivoreCopepodRatio",
       cst."NoCopepodSpecies_Sample",
       ln(cst.total_taxon_count) - (cst.total_n_logn/cst.total_taxon_count) AS "ShannonCopepodDiversity",
       (ln(cst.total_taxon_count) - (cst.total_n_logn/cst.total_taxon_count)) /
           ln(cst."NoCopepodSpecies_Sample") AS "CopepodEvenness",

       -- phytoplankton indices
       pt."PhytoBiomassCarbon_pgL",
       pt."PhytoAbund_CellsL",  -- TODO: check name - spec says "AbundancePhyto_cellsL"
       pt.diatom_l / (pt.diatom_l + pt.dinoflagellate_l) AS "DiatomDinoflagellateRatio",
       pt."AvgCellVol_um3",
       pt."NoPhytoSpecies_Sample",  -- TODO: NOT QUITE RIGHT ??
--        "ShannonPhytoDiversity",
--        "PhytoEvenness",
--        "NoDiatomSpecies_Sample",
--        "ShannonDiatomDiversity",
--        "DiatomEvenness",
--        "NoDinoSpecies_Sample",
--        "ShannonDinoDiversity",
--        "DinoflagellateEvenness"
       NULL AS "_end"  -- TODO: remove
FROM nrs_derived_indices_map m LEFT JOIN zoop_by_trip zt USING (trip_code)
                               LEFT JOIN copepods_by_trip ct USING (trip_code)
                               LEFT JOIN copepod_species_by_trip cst USING (trip_code)
                               LEFT JOIN phyto_by_trip pt USING (trip_code)
ORDER BY trip_code
;
