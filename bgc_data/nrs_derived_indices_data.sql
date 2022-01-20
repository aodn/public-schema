-- Materialized view for the NRS Derived Indices product
-- To be served as a WFS layer by Geoserver
-- CREATE MATERIALIZED VIEW nrs_derived_indices_data AS
WITH nrs_derived_indices_map AS (
    SELECT -- "StationName",
           "TripCode",
           -- "SampleTime_local"::date AS "SampleDateLocal",
           --TODO: "SampleDateUTC",
--            "Latitude",
--            "Longitude",
           "Biomass_mgm3",
           --TODO: "AshFreeBiomass_mgm3",
           --TODO: what about Year/Month/Day/Time?
--            zoopsampledepth_m AS "ZSampleDepth_m",
--            phytosampledepth_m AS "PSampleDepth_m"
           trip_code
    FROM bgc_trip_metadata
    WHERE "Project" = 'NRS'
), zoopinfo_mod AS (
    SELECT taxon_name,
           length_mm,
           CASE WHEN zi.diet = 'Carnivore' THEN 'CC'
                WHEN zi.diet = 'Omnivore' THEN 'CO'
                WHEN zi.diet = 'Herbivore' THEN 'CO'
               END AS diet
    FROM zoopinfo zi
), copepod_stats AS (
    SELECT zr.trip_code,
           sum(zr.zoop_abundance_m3) AS "CopeAbundance_taxm3",
           sum(zr.zoop_abundance_m3 * zi.length_mm) AS "CopeSumAbundanceLength",
           sum(zr.zoop_abundance_m3) FILTER ( WHERE zi.diet = 'CC') AS "CC",
           sum(zr.zoop_abundance_m3) FILTER ( WHERE zi.diet = 'CO') AS "CO"
    FROM bgc_zoop_raw zr LEFT JOIN zoopinfo_mod zi USING (taxon_name)
    WHERE zr.copepod = 'COPEPOD'
    GROUP BY trip_code
), zoo_stats AS (
    SELECT zr.trip_code,
           sum(zr.zoop_abundance_m3) AS "ZoopAbundance_taxm3"
    FROM bgc_zoop_raw zr LEFT JOIN copepod_stats cs USING (trip_code)
    GROUP BY trip_code
)

SELECT m.*,
       zs."ZoopAbundance_taxm3",
       cs."CopeAbundance_taxm3",
       cs."CopeSumAbundanceLength" / zs."ZoopAbundance_taxm3" AS "AvgTotalLengthCopepod_mm",
       --TODO: "OmnivoreCarnivoreCopepodRatio" or is it "HerbivoreCarnivoreCopepodRatio" ??
       cs."CO" / (cs."CO" + cs."CC") AS "HerbivoreCarnivoreCopepodRatio"
FROM nrs_derived_indices_map m LEFT JOIN zoo_stats zs USING (trip_code)
                               LEFT JOIN copepod_stats cs USING (trip_code)
ORDER BY trip_code DESC
;
