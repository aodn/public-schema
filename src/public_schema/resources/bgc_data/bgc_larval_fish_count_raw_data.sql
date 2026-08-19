-- Larval fish count raw product
CREATE OR REPLACE TABLE bgc_larval_fish_count_raw_data AS
WITH pivoted AS (
   PIVOT bgc_lfish_countraw
   ON scientificname
   USING sum(taxon_count)
   GROUP BY i_sample_id
)
-- join on to metadata columns, include a row for every trip with larval fish samples taken
   SELECT 
      m.*,
      p.* EXCLUDE (i_sample_id)
   FROM bgc_larval_fish_map m LEFT JOIN pivoted p USING (i_sample_id)
;

