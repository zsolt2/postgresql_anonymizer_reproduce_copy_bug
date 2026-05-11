ARG PG_VERSION=17
FROM postgres:${PG_VERSION}

ARG PG_VERSION=17
# Override at build time with --build-arg ANON_VERSION=x.y.z. Note: not every
# git tag has a matching .deb — 3.0.5..3.0.12 are CI-only tags per Dalibo's
# release notes, so 3.0.13 is the first usable 3.x .deb.
ARG ANON_VERSION=3.0.13

# Install postgresql_anonymizer from Dalibo's GitLab release assets. Dalibo
# does not run a public apt repo; the canonical Debian distribution is the
# .deb attached to each release on GitLab.
RUN set -eux \
 && apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && curl -fsSL -o /tmp/anon.deb \
      "https://gitlab.com/dalibo/postgresql_anonymizer/-/releases/${ANON_VERSION}/downloads/postgresql_anonymizer_${PG_VERSION}_${ANON_VERSION}_$(dpkg --print-architecture).deb" \
 && apt-get install -y --no-install-recommends /tmp/anon.deb \
 && rm /tmp/anon.deb \
 && rm -rf /var/lib/apt/lists/*

# Masking hooks (transparent_dynamic_masking, COPY rewriter) need the anon
# library loaded at session start. session_preload_libraries avoids a server
# restart and matches Dalibo's prebuilt image. The 000- prefix ensures this
# runs before 001-repro.sql.
RUN printf '%s\n' \
    '#!/bin/sh' \
    'set -e' \
    'psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres \' \
    '  -c "ALTER SYSTEM SET session_preload_libraries = '\''anon'\'';" \' \
    '  -c "SELECT pg_reload_conf();"' \
    > /docker-entrypoint-initdb.d/000-anon-preload.sh \
 && chmod +x /docker-entrypoint-initdb.d/000-anon-preload.sh

COPY 001-repro.sql /docker-entrypoint-initdb.d/001-repro.sql
COPY test.sh /test.sh
RUN chmod +x /test.sh
