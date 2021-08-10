CREATE MATERIALIZED VIEW bgc_phytoplankton_abundance_raw_data AS
  WITH pivoted AS (
    SELECT
      trip_code,
      jsonb_object_agg(taxon_name, cell_l) AS jsonb_abundances
    FROM bgc_phyto_raw
    GROUP BY trip_code
  )
  SELECT
    m.*,
--    p.jsonb_abundances
    coalesce(p.jsonb_abundances, '{"Cylindrotheca closterium": 0}'::jsonb) AS jsonb_abundances
  FROM bgc_phytoplankton_map m LEFT JOIN pivoted p USING (trip_code)
;
