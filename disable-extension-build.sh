#!/bin/bash

# Script to disable GeoServer extensions at build time
# Usage: ./disable-extension-build.sh <extension-name>

EXTENSION_NAME="$1"
EXTENSIONS_FILE="install-extensions.sh"

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

# Check if extension exists in the file
if ! grep -q "\"$EXTENSION_NAME\"" "$EXTENSIONS_FILE"; then
    echo "Error: Extension '$EXTENSION_NAME' not found in $EXTENSIONS_FILE"
    exit 1
fi

# Create backup
cp "$EXTENSIONS_FILE" "${EXTENSIONS_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

# Disable the extension by commenting it out
sed -i.tmp "s/\"$EXTENSION_NAME\"/# \"$EXTENSION_NAME\" # DISABLED for troubleshooting/" "$EXTENSIONS_FILE"
rm -f "${EXTENSIONS_FILE}.tmp"

echo "✅ Disabled extension: $EXTENSION_NAME"
echo "📝 Backup created: ${EXTENSIONS_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
echo ""
echo "To rebuild GeoServer with this change:"
echo "  docker-compose -f docker-compose.dev.yml build geoserver"
echo "  docker-compose -f docker-compose.dev.yml up geoserver -d"
echo ""
echo "To re-enable this extension later:"
echo "  sed -i 's/# \"$EXTENSION_NAME\"/\"$EXTENSION_NAME\"/' $EXTENSIONS_FILE"
