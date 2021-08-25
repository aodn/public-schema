-- bgc_phytoplankton_abundance_genus_data
CREATE MATERIALIZED VIEW bgc_phytoplankton_abundance_genus_data AS
WITH grouped AS (
    SELECT r.trip_code,
           r.genus,
           c.startdate,
           substring(taxon_name, '^\w+') != substring(parent_name, '^\w+') AS genus_changed,
           sum(r.cell_l) AS cell_l
    FROM bgc_phyto_raw r LEFT JOIN bgc_phyto_changelog c USING (taxon_name)
    WHERE r.genus IS NOT NULL
    GROUP BY trip_code, genus, startdate, genus_changed
), genera_affected AS (
    SELECT DISTINCT genus, startdate
    FROM grouped
    WHERE genus_changed
), default_abundances AS (
    SELECT m.trip_code,
           g.genus,
           CASE
               WHEN m."SampleTime_local" < g.startdate THEN NULL
               ELSE 0.
           END AS cell_l
    FROM bgc_phytoplankton_map m CROSS JOIN genera_affected g
), defaults_and_grouped AS (
    SELECT trip_code, genus, cell_l  FROM default_abundances
    UNION ALL
    SELECT trip_code, genus, cell_l  FROM grouped
), regrouped AS (
    SELECT trip_code,
           genus,
           max(cell_l) AS cell_l
    FROM defaults_and_grouped
    GROUP BY trip_code, genus
), pivoted AS (
    SELECT trip_code,
           jsonb_object_agg(genus, cell_l) AS abundances
    FROM regrouped
    GROUP BY trip_code
)
SELECT m.*,
       p.abundances
FROM bgc_phytoplankton_map m LEFT JOIN pivoted p USING (trip_code)
;
