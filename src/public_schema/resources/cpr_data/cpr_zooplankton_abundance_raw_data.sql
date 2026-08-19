-- Materialized view for CPR Zooplankton Raw products
-- To be served as a WFS layer by Geoserver using output format csv-with-metadata-header,
-- which will convert the jsonb `abundances` column into separate CSV columns on output.
CREATE OR REPLACE TABLE cpr_zooplankton_abundance_raw_data AS
WITH pivoted AS (
    -- aggregate all taxa per trip into a single row
    PIVOT cpr_zoop_raw
    ON taxon_name
    USING sum(zoop_abundance_m3)
    GROUP BY sample
)
-- join on to metadata columns, include a row for every trip with zooplankton samples taken
SELECT m.*,
       p.* EXCLUDE (sample)
FROM cpr_zooplankton_map m LEFT JOIN pivoted p USING (sample)
;
