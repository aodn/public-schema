-- Materialized view for Phytoplankton Higher Taxonomic Groups (HTG) biovolume product
-- To be served as a WFS layer by Geoserver using output format csv-with-metadata-header,
-- which will convert the jsonb `biovolumes` column into separate CSV columns on output.
CREATE MATERIALIZED VIEW bgc_phytoplankton_biovolume_htg_data AS
WITH grouped AS (
    -- sum up biovolumes for each trip/group,
    -- filtering out groups that are not phytoplankton
    SELECT trip_code,
           methods,
           taxon_group,
           sum(biovolume_um3l) AS biovolume_um3l
    FROM bgc_phyto_raw
    WHERE taxon_group NOT IN ('Other', 'Coccolithophore', 'Diatom', 'Protozoa')
    GROUP BY trip_code, methods, taxon_group
), changelog AS (
    -- virtual changelog table for groups that were not counted before 2012-08-07, including 2 different methods for each group
    SELECT unnest(ARRAY ['Ciliate', 'Silicoflagellate', 'Radiozoa', 'Foraminifera', 'Ciliate', 'Silicoflagellate', 'Radiozoa', 'Foraminifera']) AS taxon_group,
           unnest(ARRAY ['SEM', 'SEM', 'SEM', 'SEM', 'LM', 'LM', 'LM', 'LM']) AS methods,
           '2012-08-07'::date AS startdate
), default_biovolumes AS (
    -- for taxon groups affected by the change in counting, set default biovolume values
    -- (NULL for 'not looked for', 0 for 'not found')
    SELECT m.trip_code,
           c.methods,
           c.taxon_group,
           CASE
               WHEN m."SampleTime_UTC" < c.startdate THEN NULL
               ELSE 0.
           END AS biovolume_um3l
    FROM bgc_phytoplankton_map m CROSS JOIN changelog c
), defaults_and_grouped AS (
    -- stack together observations and default values
    SELECT trip_code, methods, taxon_group, biovolume_um3l  FROM default_biovolumes
    UNION ALL
    SELECT trip_code, methods, taxon_group, biovolume_um3l  FROM grouped
), regrouped AS (
    -- create a single row per trip/group, making sure observed biovolumes override default values
    SELECT dg.trip_code,
           dg.methods,
           dg.taxon_group,
           max(dg.biovolume_um3l) AS biovolume_um3l
    FROM defaults_and_grouped dg
    INNER JOIN grouped using (trip_code, methods)
    GROUP BY dg.trip_code, dg.methods, dg.taxon_group
), pivoted AS (
    -- aggregate all taxon groups per trip into a single row
    SELECT trip_code,
           methods,
           jsonb_object_agg(taxon_group, biovolume_um3l) AS biovolumes
    FROM regrouped
    GROUP BY trip_code, methods
)
-- join on to metadata columns, include a row for every trip with phytoplankton samples taken
SELECT m.*,
       p.methods AS "Method",
       p.biovolumes
FROM bgc_phytoplankton_map m LEFT JOIN pivoted p USING (trip_code)
;
