-- PostgreSQL database settings for Turkish character support
-- Run this before schema.sql.
-- Adjust database name and owner if needed.

CREATE DATABASE dgs_db
    WITH
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'tr_TR.UTF-8'
    LC_CTYPE = 'tr_TR.UTF-8'
    TEMPLATE = template0;

\c dgs_db

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET timezone = 'Europe/Istanbul';

ALTER DATABASE dgs_db SET client_encoding TO 'UTF8';
ALTER DATABASE dgs_db SET timezone TO 'Europe/Istanbul';
