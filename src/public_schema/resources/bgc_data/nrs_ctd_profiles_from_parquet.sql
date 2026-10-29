-- Load a subset of the vessel_ctd_profiles_delayed_qc Parquet product into a table as the source data
-- for the NRS depth binned CTD product.
CREATE OR REPLACE TABLE nrs_ctd_profiles_from_parquet AS (
    SELECT
        site_code,
        filename,
        time,
        "DEPTH",
        "PSAL",
        "PSAL_quality_control",
        "TEMP", 
        "TEMP_quality_control", 
        "DOX2", 
        "DOX2_quality_control",
        "CPHL",
        "CPHL_quality_control", 
        "TURB", 
        "TURB_quality_control", 
        "CNDC", 
        "CNDC_quality_control", 
        "DENS", 
        "DENS_quality_control"
    FROM read_parquet('s3://aodn-cloud-optimised/vessel_ctd_profiles_delayed_qc.parquet/site_code=NRS*/**/*.parquet',
         hive_partitioning = true)
);
