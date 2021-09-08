-- Materialized view for Zooplankton Higher Taxonomic Groups (HTG) product
-- To be served as a WFS layer by Geoserver using output format csv-with-metadata-header,
-- which will convert the josnb `abundances` column into separate CSV columns on output.
CREATE MATERIALIZED VIEW bgc_zooplankton_abundance_htg_data AS
WITH grouped AS (
    -- sum up abundances for each trip/group,
    -- filtering out groups that are not zooplankton
    SELECT trip_code,
           taxon_group,
           sum(zoop_abundance_m3) AS zoop_abundance_m3
    FROM bgc_zoop_raw
    WHERE taxon_group NOT IN ('Other')
    GROUP BY trip_code, taxon_group
), pivoted AS (
    -- aggregate all taxon groups per trip into a single row
    SELECT trip_code,
           jsonb_object_agg(taxon_group, zoop_abundance_m3) AS abundances
    FROM grouped
    GROUP BY trip_code
)
-- join on to metadata columns, include a row for every trip with zooplankton samples taken
-- add dummy entry in case no zooplankton have been identified in this sample
SELECT m.*,
       p.abundances
FROM bgc_zooplankton_map m LEFT JOIN pivoted p USING (trip_code)
;
