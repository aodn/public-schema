CREATE MATERIALIZED VIEW bgc_phytoplankton_abundance_htg_data AS
  WITH grouped AS (
    SELECT
      trip_code,
      taxon_group,
      sum(cell_l) AS cell_l
    FROM bgc_phyto_raw
    WHERE taxon_group NOT IN ('Other', 'Coccolithophore', 'Diatom', 'Protozoa')
    GROUP BY trip_code, taxon_group
  )
  SELECT
    m.*,
    g.taxon_group,
    g.cell_l
  FROM bgc_phytoplankton_map m LEFT JOIN grouped g ON m."TripCode" = g.trip_code
;
