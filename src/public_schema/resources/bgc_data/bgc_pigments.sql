ALTER TABLE bgc_pigments
    ADD FOREIGN KEY (trip_code) REFERENCES bgc_trip
;
