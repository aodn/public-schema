-- Materialized view for larval fish count raw product
-- To be served as a WFS layer by Geoserver using output format csv-with-metadata-header,
-- which will convert the jsonb `abundances` column into separate CSV columns on output.
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

