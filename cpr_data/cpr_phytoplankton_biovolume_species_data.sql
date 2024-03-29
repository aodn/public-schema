-- Materialized view for CPR Phytoplankton Species biovolume product
-- To be served as a WFS layer by Geoserver using output format csv-with-metadata-header,
-- which will convert the jsonb `biovolumes` column into separate CSV columns on output.
CREATE MATERIALIZED VIEW cpr_phytoplankton_biovolume_species_data AS
WITH cpr_phyto_raw_species AS (
    -- filter out rows where species hasn't been identified,
    -- concatenate genus and species to create a simplified taxon name
    SELECT sample,
           genus || ' ' || species AS taxon_name,
           biovol_um3m3
    FROM cpr_phyto_raw
    WHERE species IS NOT NULL AND
          species != 'spp.' AND
          species NOT LIKE '%cf.%' AND
          species NOT LIKE '%/%' AND
          species NOT LIKE '%complex%' AND
          species NOT LIKE '%type%' AND
          species NOT LIKE '%cyst%' 
), grouped AS (
    -- join changelog on to raw data, group by trip, species and changelog details
    SELECT r.sample,
           taxon_name,
           c.startdate,
           taxon_name != c.parent_name AS species_changed,
           sum(r.biovol_um3m3) AS biovol_um3m3
    FROM cpr_phyto_raw_species r LEFT JOIN cpr_phyto_changelog c USING (taxon_name)
    GROUP BY sample, taxon_name, startdate, species_changed
), species_affected AS (
    -- identify species affected by a taxonomy change
    SELECT DISTINCT taxon_name, startdate
    FROM grouped
    WHERE species_changed
), default_biovolumes AS (
    -- for species affected by taxonomy change, set default biovolume values
    -- (NULL for 'not looked for', 0 for 'not found')
    SELECT m.sample,
           s.taxon_name,
           CASE
               WHEN m."SampleTime_UTC" < s.startdate THEN NULL
               ELSE 0.
           END AS biovol_um3m3
    FROM cpr_phytoplankton_map m CROSS JOIN species_affected s
),
defaults_and_grouped AS (
    -- stack together observations and default values
    SELECT sample, taxon_name, biovol_um3m3 FROM default_biovolumes
    UNION ALL
    SELECT sample, taxon_name, biovol_um3m3 FROM grouped
), regrouped AS (
    -- create a single row per trip/species, making sure observed biovolumes override default values
    SELECT sample,
           taxon_name,
           max(biovol_um3m3) AS biovol_um3m3
    FROM defaults_and_grouped
    GROUP BY sample, taxon_name
), pivoted AS (
    -- aggregate all species per trip into a single row
    SELECT sample,
           jsonb_object_agg(taxon_name, biovol_um3m3) AS biovolumes
    FROM regrouped
    GROUP BY sample
)
-- join on to metadata columns, include a row for every trip with phytoplankton samples taken
SELECT m.*,
       p.biovolumes
FROM cpr_phytoplankton_map m LEFT JOIN pivoted p USING (sample)
;
