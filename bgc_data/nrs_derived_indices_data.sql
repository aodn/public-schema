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
), zoo_stats AS (
    -- per-trip stats for all zooplankton
    SELECT trip_code,
           sum(zoop_abundance_m3) AS ZoopAbundance_m3
    FROM bgc_zoop_raw
    GROUP BY trip_code
), copepod_stats AS (
    -- per-trip stats for all Copepods
    SELECT zr.trip_code,
           sum(zr.zoop_abundance_m3) AS CopeAbundance_m3,
           sum(zr.zoop_abundance_m3 * zi.length_mm) AS "CopeSumAbundanceLength",
           sum(zr.zoop_abundance_m3) FILTER ( WHERE zi.diet = 'CC') AS "CC",
           sum(zr.zoop_abundance_m3) FILTER ( WHERE zi.diet = 'CO') AS "CO"
    FROM bgc_zoop_raw zr LEFT JOIN zoopinfo_mod zi USING (taxon_name)
    WHERE zr.copepod = 'COPEPOD'
    GROUP BY trip_code
), copepods_by_trip_species AS (
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
), copepod_species_stats_by_trip AS (
    -- count number of copepod species
    SELECT trip_code,
           count(*) AS "NoCopepodSpecies_Sample",
           sum(taxon_count) AS total_taxon_count,
           sum(taxon_count * ln(taxon_count)) AS total_n_logn
    FROM copepods_by_trip_species
    GROUP BY trip_code
)

SELECT m.*,
--        zs.ZoopAbundance_m3,
--        cs.CopeAbundance_m3,
--        cs."CopeSumAbundanceLength" / zs.ZoopAbundance_m3 AS "AvgTotalLengthCopepod_mm",
--        --TODO: column below should be "OmnivoreCarnivoreCopepodRatio" ??
--        cs."CO" / (cs."CO" + cs."CC") AS "HerbivoreCarnivoreCopepodRatio",
       css."NoCopepodSpecies_Sample",
       ln(css.total_taxon_count) - (css.total_n_logn/css.total_taxon_count) AS "ShannonCopepodDiversity",
       (ln(css.total_taxon_count) - (css.total_n_logn/css.total_taxon_count)) /
           ln(css."NoCopepodSpecies_Sample") AS "CopepodEvenness"
FROM nrs_derived_indices_map m LEFT JOIN zoo_stats zs USING (trip_code)
                               LEFT JOIN copepod_stats cs USING (trip_code)
                               LEFT JOIN copepod_species_stats_by_trip css USING (trip_code)
ORDER BY trip_code
;
