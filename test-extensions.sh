#!/bin/bash

# Script to systematically test GeoServer extensions
# This will disable extensions one by one and test if GeoServer starts

echo "🔍 GeoServer Extension Testing Script"
echo "====================================="
echo ""

# List of extensions to test (in order of likelihood to cause issues)
EXTENSIONS_TO_TEST=(
    "mongodb-plugin"
    "monitor-plugin"
    "cas-plugin"
    "oracle-plugin"
    "sqlserver-plugin"
    "vectortiles-plugin"
    "mapml-plugin"
    "authkey-plugin"
    "csw-plugin"
    "querylayer-plugin"
    "web-resource-plugin"
    "charts-plugin"
    "importer-plugin"
    "dxf-plugin"
    "excel-plugin"
    "geopkg-output-plugin"
    "wps-plugin"
    "wps-download-plugin"
    "wps-jdbc-plugin"
    "control-flow-plugin"
    "printing-plugin"
)

echo "📋 Extensions to test: ${#EXTENSIONS_TO_TEST[@]}"
echo ""

# Function to test if GeoServer starts successfully
test_geoserver() {
    echo "🔄 Building and starting GeoServer..."
    docker-compose -f docker-compose.dev.yml build geoserver > /dev/null 2>&1
    docker-compose -f docker-compose.dev.yml up geoserver -d > /dev/null 2>&1
    
    echo "⏳ Waiting 60 seconds for GeoServer to start..."
    sleep 60
    
    # Check if container is running
    if docker ps | grep -q "gis_geoserver_dev"; then
        echo "✅ Container is running"
        
        # Check logs for NullPointerException
        if docker-compose -f docker-compose.dev.yml logs geoserver --tail=50 | grep -q "NullPointerException"; then
            echo "❌ Still getting NullPointerException"
            return 1
        else
            echo "✅ No NullPointerException found in logs"
            
            # Test if GeoServer web interface is accessible
            if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/geoserver/web | grep -q "200\|302"; then
                echo "✅ GeoServer web interface is accessible!"
                return 0
            else
                echo "❌ GeoServer web interface not accessible"
                return 1
            fi
        fi
    else
        echo "❌ Container failed to start"
        return 1
    fi
}

# Test with all extensions first
echo "🧪 Testing with ALL extensions enabled..."
if test_geoserver; then
    echo ""
    echo "🎉 SUCCESS! GeoServer works with all extensions!"
    echo "The issue might not be with extensions."
    exit 0
else
    echo "❌ GeoServer failed with all extensions"
fi

echo ""
echo "🔍 Starting systematic extension testing..."
echo ""

# Test disabling each extension one by one
for ext in "${EXTENSIONS_TO_TEST[@]}"; do
    echo "🧪 Testing without extension: $ext"
    
    # Disable the extension
    ./disable-extension-build.sh "$ext" > /dev/null 2>&1
    
    # Test GeoServer
    if test_geoserver; then
        echo ""
        echo "🎉 FOUND THE PROBLEM!"
        echo "❌ Extension causing issues: $ext"
        echo ""
        echo "✅ GeoServer works without: $ext"
        echo ""
        echo "🔧 To keep this configuration:"
        echo "   The extension $ext is already disabled in install-extensions.sh"
        echo ""
        echo "🔧 To re-enable this extension later:"
        echo "   ./enable-extension-build.sh $ext"
        exit 0
    else
        echo "❌ Still failing without $ext"
        
        # Re-enable the extension for next test
        ./enable-extension-build.sh "$ext" > /dev/null 2>&1
    fi
    
    echo ""
done

echo "😞 No single extension was found to be the problem."
echo "The issue might be:"
echo "  - A combination of extensions"
echo "  - The Java 11 container metrics issue"
echo "  - Something else entirely"
echo ""
echo "💡 Try testing with minimal extensions:"
echo "   cp install-extensions-minimal.sh install-extensions.sh"
echo "   docker-compose -f docker-compose.dev.yml build geoserver"
