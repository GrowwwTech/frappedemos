#!/bin/bash
# Nightly demo reset: restore every site from its golden backup.
# Golden backups live in /home/frappe/golden-backups/<site>/ and are created with:
#   take-golden: bench --site <site> backup --with-files
#                then copy the newest set into /home/frappe/golden-backups/<site>/
# Usage:
#   reset-demos.sh              -> restore all sites from golden backups
#   reset-demos.sh take-golden  -> snapshot current state of all sites as golden
set -euo pipefail

: "${DB_PASSWORD:?set DB_PASSWORD}"

GOLDEN=/home/frappe/golden-backups
cd /home/frappe/frappe-bench

sites=$(ls sites | grep -v -E '^(apps.txt|assets|common_site_config.json|currentsite.txt)$')

if [ "${1:-}" = "take-golden" ]; then
  for site in $sites; do
    echo "== golden snapshot: ${site}"
    bench --site "${site}" backup --with-files
    mkdir -p "${GOLDEN}/${site}"
    rm -f "${GOLDEN}/${site}"/*
    latest_db=$(ls -t "sites/${site}/private/backups/"*-database.sql.gz | head -1)
    prefix="${latest_db%-database.sql.gz}"
    cp "${latest_db}" "${GOLDEN}/${site}/database.sql.gz"
    [ -f "${prefix}-files.tar" ] && cp "${prefix}-files.tar" "${GOLDEN}/${site}/files.tar"
    [ -f "${prefix}-private-files.tar" ] && cp "${prefix}-private-files.tar" "${GOLDEN}/${site}/private-files.tar"
  done
  echo "== golden snapshots done"
  exit 0
fi

for site in $sites; do
  if [ ! -f "${GOLDEN}/${site}/database.sql.gz" ]; then
    echo "== ${site}: no golden backup, skipping"
    continue
  fi
  echo "== resetting ${site}"
  restore_args=()
  [ -f "${GOLDEN}/${site}/files.tar" ] && restore_args+=(--with-public-files "${GOLDEN}/${site}/files.tar")
  [ -f "${GOLDEN}/${site}/private-files.tar" ] && restore_args+=(--with-private-files "${GOLDEN}/${site}/private-files.tar")
  bench --site "${site}" --force restore \
    --db-root-username=root \
    --db-root-password="${DB_PASSWORD}" \
    "${restore_args[@]}" \
    "${GOLDEN}/${site}/database.sql.gz"
  bench --site "${site}" migrate
done

echo "== all demos reset"
