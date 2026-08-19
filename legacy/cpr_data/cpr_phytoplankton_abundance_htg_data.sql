-- Materialized view for Phytoplankton CPR Higher Taxonomic Groups (HTG) abundance product
-- To be served as a WFS layer by Geoserver using output format csv-with-metadata-header,
-- which will convert the jsonb `abundances` column into separate CSV columns on output.
CREATE MATERIALIZED VIEW cpr_phytoplankton_abundance_htg_data AS
WITH grouped AS (
    -- sum up abundances for each trip/group,
    -- filtering out groups that are not phytoplankton
    SELECT sample,
           taxon_group,
           sum(phyto_abundance_m3) AS phyto_abundance_m3
    FROM cpr_phyto_raw
    WHERE taxon_group NOT IN ('Other', 'Coccolithophore', 'Diatom', 'Protozoa')
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
               WHEN m."SampleTime_UTC" < c.startdate THEN NULL
               ELSE 0.
           END AS phyto_abundance_m3
    FROM cpr_phytoplankton_map m CROSS JOIN changelog c
), defaults_and_grouped AS (
    -- stack together observations and default values
    SELECT sample, taxon_group, phyto_abundance_m3  FROM default_abundances
    UNION ALL
    SELECT sample, taxon_group, phyto_abundance_m3  FROM grouped
), regrouped AS (
    -- create a single row per trip/group, making sure observed abundances override default values
    SELECT sample,
           taxon_group,
           max(phyto_abundance_m3) AS phyto_abundance_m3
    FROM defaults_and_grouped
    GROUP BY sample, taxon_group
), pivoted AS (
    -- aggregate all taxon groups per trip into a single row
    SELECT sample,
           jsonb_object_agg(taxon_group, phyto_abundance_m3) AS abundances
    FROM regrouped
    GROUP BY sample
)
-- join on to metadata columns, include a row for every trip with phytoplankton samples taken
SELECT m.*,
       p.abundances
FROM cpr_phytoplankton_map m LEFT JOIN pivoted p USING (sample)
;
