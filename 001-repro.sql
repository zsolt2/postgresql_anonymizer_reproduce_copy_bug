CREATE DATABASE test_db;
\c test_db

CREATE EXTENSION IF NOT EXISTS anon CASCADE;
SELECT anon.init();

CREATE SCHEMA test_schema;

CREATE TABLE test_schema.test_table (
    id integer,
    example_column numeric,
    "Example Column" numeric,
    "MixedCase" numeric,
    "col!@#$%" numeric,
    "naïve_café" numeric,
    "col""with""quotes" numeric,
    "select" numeric,
    "col.with.dot" numeric,
    "col-with-dash" numeric,
    "col'with'apostrophe" numeric,
    "123abc" numeric,
    "col with  multiple   spaces" numeric,
    " leading_space" numeric,
    "trailing_space " numeric
);

INSERT INTO test_schema.test_table
VALUES (1, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100);

CREATE ROLE anon_user LOGIN PASSWORD 'anon';
CREATE ROLE table_owner LOGIN PASSWORD 'owner';

ALTER TABLE test_schema.test_table OWNER TO table_owner;

GRANT USAGE ON SCHEMA test_schema TO anon_user, table_owner;
GRANT SELECT ON test_schema.test_table TO anon_user;

ALTER ROLE anon_user SET anon.transparent_dynamic_masking = true;
SECURITY LABEL FOR anon ON ROLE anon_user IS 'MASKED';
