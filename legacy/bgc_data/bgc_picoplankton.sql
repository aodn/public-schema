ALTER TABLE bgc_picoplankton
    ADD FOREIGN KEY (trip_code) REFERENCES bgc_trip
;
