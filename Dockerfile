FROM registry.gitlab.com/dalibo/postgresql_anonymizer:stable

COPY 001-repro.sql /docker-entrypoint-initdb.d/001-repro.sql
COPY test.sh /test.sh

RUN chmod +x /test.sh