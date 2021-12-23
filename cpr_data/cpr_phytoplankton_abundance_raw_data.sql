-- Materialized view for CPR Phytoplankton Raw abundance product
-- To be served as a WFS layer by Geoserver using output format csv-with-metadata-header,
-- which will convert the jsonb `abundances` column into separate CSV columns on output.
CREATE MATERIALIZED VIEW cpr_phytoplankton_abundance_raw_data AS
WITH pivoted AS (
    -- aggregate all taxa per trip into a single row
    SELECT sample, --trip_code,
           jsonb_object_agg(taxon_name, phyto_abundance_m3) AS abundances --cell_l) AS abundances
    FROM cpr_phyto_raw
    GROUP BY sample --trip_code
)
-- join on to metadata columns, include a row for every trip with phytoplankton samples taken
SELECT m.*,
       p.abundances
FROM cpr_phytoplankton_map m LEFT JOIN pivoted p USING (sample) --(trip_code)
;

