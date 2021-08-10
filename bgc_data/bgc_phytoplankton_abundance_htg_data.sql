CREATE MATERIALIZED VIEW bgc_phytoplankton_abundance_htg_data AS
  WITH grouped AS (
    SELECT
      trip_code,
      taxon_group,
      sum(cell_l) AS cell_l
    FROM bgc_phyto_raw
    WHERE taxon_group NOT IN ('Other', 'Coccolithophore', 'Diatom', 'Protozoa')
    GROUP BY trip_code, taxon_group
  ), pivoted AS (
    SELECT
      trip_code,
      jsonb_object_agg(taxon_group, cell_l) AS jsonb_abundances
    FROM grouped
    GROUP BY trip_code
  )
  SELECT
    m.*,
    coalesce(p.jsonb_abundances, '{"Ciliate": 0}'::jsonb) AS jsonb_abundances
  FROM bgc_phytoplankton_map m LEFT JOIN pivoted p USING (trip_code)
;
