#!/usr/bin/env bash
set -euo pipefail

CONTAINER=anon-copy-repro
IMAGE=anon-copy-repro

# Clean any container left behind by this script or a previously-renamed copy.
docker rm -fv "$CONTAINER" >/dev/null 2>&1 || true

docker build --pull -t "$IMAGE" .
docker run --name "$CONTAINER" \
  -e POSTGRES_PASSWORD=postgres \
  -d "$IMAGE" >/dev/null

# The official postgres image runs entrypoint init scripts against a private
# unix socket, then restarts listening on TCP. A successful TCP query against
# test_db proves both phases finished: postgres is up AND 001-repro.sql ran.
# Fail fast if the container exits before becoming ready.
echo "Waiting for $CONTAINER to be ready..."
deadline=$(( $(date +%s) + 120 ))
while :; do
  if docker exec -e PGPASSWORD=postgres "$CONTAINER" \
       psql -h 127.0.0.1 -U postgres -d test_db -tAc 'SELECT 1' >/dev/null 2>&1; then
    break
  fi
  if ! docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -q true; then
    echo "Container exited before becoming ready. Logs:" >&2
    docker logs "$CONTAINER" >&2
    exit 1
  fi
  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "Timed out waiting for $CONTAINER. Logs:" >&2
    docker logs "$CONTAINER" >&2
    exit 1
  fi
  sleep 1
done

docker exec "$CONTAINER" /test.sh
