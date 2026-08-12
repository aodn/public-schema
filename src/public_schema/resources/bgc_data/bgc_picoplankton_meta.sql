ALTER TABLE bgc_picoplankton_meta
    ADD FOREIGN KEY (trip_code) REFERENCES bgc_trip
;
