ALTER TABLE bgc_phyto_raw
    ADD FOREIGN KEY (trip_code) REFERENCES bgc_trip
;
