-- Materialized view for Phytoplankton Higher Taxonomic Groups (HTG) abundance product
-- To be served as a WFS layer by Geoserver using output format csv-with-metadata-header,
-- which will convert the jsonb `abundances` column into separate CSV columns on output.
CREATE MATERIALIZED VIEW bgc_phytoplankton_abundance_htg_data AS
WITH grouped AS (
    -- sum up abundances for each trip/group,
    -- filtering out groups that are not phytoplankton
    SELECT trip_code,
           taxon_group,
           sum(cell_l) AS cell_l
    FROM bgc_phyto_raw
    WHERE taxon_group NOT IN ('Other', 'Coccolithophore', 'Diatom', 'Protozoa')
    GROUP BY trip_code, taxon_group
), changelog AS (
    -- virtual changelog table for groups that were not counted before 2012-08-07
    SELECT unnest(ARRAY ['Ciliate', 'Silicoflagellate', 'Radiozoa', 'Foraminifera']) AS taxon_group,
           '2012-08-07'::date AS startdate
), default_abundances AS (
    -- for taxon groups affected by the change in counting, set default abundance values
    -- (NULL for 'not looked for', 0 for 'not found')
    SELECT m.trip_code,
           c.taxon_group,
           CASE
               WHEN m."SampleTime_local" < c.startdate THEN NULL
               ELSE 0.
           END AS cell_l
    FROM bgc_phytoplankton_map m CROSS JOIN changelog c
), defaults_and_grouped AS (
    -- stack together observations and default values
    SELECT trip_code, taxon_group, cell_l  FROM default_abundances
    UNION ALL
    SELECT trip_code, taxon_group, cell_l  FROM grouped
), regrouped AS (
    -- create a single row per trip/group, making sure observed abundances override default values
    SELECT trip_code,
           taxon_group,
           max(cell_l) AS cell_l
    FROM defaults_and_grouped
    GROUP BY trip_code, taxon_group
), pivoted AS (
    -- aggregate all taxon groups per trip into a single row
    SELECT trip_code,
           jsonb_object_agg(taxon_group, cell_l) AS abundances
    FROM regrouped
    GROUP BY trip_code
)
-- join on to metadata columns, include a row for every trip with phytoplankton samples taken
SELECT m.*,
       p.abundances
FROM bgc_phytoplankton_map m LEFT JOIN pivoted p USING (trip_code)
;
