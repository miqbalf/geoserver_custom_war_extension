#!/bin/bash

# Script to disable GeoServer extensions at runtime (no rebuild needed)
# Usage: ./disable-extension-runtime.sh <extension-name>

EXTENSION_NAME="$1"
CONTAINER_NAME="gis_geoserver_dev"
GEOSERVER_LIB="/usr/local/tomcat/webapps/geoserver/WEB-INF/lib"

if [ -z "$EXTENSION_NAME" ]; then
    echo "Usage: $0 <extension-name>"
    echo ""
    echo "Available extensions to disable:"
    echo "  mongodb-plugin"
    echo "  monitor-plugin"
    echo "  cas-plugin"
    echo "  oracle-plugin"
    echo "  sqlserver-plugin"
    echo "  vectortiles-plugin"
    echo "  mapml-plugin"
    echo "  authkey-plugin"
    echo "  csw-plugin"
    echo "  querylayer-plugin"
    echo "  web-resource-plugin"
    echo "  charts-plugin"
    echo "  importer-plugin"
    echo "  dxf-plugin"
    echo "  excel-plugin"
    echo "  geopkg-output-plugin"
    echo "  wps-plugin"
    echo "  wps-download-plugin"
    echo "  wps-jdbc-plugin"
    echo "  control-flow-plugin"
    echo "  printing-plugin"
    exit 1
fi

# Check if container is running
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo "Error: Container $CONTAINER_NAME is not running"
    echo "Start it first with: docker-compose -f docker-compose.dev.yml up geoserver -d"
    exit 1
fi

echo "🔍 Looking for $EXTENSION_NAME extension files..."

# Find and disable extension JAR files
JAR_FILES=$(docker exec "$CONTAINER_NAME" find "$GEOSERVER_LIB" -name "*${EXTENSION_NAME}*.jar" 2>/dev/null || true)

if [ -z "$JAR_FILES" ]; then
    echo "❌ No JAR files found for extension: $EXTENSION_NAME"
    echo "Available extensions in container:"
    docker exec "$CONTAINER_NAME" find "$GEOSERVER_LIB" -name "*.jar" | grep -E "(plugin|extension)" | head -10
    exit 1
fi

echo "📦 Found JAR files for $EXTENSION_NAME:"
echo "$JAR_FILES"
echo ""

# Create backup directory
docker exec "$CONTAINER_NAME" mkdir -p /tmp/disabled-extensions

# Move JAR files to backup location
DISABLED_COUNT=0
while IFS= read -r jar_file; do
    if [ -n "$jar_file" ]; then
        filename=$(basename "$jar_file")
        echo "🔄 Disabling: $filename"
        docker exec "$CONTAINER_NAME" mv "$jar_file" "/tmp/disabled-extensions/$filename.disabled"
        DISABLED_COUNT=$((DISABLED_COUNT + 1))
    fi
done <<< "$JAR_FILES"

echo ""
echo "✅ Disabled $DISABLED_COUNT JAR files for extension: $EXTENSION_NAME"
echo "📁 Backup location: /tmp/disabled-extensions/"
echo ""
echo "🔄 Restarting GeoServer to apply changes..."
docker-compose -f docker-compose.dev.yml restart geoserver

echo ""
echo "⏳ Wait 30-60 seconds for GeoServer to start, then check:"
echo "   docker-compose -f docker-compose.dev.yml logs geoserver --tail=20"
echo ""
echo "🔧 To re-enable this extension later:"
echo "   ./enable-extension-runtime.sh $EXTENSION_NAME"
