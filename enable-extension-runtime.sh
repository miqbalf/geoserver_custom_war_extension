#!/bin/bash

# Script to re-enable GeoServer extensions at runtime (no rebuild needed)
# Usage: ./enable-extension-runtime.sh <extension-name>

EXTENSION_NAME="$1"
CONTAINER_NAME="gis_geoserver_dev"
GEOSERVER_LIB="/usr/local/tomcat/webapps/geoserver/WEB-INF/lib"
BACKUP_DIR="/tmp/disabled-extensions"

if [ -z "$EXTENSION_NAME" ]; then
    echo "Usage: $0 <extension-name>"
    echo ""
    echo "To see disabled extensions, check:"
    echo "  docker exec $CONTAINER_NAME ls -la $BACKUP_DIR"
    exit 1
fi

# Check if container is running
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo "Error: Container $CONTAINER_NAME is not running"
    echo "Start it first with: docker-compose -f docker-compose.dev.yml up geoserver -d"
    exit 1
fi

echo "🔍 Looking for disabled $EXTENSION_NAME extension files..."

# Find disabled JAR files
DISABLED_FILES=$(docker exec "$CONTAINER_NAME" find "$BACKUP_DIR" -name "*${EXTENSION_NAME}*.disabled" 2>/dev/null || true)

if [ -z "$DISABLED_FILES" ]; then
    echo "❌ No disabled JAR files found for extension: $EXTENSION_NAME"
    echo "Disabled extensions:"
    docker exec "$CONTAINER_NAME" ls -la "$BACKUP_DIR" 2>/dev/null || echo "No disabled extensions found"
    exit 1
fi

echo "📦 Found disabled JAR files for $EXTENSION_NAME:"
echo "$DISABLED_FILES"
echo ""

# Move JAR files back to original location
ENABLED_COUNT=0
while IFS= read -r disabled_file; do
    if [ -n "$disabled_file" ]; then
        filename=$(basename "$disabled_file" .disabled)
        original_path="$GEOSERVER_LIB/$filename"
        echo "🔄 Re-enabling: $filename"
        docker exec "$CONTAINER_NAME" mv "$disabled_file" "$original_path"
        ENABLED_COUNT=$((ENABLED_COUNT + 1))
    fi
done <<< "$DISABLED_FILES"

echo ""
echo "✅ Re-enabled $ENABLED_COUNT JAR files for extension: $EXTENSION_NAME"
echo ""
echo "🔄 Restarting GeoServer to apply changes..."
docker-compose -f docker-compose.dev.yml restart geoserver

echo ""
echo "⏳ Wait 30-60 seconds for GeoServer to start, then check:"
echo "   docker-compose -f docker-compose.dev.yml logs geoserver --tail=20"
