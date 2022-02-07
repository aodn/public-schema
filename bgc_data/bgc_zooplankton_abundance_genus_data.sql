-- Materialized view for Zooplankton Genus product
-- To be served as a WFS layer by Geoserver using output format csv-with-metadata-header,
-- which will convert the jsonb `abundances` column into separate CSV columns on output.
CREATE MATERIALIZED VIEW bgc_zooplankton_abundance_genus_data AS
WITH grouped AS (
    -- join changelog on to raw data, pick only rows where genus identified
    -- group by trip, genus and changelog details
	SELECT r.trip_code,
           r.genus,
           c.startdate,
           substring(taxon_name, '^\w+') != substring(parent_name, '^\w+') AS genus_changed,
           sum(r.zoop_abundance_m3) AS zoop_abundance_m3
    FROM bgc_zoop_raw r LEFT JOIN bgc_zoop_changelog c USING (taxon_name)
    WHERE r.genus IS NOT NULL AND 
          r.genus NOT LIKE '%cf.%'
    GROUP BY trip_code, genus, startdate, genus_changed
), genera_affected AS (
    -- identify genera affected by a taxonomy change
    SELECT DISTINCT genus, startdate
    FROM grouped
    WHERE genus_changed
), default_abundances AS (
    -- for genera affected by taxonomy change, set default abundance values
    -- (NULL for 'not looked for', 0 for 'not found')
    SELECT m.trip_code,
           g.genus,
           CASE
               WHEN m."SampleTime_local"::date < g.startdate THEN NULL
               ELSE 0.
           END AS zoop_abundance_m3
    FROM bgc_zooplankton_map m CROSS JOIN genera_affected g
), defaults_and_grouped AS (
    -- stack together observations and default values
    SELECT trip_code, genus, zoop_abundance_m3  FROM default_abundances
    UNION ALL
    SELECT trip_code, genus, zoop_abundance_m3  FROM grouped
), regrouped AS (
    -- create a single row per trip/genus, making sure observed abundances override default values
    SELECT trip_code,
           genus,
           max(zoop_abundance_m3) AS zoop_abundance_m3
    FROM defaults_and_grouped
    GROUP BY trip_code, genus
), pivoted AS (
    -- aggregate all genera per trip into a single row
    SELECT trip_code,
           jsonb_object_agg(genus, zoop_abundance_m3) AS abundances
    FROM regrouped
    GROUP BY trip_code
)
-- join on to metadata columns, include a row for every trip with zooplankton samples taken
SELECT m.*,
       p.abundances
FROM bgc_zooplankton_map m LEFT JOIN pivoted p USING (trip_code)
;
