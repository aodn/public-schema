-- Materialized view for Phytoplankton Raw biovolume product
-- To be served as a WFS layer by Geoserver using output format csv-with-metadata-header,
-- which will convert the jsonb `biovolumes` column into separate CSV columns on output.
CREATE MATERIALIZED VIEW cpr_phytoplankton_biovolume_raw_data AS
WITH pivoted AS (
    -- aggregate all taxa per sample into a single row
    SELECT sample,
           jsonb_object_agg(taxon_name, biovol_um3m3) AS biovolumes
    FROM cpr_phyto_raw
    GROUP BY sample
)
-- join on to metadata columns, include a row for every trip with phytoplankton samples taken
SELECT m.*,
       p.biovolumes
FROM cpr_phytoplankton_map m LEFT JOIN pivoted p USING (sample)
;
