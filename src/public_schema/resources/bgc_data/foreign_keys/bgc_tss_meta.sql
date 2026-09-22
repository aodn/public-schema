ALTER TABLE bgc_tss_meta
    ADD FOREIGN KEY (trip_code) REFERENCES bgc_trip
;
