ALTER TABLE bgc_tss
    ADD FOREIGN KEY (trip_code) REFERENCES bgc_trip
;
