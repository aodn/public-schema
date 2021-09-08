-- Materialized view for Phytoplankton Higher Taxonomic Groups (HTG) biovolume product
-- To be served as a WFS layer by Geoserver using output format csv-with-metadata-header,
-- which will convert the josnb `biovolumes` column into separate CSV columns on output.
CREATE MATERIALIZED VIEW bgc_phytoplankton_biovolume_htg_data AS
WITH grouped AS (
    -- sum up biovolumes for each trip/group,
    -- filtering out groups that are not phytoplankton
    SELECT trip_code,
           taxon_group,
           sum(biovolume_um3l) AS biovolume_um3l
    FROM bgc_phyto_raw
    WHERE taxon_group NOT IN ('Other', 'Coccolithophore', 'Diatom', 'Protozoa')
    GROUP BY trip_code, taxon_group
), pivoted AS (
    -- aggregate all taxon groups per trip into a single row
    SELECT trip_code,
           jsonb_object_agg(taxon_group, biovolume_um3l) AS biovolumes
    FROM grouped
    GROUP BY trip_code
)
-- join on to metadata columns, include a row for every trip with phytoplankton samples taken
-- add dummy entry in case no phytoplankton have been identified in this sample
SELECT m.*,
       p.biovolumes
FROM bgc_phytoplankton_map m LEFT JOIN pivoted p USING (trip_code)
;
