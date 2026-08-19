-- CPR Phytoplankton Raw abundance product
CREATE OR REPLACE TABLE cpr_phytoplankton_abundance_raw_data AS
WITH pivoted AS (
    -- aggregate all taxa per trip into a single row
    PIVOT cpr_phyto_raw
    ON taxon_name
    USING sum(phyto_abundance_m3)
    GROUP BY sample
)
-- join on to metadata columns, include a row for every trip with phytoplankton samples taken
SELECT m.*,
       p.* EXCLUDE (sample)
FROM cpr_phytoplankton_map m LEFT JOIN pivoted p USING (sample)
;
