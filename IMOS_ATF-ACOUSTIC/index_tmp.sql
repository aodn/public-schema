-- insert what has been harvested into the database with index_tmp
-- creates if needed the table detection_file_index
-- then creates the views to be used for WMS

CREATE TABLE IF NOT EXISTS detection_file_index
(
    tag_deployment_id TEXT PRIMARY KEY,
    transmitter_id TEXT,
    species TEXT,
    tagging_project TEXT,
    time_coverage_start timestamp with time zone,
    time_coverage_end timestamp with time zone,
    geom geometry(Geometry,4326),
    first_indexed timestamp with time zone DEFAULT Now(),
    last_indexed timestamp with time zone DEFAULT Now(),
    url TEXT,
    size integer
);

-- read geom from dataframe - multi point
SELECT AddGeometryColumn('animal_tracking_acoustic_qc','index_tmp','geom',4326,'MULTIPOINT',2);
UPDATE index_tmp
       SET geom = ST_GeomFromText(geom_df, 4326);

-- UPSERT
-- insert newly harvested record from index_tmp to the main table
-- 1. if tag_deployment_id does not exist --> new entry, insert everything
-- 2. if tag_deployment_id exists --> update record where needed
insert into detection_file_index (tag_deployment_id, transmitter_id, species, tagging_project,
                                  time_coverage_start, time_coverage_end, url, size, geom)
SELECT tag_deployment_id, transmitter_id, species, tagging_project, time_coverage_start, time_coverage_end,
       url, size, geom
FROM index_tmp
ON CONFLICT (tag_deployment_id)
DO
    UPDATE SET time_coverage_start = excluded.time_coverage_start, time_coverage_end = excluded.time_coverage_end,
               last_indexed = now()::timestamp, size = excluded.size,
               geom = excluded.geom
;