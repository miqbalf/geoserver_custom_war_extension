#!/bin/bash

# Script to re-enable GeoServer extensions at build time
# Usage: ./enable-extension-build.sh <extension-name>

EXTENSION_NAME="$1"
EXTENSIONS_FILE="install-extensions.sh"

if [ -z "$EXTENSION_NAME" ]; then
    echo "Usage: $0 <extension-name>"
    echo ""
    echo "To see disabled extensions, check $EXTENSIONS_FILE for lines starting with #"
    exit 1
fi

# Check if extension is disabled in the file
if ! grep -q "# \"$EXTENSION_NAME\"" "$EXTENSIONS_FILE"; then
    echo "Error: Extension '$EXTENSION_NAME' is not currently disabled in $EXTENSIONS_FILE"
    exit 1
fi

# Create backup
cp "$EXTENSIONS_FILE" "${EXTENSIONS_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

# Re-enable the extension by uncommenting it
sed -i.tmp "s/# \"$EXTENSION_NAME\"/\"$EXTENSION_NAME\"/" "$EXTENSIONS_FILE"
rm -f "${EXTENSIONS_FILE}.tmp"

echo "✅ Re-enabled extension: $EXTENSION_NAME"
echo "📝 Backup created: ${EXTENSIONS_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
echo ""
echo "To rebuild GeoServer with this change:"
echo "  docker-compose -f docker-compose.dev.yml build geoserver"
echo "  docker-compose -f docker-compose.dev.yml up geoserver -d"
