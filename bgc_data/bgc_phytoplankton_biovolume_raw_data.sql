-- Materialized view for Phytoplankton Raw biovolume product
-- To be served as a WFS layer by Geoserver using output format csv-with-metadata-header,
-- which will convert the jsonb `biovolumes` column into separate CSV columns on output.
CREATE MATERIALIZED VIEW bgc_phytoplankton_biovolume_raw_data AS
WITH pivoted AS (
    -- aggregate all taxa per trip into a single row
    SELECT trip_code,
           methods,
           jsonb_object_agg(taxon_name, biovolume_um3l) AS biovolumes
    FROM bgc_phyto_raw
    GROUP BY trip_code, methods
)
-- join on to metadata columns, include a row for every trip with phytoplankton samples taken
SELECT m.*,
       p.methods AS "Method",
       p.biovolumes
FROM bgc_phytoplankton_map m LEFT JOIN pivoted p USING (trip_code)
;
