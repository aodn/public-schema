-- Materialized view for Zooplankton Copepods product
-- To be served as a WFS layer by Geoserver using output format csv-with-metadata-header,
-- which will convert the josnb `abundances` column into separate CSV columns on output.
CREATE MATERIALIZED VIEW bgc_zooplankton_abundance_non_copepods_data AS
WITH grouped AS (
    -- join changelog on to raw data, pick only rows where copepod identified + other cases identified in Claire code
    -- group by trip, genus, species and changelog details
	-- select only copepods
    SELECT r.trip_code,
	   CONCAT(r.genus, ' ', r.species) AS composite_species_name, 
           c.startdate,
           substring(taxon_name, '^\w+') != substring(parent_name, '^\w+') AS name_changed,
           sum(r.zoop_abundance_m3) AS zoop_abundance_m3
    FROM bgc_zoop_raw r LEFT JOIN bgc_zoop_changelog c USING (taxon_name)
    WHERE r.copepod = 'NON-COPEPOD'
      AND r.species IS NOT NULL
      AND r.species != 'spp.'
      AND r.species NOT LIKE '%cf.%'
      AND r.species NOT LIKE '%grp%'
	GROUP BY trip_code, genus, startdate, name_changed, species
), species_affected AS (
    -- identify species affected by a taxonomy change
    SELECT DISTINCT composite_species_name, startdate
    FROM grouped
    WHERE name_changed
), default_abundances AS (
    -- for name_changed affected by taxonomy change, set default abundance values
    -- (NULL for 'not looked for', 0 for 'not found')
    SELECT m.trip_code,
           g.composite_species_name,
           CASE
               WHEN m."SampleTime_local" < g.startdate THEN NULL
               ELSE 0.
           END AS zoop_abundance_m3
    FROM bgc_zooplankton_map m CROSS JOIN species_affected g
), defaults_and_grouped AS (
    -- stack together observations and default values
    SELECT trip_code, composite_species_name, zoop_abundance_m3  FROM default_abundances
    UNION ALL
    SELECT trip_code, composite_species_name, zoop_abundance_m3  FROM grouped
), regrouped AS (
    -- create a single row per trip/genus, making sure observed abundances override default values
    SELECT trip_code,
           composite_species_name,
           max(zoop_abundance_m3) AS zoop_abundance_m3
    FROM defaults_and_grouped
    GROUP BY trip_code, composite_species_name
), pivoted AS (
    -- aggregate all species per trip into a single row
    SELECT trip_code,
           jsonb_object_agg(composite_species_name, zoop_abundance_m3) AS abundances
    FROM regrouped
    GROUP BY trip_code
)
-- join on to metadata columns, include a row for every trip with zooplankton samples taken
SELECT m.*,
       p.abundances
FROM bgc_zooplankton_map m LEFT JOIN pivoted p USING (trip_code)
;
