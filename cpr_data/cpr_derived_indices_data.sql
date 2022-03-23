-- Materialized view for the CPR Derived Indices product
-- To be served as a WFS layer by Geoserver

CREATE MATERIALIZED VIEW cpr_derived_indices_data AS
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
    -- per-sample stats for all zooplankton
    SELECT sample,
           sum(zoop_abundance_m3) AS "ZoopAbundance_m3"
    FROM cpr_zoop_raw
    GROUP BY sample
),
copepods_by_trip AS (
    -- per-sample stats for all copepods
    SELECT zr.sample,
           sum(zr.zoop_abundance_m3) AS "CopeAbundance_m3",
           sum(zr.zoop_abundance_m3 * zi.length_mm) AS "CopeSumAbundanceLength",
           sum(zr.zoop_abundance_m3) FILTER (WHERE zi.diet = 'CC') AS "CC",
           sum(zr.zoop_abundance_m3) FILTER (WHERE zi.diet = 'CO') AS "CO"
    FROM cpr_zoop_raw zr LEFT JOIN zoopinfo_mod zi USING (taxon_name)
	WHERE zr.copepod = 'COPEPOD'
    GROUP BY sample
),
copepod_species_by_trip_species AS (
    -- zooplankton raw data filtered to include only correctly identified copepod species
    -- taxon_name updated to identify each unique species
    -- grouped by trip_code & taxon_name
    SELECT sample,
           genus || ' ' || substring(species, '^\w+') AS taxon_name,
           sum(taxon_count) AS taxon_count
    FROM cpr_zoop_raw
    WHERE copepod = 'COPEPOD' AND
          species != 'spp.' AND
          species NOT LIKE '%cf.%' AND
          species NOT LIKE '%/%' AND
          species NOT LIKE '%grp%' AND
          species NOT LIKE '%complex%'
    GROUP BY sample, genus || ' ' || substring(species, '^\w+')
),
copepod_species_by_trip AS (
    -- count number of copepod species
    SELECT sample,
           count(*) AS "NoCopepodSpecies_Sample",
           sum(taxon_count) AS total_taxon_count,
           sum(taxon_count * ln(taxon_count)) AS total_n_logn
    FROM copepod_species_by_trip_species
    GROUP BY sample
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
                      species LIKE '%type%' AND 
                      species LIKE '%cyst%') THEN NULL
                ELSE genus || ' ' || substring(species, '^\w+')
               END AS genus_species,
           CASE WHEN phyto_abundance_m3 = 0 THEN 0 --cell_l is phyto_abundance_m3 in cpr
                WHEN taxon_group = 'Dinoflagellate' THEN phyto_abundance_m3 * 0.76 * (biovol_um3m3/phyto_abundance_m3)^0.819
                WHEN taxon_group = 'Ciliate' THEN phyto_abundance_m3 * 0.22 * (biovol_um3m3/phyto_abundance_m3)^0.939
                WHEN taxon_group = 'Cyanobacteria' THEN phyto_abundance_m3 * 0.2
                ELSE phyto_abundance_m3 * 0.288 * (biovol_um3m3/phyto_abundance_m3)^0.811
               END AS carbon_pgm3,
           taxon_group LIKE '%diatom' AS is_diatom
    FROM cpr_phyto_raw
    WHERE taxon_group != 'Other'
),
phyto_by_samp AS (
    SELECT sample,
           sum(carbon_pgm3) AS "PhytoBiomassCarbon_pgm3",
           sum(phyto_abundance_m3) AS "PhytoAbund_Cellsm3",
           sum(phyto_abundance_m3) FILTER ( WHERE is_diatom ) AS diatom_m3,
           sum(phyto_abundance_m3) FILTER ( WHERE taxon_group = 'Dinoflagellate' ) AS dino_m3,
           sum(biovol_um3m3) / nullif(sum(phyto_abundance_m3), 0) AS "AvgCellVol_um3",
           count(DISTINCT genus_species) AS "NoPhytoSpecies_Sample",
           count(DISTINCT genus_species) FILTER ( WHERE is_diatom ) AS "NoDiatomSpecies_Sample",
           count(DISTINCT genus_species) FILTER ( WHERE taxon_group = 'Dinoflagellate' ) AS "NoDinoSpecies_Sample",
           sum(phyto_abundance_m3) FILTER ( WHERE genus_species IS NOT NULL ) AS total_species_abundance,
           sum(phyto_abundance_m3) FILTER ( WHERE genus_species IS NOT NULL AND is_diatom ) AS total_diatom_abundance,
           sum(phyto_abundance_m3) FILTER ( WHERE genus_species IS NOT NULL AND taxon_group = 'Dinoflagellate' )
               AS total_dino_abundance
    FROM phyto_filtered
    GROUP BY sample
),
phyto_species_by_samp_species AS (
    SELECT sample,
           pf.genus_species,
           sum(pf.phyto_abundance_m3 / pt.total_species_abundance) AS species_relative_abundance,
           sum(pf.phyto_abundance_m3 / pt.total_diatom_abundance) FILTER ( WHERE is_diatom ) AS diatom_relative_abundance,
           sum(pf.phyto_abundance_m3 / pt.total_dino_abundance) FILTER ( WHERE taxon_group = 'Dinoflagellate' )
               AS dino_relative_abundance
    FROM phyto_filtered pf LEFT JOIN phyto_by_samp pt USING (sample)
    WHERE genus_species IS NOT NULL
    GROUP BY sample, genus_species
),
phyto_species_by_samp AS (
    SELECT sample,
           -1 * sum(species_relative_abundance * ln(species_relative_abundance)) AS "ShannonPhytoDiversity",
           -1 * sum(diatom_relative_abundance * ln(diatom_relative_abundance)) AS "ShannonDiatomDiversity",
           -1 * sum(dino_relative_abundance * ln(dino_relative_abundance)) AS "ShannonDinoDiversity"
    FROM phyto_species_by_samp_species
    GROUP BY sample
)

-- Main query -------------------------------------------------------------------------------------
SELECT 
       -- metadata
       m.trip_code AS "TripCode",
       m.latitude AS "Latitude",
       m.longitude AS "Longitude",
       m.sampledateutc AS "SampleDate_UTC",
       to_char(m.sampledatelocal, 'YYYY-MM-DD HH24:MI:SS') AS "SampleDate_Local",
       extract(year from m.sampledatelocal)::int AS "Year_local",
       extract(month from m.sampledatelocal)::int AS "Month_local",
       extract(day from m.sampledatelocal)::int AS "Day_local",
       to_char(m.sampledatelocal, 'HH24:MI') AS "Time_local24hr",
       m.pci AS "PCI",
       m.biomass_mgm3 AS "BiomassIndex_mgm3",
       m.region AS "BioRegion", ---check with Claire as in CPR products we call it Region

       -- zooplankton indices
       zt."ZoopAbundance_m3",
       ct."CopeAbundance_m3",
       ct."CopeSumAbundanceLength" / ct."CopeAbundance_m3" AS "AvgTotalLengthCopepod_mm",
       ct."CO" / (ct."CO" + ct."CC") AS "OmnivoreCarnivoreCopepodRatio",
       cst."NoCopepodSpecies_Sample",
       ln(nullif(cst.total_taxon_count,0)) - (cst.total_n_logn/cst.total_taxon_count) AS "ShannonCopepodDiversity",
       (ln(cst.total_taxon_count) - (cst.total_n_logn/cst.total_taxon_count)) /
           nullif(ln(nullif(cst."NoCopepodSpecies_Sample",0)),0) AS "CopepodEvenness",

       -- phytoplankton indices
       ps."PhytoBiomassCarbon_pgm3",
       ps."PhytoAbund_Cellsm3", -- check name - spec says "AbundancePhyto_cellsL"
       ps.diatom_m3 / (ps.diatom_m3 + ps.dino_m3) AS "DiatomDinoflagellateRatio",
       ps."AvgCellVol_um3",
       ps."NoPhytoSpecies_Sample",
       pss."ShannonPhytoDiversity",
       pss."ShannonPhytoDiversity" / nullif(ln(nullif(ps."NoPhytoSpecies_Sample", 0)), 0) AS "PhytoEvenness",
       ps."NoDiatomSpecies_Sample",
       pss."ShannonDiatomDiversity",
       pss."ShannonDiatomDiversity" / nullif(ln(nullif(ps."NoDiatomSpecies_Sample", 0)), 0) AS "DiatomEvenness",
       ps."NoDinoSpecies_Sample",
       pss."ShannonDinoDiversity",
       pss."ShannonDinoDiversity" / nullif(ln(nullif(ps."NoDinoSpecies_Sample", 0)), 0) AS "DinoflagellateEvenness"

FROM cpr_samp m LEFT JOIN zoop_by_trip zt USING (sample)
                LEFT JOIN copepods_by_trip ct USING (sample)
                LEFT JOIN copepod_species_by_trip cst USING (sample)
                LEFT JOIN phyto_by_samp ps USING (sample)
                LEFT JOIN phyto_species_by_samp pss USING (sample)
;