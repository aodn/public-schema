ALTER TABLE bgc_lfish_countraw
    ADD FOREIGN KEY (i_sample_id) REFERENCES bgc_lfish_samples
;
