-- Materialized view for Zooplankton Species (Copepods) abundance product
-- To be served as a WFS layer by Geoserver using output format csv-with-metadata-header,
-- which will convert the jsonb `abundances` column into separate CSV columns on output.
CREATE MATERIALIZED VIEW bgc_zooplankton_abundance_copepods_data AS
WITH bgc_zoop_raw_species AS (
    -- filter out rows where species hasn't been identified,
    -- concatenate genus and first word of species to create a simplified species name
    SELECT r.trip_code,
           r.taxon_name,
           r.genus || ' ' || substring(r.species, '^\w+') AS species,
           r.zoop_abundance_m3
    FROM bgc_zoop_raw r
    WHERE r.copepod = 'COPEPOD' AND
          r.species IS NOT NULL AND
          r.species != 'spp.' AND
          r.species NOT LIKE '%cf.%' AND
          r.species NOT LIKE '%/%' AND
          r.species NOT LIKE '%grp%'
), grouped AS (
    -- join changelog on to raw data, group by trip, species and changelog details
    SELECT r.trip_code,
           r.species,
           c.startdate,
           taxon_name != c.parent_name AS name_changed,
           sum(r.zoop_abundance_m3) AS zoop_abundance_m3
    FROM bgc_zoop_raw_species r LEFT JOIN bgc_zoop_changelog c USING (taxon_name)
    GROUP BY trip_code, species, startdate, name_changed
), species_affected AS (
    -- identify species affected by a taxonomy change
    SELECT DISTINCT species, startdate
    FROM grouped
    WHERE name_changed
), default_abundances AS (
    -- for species affected by taxonomy change, set default abundance values
    -- (NULL for 'not looked for', 0 for 'not found')
    SELECT m.trip_code,
           s.species,
           CASE
               WHEN m."SampleTime_local" < s.startdate THEN NULL
               ELSE 0.
           END AS zoop_abundance_m3
    FROM bgc_zooplankton_map m CROSS JOIN species_affected s
), defaults_and_grouped AS (
    -- stack together observations and default values
    SELECT trip_code, species, zoop_abundance_m3  FROM default_abundances
    UNION ALL
    SELECT trip_code, species, zoop_abundance_m3  FROM grouped
), regrouped AS (
    -- create a single row per trip/species, making sure observed abundances override default values
    SELECT trip_code,
           species,
           max(zoop_abundance_m3) AS zoop_abundance_m3
    FROM defaults_and_grouped
    GROUP BY trip_code, species
), pivoted AS (
    -- aggregate all species per trip into a single row
    SELECT trip_code,
           jsonb_object_agg(species, zoop_abundance_m3) AS abundances
    FROM regrouped
    GROUP BY trip_code
)
-- join on to metadata columns, include a row for every trip with zooplankton samples taken
SELECT m.*,
       p.abundances
FROM bgc_zooplankton_map m LEFT JOIN pivoted p USING (trip_code)
;
