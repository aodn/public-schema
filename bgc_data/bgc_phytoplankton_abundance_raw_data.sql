-- Materialized view for Phytoplankton Raw products
-- To be served as 2 WFS layers by Geoserver using output format csv-with-metadata-header.
-- Each layer will pick one of the josnb columns (abundance or biovolume), which will be converted
-- into separate CSV columns on output.
CREATE MATERIALIZED VIEW bgc_phytoplankton_raw_data AS
  WITH pivoted AS (
    -- group all taxa from a given trip into a single row,
    -- aggregating abundances and biovolumes into separate jsonb columns
    SELECT
      trip_code,
      jsonb_object_agg(taxon_name, cell_l) AS abundances,
      jsonb_object_agg(taxon_name, biovolume_um3l) AS biovolumes
    FROM bgc_phyto_raw
    GROUP BY trip_code
  )
  SELECT
    m.*,
    coalesce(p.abundances, '{"Cylindrotheca closterium": 0}'::jsonb) AS abundances,
    coalesce(p.biovolumes, '{"Cylindrotheca closterium": 0}'::jsonb) AS biovolumes
  FROM bgc_phytoplankton_map m LEFT JOIN pivoted p USING (trip_code)
;
