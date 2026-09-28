-- ============================================================
-- OpsMind AI — 04_stages_file_formats.sql
-- Internal stage and file formats for data loading
-- ============================================================

USE DATABASE OPSMIND;
USE SCHEMA RAW;

-- File format for CSV seed data
CREATE FILE FORMAT IF NOT EXISTS CSV_FORMAT
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
    NULL_IF = ('', 'NULL', 'None')
    EMPTY_FIELD_AS_NULL = TRUE
    FIELD_DELIMITER = ','
    COMMENT = 'CSV format for OpsMind seed data loading';

-- Internal stage for seed data uploads
CREATE STAGE IF NOT EXISTS SEED_DATA_STAGE
    FILE_FORMAT = CSV_FORMAT
    COMMENT = 'Internal stage for OpsMind seed data CSV and document files';

-- File format for Markdown documents (single-column text)
CREATE FILE FORMAT IF NOT EXISTS TEXT_FORMAT
    TYPE = 'CSV'
    FIELD_DELIMITER = 'NONE'
    RECORD_DELIMITER = 'NONE'
    SKIP_HEADER = 0
    COMMENT = 'Raw text format for document loading';
