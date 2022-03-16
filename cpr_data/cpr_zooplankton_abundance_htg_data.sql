-- Materialized view for Zooplankton CPR Higher Taxonomic Groups (HTG) product
-- To be served as a WFS layer by Geoserver using output format csv-with-metadata-header,
-- which will convert the jsonb `abundances` column into separate CSV columns on output.
CREATE MATERIALIZED VIEW cpr_zooplankton_abundance_htg_data AS
WITH grouped AS (
    -- sum up abundances for each trip/group,
    -- filtering out groups that are not zooplankton
    SELECT sample,
           taxon_group,
           sum(zoop_abundance_m3) AS zoop_abundance_m3
    FROM cpr_zoop_raw
    WHERE taxon_group NOT IN ('Other')
    GROUP BY sample, taxon_group
), changelog AS (
    -- virtual changelog table for groups that were not counted before 2013-03-01
    SELECT unnest(ARRAY ['Ciliate', 'Foraminifera']) AS taxon_group,
           '2013-03-01'::date AS startdate
), default_abundances AS (
    -- for taxon groups affected by the change in counting, set default abundance values
    -- (NULL for 'not looked for', 0 for 'not found')
    SELECT m.sample,
           c.taxon_group,
           CASE
               WHEN m."SampleDate_UTC" < c.startdate THEN NULL
               ELSE 0.
           END AS zoop_abundance_m3
    FROM cpr_zooplankton_map m CROSS JOIN changelog c
), defaults_and_grouped AS (
    -- stack together observations and default values
    SELECT sample, taxon_group, zoop_abundance_m3  FROM default_abundances
    UNION ALL
    SELECT sample, taxon_group, zoop_abundance_m3  FROM grouped
), regrouped AS (
    -- create a single row per trip/group, making sure observed abundances override default values
    SELECT sample,
           taxon_group,
           max(zoop_abundance_m3) AS zoop_abundance_m3
    FROM defaults_and_grouped
    GROUP BY sample, taxon_group
), pivoted AS (
    -- aggregate all taxon groups per trip into a single row
    SELECT sample,
           jsonb_object_agg(taxon_group, zoop_abundance_m3) AS abundances
    FROM regrouped
    GROUP BY sample
)
-- join on to metadata columns, include a row for every trip with zooplankton samples taken
SELECT m.*,
       p.abundances
FROM cpr_zooplankton_map m LEFT JOIN pivoted p USING (sample)
;
