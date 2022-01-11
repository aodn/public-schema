-- Materialized view for CPR Phytoplankton Genus biovolume product
-- To be served as a WFS layer by Geoserver using output format csv-with-metadata-header,
-- which will convert the jsonb `biovolumes` column into separate CSV columns on output.
CREATE MATERIALIZED VIEW cpr_phytoplankton_biovolume_genus_data AS
WITH grouped AS (
    -- join changelog on to raw data, pick only rows where genus identified
    -- group by trip, genus and changelog details
    SELECT r.sample,
           r.genus,
           c.startdate,
           substring(taxon_name, '^\w+') != substring(parent_name, '^\w+') AS genus_changed,
           sum(r.biovol_um3m3) AS biovol_um3m3
    FROM cpr_phyto_raw r LEFT JOIN cpr_phyto_changelog c USING (taxon_name)
    WHERE r.genus IS NOT NULL
    GROUP BY sample, genus, startdate, genus_changed
), genera_affected AS (
    -- identify genera affected by a taxonomy change
    SELECT DISTINCT genus, startdate
    FROM grouped
    WHERE genus_changed
), default_biovolumes AS (
    -- for genera affected by taxonomy change, set default biovolume values
    -- (NULL for 'not looked for', 0 for 'not found')
    SELECT m.sample,
           g.genus,
           CASE
               WHEN m."SampleDate_UTC" < g.startdate THEN NULL
               ELSE 0.
           END AS biovol_um3m3
    FROM cpr_phytoplankton_map m CROSS JOIN genera_affected g
), defaults_and_grouped AS (
    -- stack together observations and default values
    SELECT sample, genus, biovol_um3m3  FROM default_biovolumes
    UNION ALL
    SELECT sample, genus, biovol_um3m3  FROM grouped
), regrouped AS (
    -- create a single row per trip/genus, making sure observed biovolumes override default values
    SELECT sample,
           genus,
           max(biovol_um3m3) AS biovol_um3m3
    FROM defaults_and_grouped
    GROUP BY sample, genus
), pivoted AS (
    -- aggregate all genera per trip into a single row
    SELECT sample,
           jsonb_object_agg(genus, biovol_um3m3) AS biovolumes
    FROM regrouped
    GROUP BY sample
)
-- join on to metadata columns, include a row for every trip with phytoplankton samples taken
SELECT m.*,
       p.biovolumes
FROM cpr_phytoplankton_map m LEFT JOIN pivoted p USING (sample)
;
