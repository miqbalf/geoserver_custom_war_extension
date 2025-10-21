#!/bin/bash

# Enhanced GeoServer Extensions Installation Script
# Based on GeoNode approach with better error handling and SSO support

set -e

echo "🔧 Installing GeoServer Extensions..."

# GeoServer version
GEOSERVER_VERSION=${GEOSERVER_VERSION:-2.26.0}
GEOSERVER_LIB_DIR="/usr/local/tomcat/webapps/geoserver/WEB-INF/lib"
EXTENSIONS_CACHE_DIR="/tmp/geoserver-extensions-cache"

# Create cache directory
mkdir -p $EXTENSIONS_CACHE_DIR

# Function to download extension
download_extension() {
    local extension_name=$1
    local version=$2
    local url="https://sourceforge.net/projects/geoserver/files/GeoServer/${GEOSERVER_VERSION}/extensions/geoserver-${GEOSERVER_VERSION}-${extension_name}-plugin.zip"
    
    echo "📦 Downloading $extension_name..."
    
    if [ -f "$EXTENSIONS_CACHE_DIR/${extension_name}.zip" ]; then
        echo "   Using cached version of $extension_name"
        return 0
    fi
    
    if wget --no-check-certificate --progress=bar:force:noscroll -O "$EXTENSIONS_CACHE_DIR/${extension_name}.zip" "$url" 2>/dev/null; then
        echo "   ✅ Downloaded $extension_name"
    else
        echo "   ❌ Failed to download $extension_name"
        return 1
    fi
}

# Function to install extension
install_extension() {
    local extension_name=$1
    local version=$2
    
    echo "🔧 Installing $extension_name..."
    
    if [ ! -f "$EXTENSIONS_CACHE_DIR/${extension_name}.zip" ]; then
        download_extension "$extension_name" "$version" || return 1
    fi
    
    # Extract and install
    cd $EXTENSIONS_CACHE_DIR
    unzip -q "${extension_name}.zip" -d temp_${extension_name}
    
    # Copy JAR files to GeoServer lib directory
    find temp_${extension_name} -name "*.jar" -exec cp {} $GEOSERVER_LIB_DIR/ \;
    
    # Cleanup
    rm -rf temp_${extension_name}
    
    echo "   ✅ Installed $extension_name"
}

# Core extensions for GIS Carbon AI
CORE_EXTENSIONS=(
    "wps"
    "importer"
    "monitor"
    "control-flow"
    "css"
    "ysld"
    "sldservice"
    "querylayer"
    "csw"
    "wcs"
    "wfs"
    "wms"
    "wmts"
    "gwc"
    "vectortiles"
    "mbstyle"
    "printing"
    "libreoffice"
    "oracle"
    "mysql"
    "sqlserver"
    "h2"
    "arcsde"
    "app-schema"
    "dxf"
    "excel"
    "gdal"
    "geopkg"
    "imagepyramid"
    "imagemosaic"
    "netcdf"
    "ogr"
    "pgraster"
    "pyramid"
    "rasterlite"
    "s3"
    "teradata"
    "wps-cluster"
    "xslt"
    "ysld"
    "zarr"
)

# SSO and Security extensions
SSO_EXTENSIONS=(
    "authkey"
    "cas"
    "ldap"
    "oauth2"
    "saml"
    "rest"
    "security"
)

# Performance and monitoring extensions
PERFORMANCE_EXTENSIONS=(
    "monitor"
    "control-flow"
    "gwc"
    "vectortiles"
    "mbstyle"
)

echo "📋 Installing core extensions..."
for extension in "${CORE_EXTENSIONS[@]}"; do
    install_extension "$extension" "$GEOSERVER_VERSION" || echo "   ⚠️  $extension installation failed (may not be available)"
done

echo "🔐 Installing SSO and security extensions..."
for extension in "${SSO_EXTENSIONS[@]}"; do
    install_extension "$extension" "$GEOSERVER_VERSION" || echo "   ⚠️  $extension installation failed (may not be available)"
done

echo "⚡ Installing performance extensions..."
for extension in "${PERFORMANCE_EXTENSIONS[@]}"; do
    install_extension "$extension" "$GEOSERVER_VERSION" || echo "   ⚠️  $extension installation failed (may not be available)"
done

# Install custom extensions if they exist
if [ -d "/tmp/custom-extensions" ]; then
    echo "🔧 Installing custom extensions..."
    find /tmp/custom-extensions -name "*.jar" -exec cp {} $GEOSERVER_LIB_DIR/ \;
    echo "   ✅ Custom extensions installed"
fi

# Verify installation
echo "🔍 Verifying extension installation..."
INSTALLED_EXTENSIONS=$(find $GEOSERVER_LIB_DIR -name "*.jar" | wc -l)
echo "   📊 Total JAR files in GeoServer: $INSTALLED_EXTENSIONS"

# List some key extensions
echo "   🔑 Key extensions installed:"
find $GEOSERVER_LIB_DIR -name "*wps*.jar" -o -name "*monitor*.jar" -o -name "*control*.jar" -o -name "*auth*.jar" | head -10

echo "✅ GeoServer extensions installation completed!"

# Cleanup cache if requested
if [ "${CLEANUP_CACHE:-false}" = "true" ]; then
    echo "🧹 Cleaning up extension cache..."
    rm -rf $EXTENSIONS_CACHE_DIR
fi