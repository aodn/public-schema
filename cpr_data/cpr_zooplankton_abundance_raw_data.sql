-- Materialized view for CPR Zooplankton Raw products
-- To be served as a WFS layer by Geoserver using output format csv-with-metadata-header,
-- which will convert the jsonb `abundances` column into separate CSV columns on output.
CREATE MATERIALIZED VIEW cpr_zooplankton_abundance_raw_data AS
WITH pivoted AS (
    -- aggregate all taxa per trip into a single row
    SELECT sample,
           jsonb_object_agg(taxon_name, zoop_abundance_m3) AS abundances
    FROM cpr_zoop_raw
    GROUP BY sample
)
-- join on to metadata columns, include a row for every trip with zooplankton samples taken
SELECT m.*,
       p.abundances
FROM cpr_zooplankton_map m LEFT JOIN pivoted p USING (sample)
;
