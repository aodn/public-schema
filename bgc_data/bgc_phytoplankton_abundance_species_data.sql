-- Materialized view for Phytoplankton Species abundance product
-- To be served as a WFS layer by Geoserver using output format csv-with-metadata-header,
-- which will convert the jsonb `abundances` column into separate CSV columns on output.
CREATE MATERIALIZED VIEW bgc_phytoplankton_abundance_species_data AS
WITH bgc_phyto_raw_species AS (
    -- filter out rows where species hasn't been identified,
    -- concatenate genus and species to create a simplified taxon name
    -- (without comments about with flagellates, cilliates etc...)
    SELECT trip_code,
           methods,
           genus || ' ' || species AS taxon_name,
           cell_l
    FROM bgc_phyto_raw
    WHERE species IS NOT NULL AND
          species != 'spp.' AND
          species NOT LIKE '%cf.%' AND
          species NOT LIKE '%/%' AND
          species NOT LIKE '%complex%' AND
          species NOT LIKE '%type%' AND
          species NOT LIKE '%cyst%' 
), grouped AS (
    -- join changelog on to raw data, group by trip, species and changelog details
    SELECT r.trip_code,
           r.methods,
           taxon_name,
           c.startdate,
           taxon_name != c.parent_name AS species_changed,
           sum(r.cell_l) AS cell_l
    FROM bgc_phyto_raw_species r LEFT JOIN bgc_phyto_changelog c USING (taxon_name)
    GROUP BY trip_code, r.methods, taxon_name, startdate, species_changed
), species_affected AS (
    -- identify species affected by a taxonomy change
    SELECT DISTINCT taxon_name, methods, startdate
    FROM grouped
    WHERE species_changed

), default_abundances AS (
    -- for species affected by taxonomy change, set default abundance values
    -- (NULL for 'not looked for', 0 for 'not found')
    SELECT m.trip_code,
           s.methods,
           s.taxon_name,
           CASE
               WHEN m."SampleTime_UTC" < s.startdate THEN NULL
               ELSE 0.
           END AS cell_l
    FROM bgc_phytoplankton_map m CROSS JOIN species_affected s
), defaults_and_grouped AS (
    -- stack together observations and default values
    SELECT trip_code, methods, taxon_name, cell_l  FROM default_abundances
    UNION ALL
    SELECT trip_code, methods, taxon_name, cell_l  FROM grouped
), regrouped AS (
    -- create a single row per trip/species, making sure observed abundances override default values
    SELECT trip_code,
           methods,
           taxon_name,
           max(cell_l) AS cell_l
    FROM defaults_and_grouped
    GROUP BY trip_code, taxon_name, methods
), pivoted AS (
    -- aggregate all species per trip into a single row
    SELECT trip_code,
           methods,
           jsonb_object_agg(taxon_name, cell_l) AS abundances
    FROM regrouped
    GROUP BY trip_code, methods
)
-- join on to metadata columns, include a row for every trip with phytoplankton samples taken
SELECT m.*,
       p.methods AS "Method",
       p.abundances
FROM bgc_phytoplankton_map m LEFT JOIN pivoted p USING (trip_code)
;
