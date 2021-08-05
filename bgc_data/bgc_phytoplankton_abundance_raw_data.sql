CREATE MATERIALIZED VIEW bgc_phytoplankton_abundance_raw_data AS
  SELECT
    m.*,
    r.taxon_name AS "TaxonName",
    r.cell_l AS "Cell_L",
    r.comments AS "Comments"
  FROM bgc_phytoplankton_map m LEFT JOIN bgc_phyto_raw r ON m."TripCode" = r.trip_code
;
