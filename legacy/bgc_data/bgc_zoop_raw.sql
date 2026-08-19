ALTER TABLE bgc_zoop_raw
    ADD FOREIGN KEY (trip_code) REFERENCES bgc_trip
;
