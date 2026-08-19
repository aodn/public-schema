-- Phytoplankton Raw biovolume product
CREATE OR REPLACE TABLE cpr_phytoplankton_biovolume_raw_data AS
WITH pivoted AS (
    -- aggregate all taxa per sample into a single row
    PIVOT cpr_phyto_raw
    ON taxon_name
    USING sum(biovol_um3m3)
    GROUP BY sample
)
-- join on to metadata columns, include a row for every trip with phytoplankton samples taken
SELECT m.*,
       p.* EXCLUDE (sample)
FROM cpr_phytoplankton_map m LEFT JOIN pivoted p USING (sample)
;
