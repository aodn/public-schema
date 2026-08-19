-- CPR Zooplankton Raw products
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
