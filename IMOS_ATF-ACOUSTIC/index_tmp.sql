-- insert what has been harvested into the database
-- creates if needed the table detection_file_index
-- then creates the views to be used for WMS

-- create the full index table when doesn't exist (= the first time it runs)
-- should ONLY run ONCE
-- could disable and safe keep this script here for reference once run
--/*
CREATE TABLE IF NOT EXISTS animal_tracking_acoustic_qc.detection_file_index
(
    id bigserial PRIMARY KEY,
    tag_deployment_id varchar(55) UNIQUE NOT NULL,
    transmitter_id varchar(55),
    species varchar(55),
    tag_project varchar(255),
    time_coverage_start timestamp with time zone,
    time_coverage_end timestamp with time zone,
    min_lat double precision,
    max_lat double precision,
    min_lon double precision,
    max_lon double precision,
    geom geometry(Geometry,4326),
    first_indexed timestamp with time zone,
    last_indexed timestamp with time zone,
    url varchar(255),
    size integer,
    FOREIGN KEY (tag_deployment_id)
        REFERENCES animal_tracking_acoustic_qc.index_tmp(tag_deployment_id)
);
alter table animal_tracking_acoustic_qc.detection_file_index
    owner to animal_tracking_acoustic_qc;


-- create the geometry column
--SET search_path = harvest, public;
SELECT AddGeometryColumn('animal_tracking_acoustic_qc','index_tmp','geom',4326,'POLYGON',2);
UPDATE animal_tracking_acoustic_qc.index_tmp SET geom = ST_GeomFromText('POLYGON(('|| min_lon::text ||' '|| min_lat::text ||','|| min_lon::text ||' '|| max_lat::text ||',
'|| max_lon::text ||' '|| min_lat::text ||','|| max_lon::text ||' '|| max_lat::text ||', '|| min_lon::text ||' '|| min_lat::text ||'))', 4326);


-- insert newly harvested record from index_tmp to the main table
-- 1. if tag_deployment_id does not exist --> new entry, insert everything
-- 2. if tag_deployment_id exists --> update record where needed
insert into animal_tracking_acoustic_qc.detection_file_index (tag_deployment_id, transmitter_id, species, tag_project,
                                                              time_coverage_start, time_coverage_end, min_lat, max_lat,
                                                              min_lon, max_lon, first_indexed, last_indexed, url, size,
                                                              geom)
SELECT tag_deployment_id, transmitter_id, species, tag_project, time_coverage_start, time_coverage_end, min_lat,
       max_lat, min_lon, max_lon, first_indexed, last_indexed, url, size, geom
FROM animal_tracking_acoustic_qc.index_tmp
ON CONFLICT (tag_deployment_id)
DO
    UPDATE SET time_coverage_start = excluded.time_coverage_start, time_coverage_end = excluded.time_coverage_end,
               min_lat = excluded.min_lat, max_lat = excluded.max_lat, min_lon = excluded.min_lon,
               max_lon = excluded.max_lon, last_indexed = excluded.last_indexed, size = excluded.size,
               geom = excluded.geom
;

