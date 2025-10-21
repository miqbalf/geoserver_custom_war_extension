#!/bin/bash
set -e

echo "🚀 Starting GeoServer basic setup..."

GEOSERVER_URL=${GEOSERVER_URL:-"http://localhost:8080/geoserver"}
GEOSERVER_ADMIN_USER=${GEOSERVER_ADMIN_USER:-"admin"}
GEOSERVER_ADMIN_PASSWORD=${GEOSERVER_ADMIN_PASSWORD:-"geoserver"}

wait_for_geoserver() {
  echo "⏳ Waiting for GeoServer..."
  until curl -fsu "$GEOSERVER_ADMIN_USER:$GEOSERVER_ADMIN_PASSWORD" \
      "$GEOSERVER_URL/rest/about/version.json" >/dev/null 2>&1; do
    echo "  Waiting..."
    sleep 3
  done
  echo "✅ GeoServer ready!"
}

setup_users_and_roles() {
  echo "👤 Creating demo users and roles..."

  curl -s -u "$GEOSERVER_ADMIN_USER:$GEOSERVER_ADMIN_PASSWORD" \
    -X POST -H "Content-type: application/json" \
    -d '{"user":{"userName":"demo_user","password":"demo123","enabled":true}}' \
    "$GEOSERVER_URL/rest/security/usergroup/default/users"

  curl -s -u "$GEOSERVER_ADMIN_USER:$GEOSERVER_ADMIN_PASSWORD" \
    -X POST -H "Content-type: application/json" \
    -d '{"roleName":"ROLE_ANALYST"}' \
    "$GEOSERVER_URL/rest/security/roles/default/roles"

  curl -s -u "$GEOSERVER_ADMIN_USER:$GEOSERVER_ADMIN_PASSWORD" \
    -X POST -H "Content-type: application/json" \
    -d '{"roleName":"ROLE_ANALYST","userName":"demo_user"}' \
    "$GEOSERVER_URL/rest/security/roles/default/rolemembers"
}

main() {
  wait_for_geoserver
  setup_users_and_roles
  echo "✅ Basic setup complete!"
}

main "$@"
