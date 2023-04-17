-- create the view to be served as a WMS by Geoserver
CREATE VIEW animal_tracking_acoustic_qc_detection_map AS
    SELECT
        -- dfi.id AS file_id,
        dfi.tag_deployment_id,
        dfi.url,
        dfi.size,
        dfi.transmitter_id,
        dfi.species,
	dfi.species_scientific_name,
        dfi.tagging_project,
        dfi.time_coverage_start,
        dfi.time_coverage_end,
        dfi.geom
    FROM detection_file_index dfi
;
