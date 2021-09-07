ALTER TABLE bgc_phyto_raw
    ADD FOREIGN KEY (trip_code) REFERENCES bgc_trip,
    ADD FOREIGN KEY (taxon_name) REFERENCES bgc_phyto_changelog
;