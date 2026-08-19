-- Materialized view for Phytoplankton Raw abundance product
-- To be served as a WFS layer by Geoserver using output format csv-with-metadata-header,
-- which will convert the jsonb `abundances` column into separate CSV columns on output.
CREATE OR REPLACE TABLE bgc_phytoplankton_abundance_raw_data AS
WITH pivoted AS (
    -- aggregate all taxa per trip into a single row
    PIVOT bgc_phyto_raw
    ON taxon_name
    USING sum(cell_l)
    GROUP BY trip_code, methods
)
-- join on to metadata columns, include a row for every trip with phytoplankton samples taken
SELECT m.*,
       p.methods AS "Method",
       p.* EXCLUDE (trip_code, methods)
FROM bgc_phytoplankton_map m LEFT JOIN pivoted p USING (trip_code)
;
