-- BRONZE COLUMNS: LocationID, Borough, Zone, service_zone

CREATE TABLE IF NOT EXISTS `ftw-week-08`.`03-silver`.taxi_zones_clean (

    location_id INT,

    borough STRING,
    zone_name STRING,
    service_zone STRING,

    zone_classification STRING,

    source_system STRING,
    source_file STRING,
    source_file_version STRING,
    batch_id STRING,
    ingested_at TIMESTAMP,

    silver_processed_at TIMESTAMP
);

MERGE INTO `ftw-week-08`.`03-silver`.taxi_zones_clean AS target

USING (

   SELECT

    CAST(location_id AS INT) AS location_id,

    trim(borough) AS borough,

    trim(zone) AS zone_name,

    CASE
        WHEN service_zone = 'N/A' THEN 'na'
        ELSE lower(trim(service_zone))
    END AS service_zone,

    CASE
        WHEN location_id = 264 THEN 'unknown'
        WHEN location_id = 265 THEN 'outside_nyc'
        WHEN borough = 'EWR' THEN 'ewr'
        WHEN borough IN (
            'Bronx',
            'Brooklyn',
            'Manhattan',
            'Queens',
            'Staten Island'
        ) THEN 'nyc_borough'
        ELSE 'other_special'
    END AS zone_classification,

    'nyc_tlc_taxi_zones' AS source_system,

    source_file,

    source_file_version,

    batch_id,

    ingested_at,

    current_timestamp() AS silver_processed_at

FROM `ftw-week-08`.`02-bronze`.taxi_zones_raw

) AS source

ON target.location_id = source.location_id

WHEN NOT MATCHED THEN INSERT (

    location_id,

    borough,
    zone_name,
    service_zone,

    zone_classification,

    source_system,
    source_file,
    source_file_version,
    batch_id,
    ingested_at,

    silver_processed_at
)

VALUES (

    source.location_id,

    source.borough,
    source.zone_name,
    source.service_zone,

    source.zone_classification,

    source.source_system,
    source.source_file,
    source.source_file_version,
    source.batch_id,
    source.ingested_at,

    source.silver_processed_at
);
