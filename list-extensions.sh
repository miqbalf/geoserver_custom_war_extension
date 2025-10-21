#!/bin/bash

# Script to list all GeoServer extensions (enabled and disabled)
# Usage: ./list-extensions.sh

CONTAINER_NAME="gis_geoserver_dev"
GEOSERVER_LIB="/usr/local/tomcat/webapps/geoserver/WEB-INF/lib"
BACKUP_DIR="/tmp/disabled-extensions"

echo "🔍 GeoServer Extensions Status"
echo "================================"

# Check if container is running
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo "❌ Container $CONTAINER_NAME is not running"
    echo "Start it first with: docker-compose -f docker-compose.dev.yml up geoserver -d"
    exit 1
fi

echo ""
echo "✅ ENABLED Extensions:"
echo "----------------------"
ENABLED_EXTENSIONS=$(docker exec "$CONTAINER_NAME" find "$GEOSERVER_LIB" -name "*.jar" | grep -E "(plugin|extension)" | sort)
if [ -n "$ENABLED_EXTENSIONS" ]; then
    echo "$ENABLED_EXTENSIONS" | while read -r jar_file; do
        filename=$(basename "$jar_file")
        echo "  ✅ $filename"
    done
else
    echo "  No extensions found"
fi

echo ""
echo "❌ DISABLED Extensions:"
echo "-----------------------"
DISABLED_EXTENSIONS=$(docker exec "$CONTAINER_NAME" find "$BACKUP_DIR" -name "*.disabled" 2>/dev/null || true)
if [ -n "$DISABLED_EXTENSIONS" ]; then
    echo "$DISABLED_EXTENSIONS" | while read -r disabled_file; do
        filename=$(basename "$disabled_file" .disabled)
        echo "  ❌ $filename"
    done
else
    echo "  No disabled extensions"
fi

echo ""
echo "📊 Summary:"
ENABLED_COUNT=$(echo "$ENABLED_EXTENSIONS" | wc -l)
DISABLED_COUNT=$(echo "$DISABLED_EXTENSIONS" | wc -l)
echo "  Enabled: $ENABLED_COUNT"
echo "  Disabled: $DISABLED_COUNT"
echo "  Total: $((ENABLED_COUNT + DISABLED_COUNT))"

echo ""
echo "🛠️  Quick Commands:"
echo "  Disable extension: ./disable-extension-runtime.sh <name>"
echo "  Enable extension:  ./enable-extension-runtime.sh <name>"
echo "  Check logs:        docker-compose -f docker-compose.dev.yml logs geoserver --tail=20"
