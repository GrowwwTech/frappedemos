#!/bin/bash
# Create all Growww demo sites. Run once, inside the backend container:
#   docker exec -it <backend> create-sites.sh
# Requires: DB_PASSWORD (mariadb root), ADMIN_PASSWORD (site Administrator).
set -euo pipefail

: "${DB_PASSWORD:?set DB_PASSWORD}"
: "${ADMIN_PASSWORD:?set ADMIN_PASSWORD}"

DOMAIN="demo.growwwtech.com"

# site-prefix:apps (comma-separated, in install order)
SITES=(
  "erp:erpnext,hrms,whitelabel"
  "health:erpnext,healthcare,whitelabel"
  "crm:crm,whitelabel"
  "helpdesk:helpdesk,whitelabel"
  "lms:lms,whitelabel"
  "insights:insights,whitelabel"
)

cd /home/frappe/frappe-bench

for entry in "${SITES[@]}"; do
  site="${entry%%:*}.${DOMAIN}"
  apps="${entry#*:}"

  if [ -d "sites/${site}" ]; then
    echo "== ${site} already exists, skipping"
    continue
  fi

  echo "== creating ${site} (${apps})"
  install_args=()
  IFS=',' read -ra app_list <<< "$apps"
  for app in "${app_list[@]}"; do
    install_args+=(--install-app "$app")
  done

  bench new-site \
    --mariadb-user-host-login-scope='%' \
    --admin-password="${ADMIN_PASSWORD}" \
    --db-root-username=root \
    --db-root-password="${DB_PASSWORD}" \
    "${install_args[@]}" \
    "${site}"

  # demos never send real email
  bench --site "${site}" set-config disable_emails 1
  bench --site "${site}" set-config disable_signup 1
done

echo "== all sites created"
bench --site all list-apps
