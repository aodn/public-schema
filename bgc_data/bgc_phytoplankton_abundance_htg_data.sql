-- Materialized view for Phytoplankton Higher Taxonomic Groups (HTG) products
-- To be served as 2 WFS layers by Geoserver using output format csv-with-metadata-header.
-- Each layer will pick one of the josnb columns (abundance or biovolume), which will be converted
-- into separate CSV columns on output.
CREATE MATERIALIZED VIEW bgc_phytoplankton_htg_data AS
  WITH grouped AS (
    -- sum up abundances & biovolumes for each trip/group,
    -- filtering out groups that are not phytoplankton
    SELECT
      trip_code,
      taxon_group,
      sum(cell_l) AS cell_l,
      sum(biovolume_um3l) AS biovolume_um3l
    FROM bgc_phyto_raw
    WHERE taxon_group NOT IN ('Other', 'Coccolithophore', 'Diatom', 'Protozoa')
    GROUP BY trip_code, taxon_group
  ), pivoted AS (
    -- group all taxon groups from a given trip into a single row,
    -- aggregating abundances and biovolumes into separate jsonb columns
      SELECT
      trip_code,
      jsonb_object_agg(taxon_group, cell_l) AS abundances,
      jsonb_object_agg(taxon_group, biovolume_um3l) AS biovolumes
      FROM grouped
      GROUP BY trip_code
  )
  SELECT
    m.*,
    coalesce(p.abundances, '{"Ciliate": 0}'::jsonb) AS abundances,
    coalesce(p.biovolumes, '{"Ciliate": 0}'::jsonb) AS biovolumes
  FROM bgc_phytoplankton_map m LEFT JOIN pivoted p USING (trip_code)
;
