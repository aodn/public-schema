-- Materialized view for Phytoplankton Genus biovolume product
-- To be served as a WFS layer by Geoserver using output format csv-with-metadata-header,
-- which will convert the jsonb `biovolumes` column into separate CSV columns on output.
CREATE MATERIALIZED VIEW bgc_phytoplankton_biovolume_genus_data AS
WITH grouped AS (
    -- join changelog on to raw data, pick only rows where genus identified
    -- group by trip, genus and changelog details
    SELECT r.trip_code,
           r.methods,
           r.genus,
           c.startdate,
           substring(taxon_name, '^\w+') != substring(parent_name, '^\w+') AS genus_changed,
           sum(r.biovolume_um3l) AS biovolume_um3l
    FROM bgc_phyto_raw r LEFT JOIN bgc_phyto_changelog c USING (taxon_name)
    WHERE r.genus IS NOT NULL AND 
          r.genus NOT LIKE '%cf.%'
    GROUP BY trip_code, methods, genus, startdate, genus_changed
), genera_affected AS (
    -- identify genera affected by a taxonomy change
    SELECT DISTINCT genus, methods, startdate
    FROM grouped
    WHERE genus_changed
), default_biovolumes AS (
    -- for genera affected by taxonomy change, set default biovolume values
    -- (NULL for 'not looked for', 0 for 'not found')
    SELECT m.trip_code,
           g.methods,
           g.genus,
           CASE
               WHEN m."SampleTime_UTC" < g.startdate THEN NULL
               ELSE 0.
           END AS biovolume_um3l
    FROM bgc_phytoplankton_map m CROSS JOIN genera_affected g
), defaults_and_grouped AS (
    -- stack together observations and default values
    SELECT trip_code, methods, genus, biovolume_um3l  FROM default_biovolumes
    UNION ALL
    SELECT trip_code, methods, genus, biovolume_um3l  FROM grouped
), regrouped AS (
    -- create a single row per trip/genus, making sure observed biovolumes override default values
    SELECT trip_code,
           methods,
           genus,
           max(biovolume_um3l) AS biovolume_um3l
    FROM defaults_and_grouped
    GROUP BY trip_code, methods, genus
), pivoted AS (
    -- aggregate all genera per trip into a single row
    SELECT trip_code,
           methods,
           jsonb_object_agg(genus, biovolume_um3l) AS biovolumes
    FROM regrouped
    GROUP BY trip_code, methods
)
-- join on to metadata columns, include a row for every trip with phytoplankton samples taken
SELECT m.*,
       p.methods AS "Method",
       p.biovolumes
FROM bgc_phytoplankton_map m LEFT JOIN pivoted p USING (trip_code)
;
