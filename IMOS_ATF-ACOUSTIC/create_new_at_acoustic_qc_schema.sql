CREATE ROLE animal_tracking_acoustic_qc LOGIN
  NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION  PASSWORD 'animal_tracking_acoustic_qc';
GRANT harvest_read_group TO animal_tracking_acoustic_qc;
GRANT harvest_reporting_write_group TO animal_tracking_acoustic_qc;
GRANT harvest_write_group TO animal_tracking_acoustic_qc;

GRANT animal_tracking_acoustic_qc TO imosadmin;

CREATE SCHEMA animal_tracking_acoustic_qc
  AUTHORIZATION animal_tracking_acoustic_qc;
