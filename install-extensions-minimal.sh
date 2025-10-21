#!/bin/bash
set -e

# GeoServer Minimal Extensions Installation Script
# This script installs only the essential extensions to avoid startup issues

GEOSERVER_VERSION="${GEOSERVER_VERSION:-2.26.0}"
GEOSERVER_LIB="/usr/local/tomcat/webapps/geoserver/WEB-INF/lib"
BASE_URL="https://sourceforge.net/projects/geoserver/files/GeoServer/${GEOSERVER_VERSION}/extensions"

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "Installing GeoServer ${GEOSERVER_VERSION} Minimal Extensions"
echo "========================================="

# Function to install an extension
install_extension() {
    local plugin_name=$1
    local zip_file="geoserver-${GEOSERVER_VERSION}-${plugin_name}.zip"
    local download_url="${BASE_URL}/${zip_file}"
    
    echo -e "\n${YELLOW}[*]${NC} Installing ${plugin_name}..."
    
    cd /tmp
    
    # Try to download with retry logic
    local max_retries=3
    local retry_count=0
    local success=false
    
    while [ $retry_count -lt $max_retries ]; do
        if wget -q --timeout=30 --tries=2 "${download_url}"; then
            success=true
            break
        else
            retry_count=$((retry_count + 1))
            echo -e "${YELLOW}  Retry ${retry_count}/${max_retries}...${NC}"
            sleep 2
        fi
    done
    
    if [ "$success" = true ]; then
        if [ -f "${zip_file}" ]; then
            unzip -o -q "${zip_file}" -d "${GEOSERVER_LIB}/" 2>/dev/null || true
            rm -f "${zip_file}"
            echo -e "${GREEN}[✓]${NC} ${plugin_name} installed successfully"
            return 0
        else
            echo -e "${RED}[✗]${NC} ${plugin_name} - file not found after download"
            return 1
        fi
    else
        echo -e "${RED}[✗]${NC} ${plugin_name} - download failed (may not exist for this version)"
        return 1
    fi
}

# Minimal list of extensions - only the most essential ones
EXTENSIONS=(
    # Essential styling
    "css-plugin"                    # CSS Styling
    "ysld-plugin"                   # YAML-based styling
    
    # Essential data formats
    "importer-plugin"               # Bulk data import
    "dxf-plugin"                    # DXF output format
    "excel-plugin"                  # Excel output format
    
    # Essential processing
    "wps-plugin"                    # Web Processing Service (core)
    
    # Essential performance
    "control-flow-plugin"           # Request throttling and rate limiting
)

# Install each extension
success_count=0
failed_count=0
failed_extensions=()

for ext in "${EXTENSIONS[@]}"; do
    if install_extension "$ext"; then
        success_count=$((success_count + 1))
    else
        failed_count=$((failed_count + 1))
        failed_extensions+=("$ext")
    fi
done

# Summary
echo ""
echo "========================================="
echo "Installation Summary"
echo "========================================="
echo -e "${GREEN}Successfully installed: ${success_count}${NC}"
echo -e "${RED}Failed: ${failed_count}${NC}"

if [ ${#failed_extensions[@]} -gt 0 ]; then
    echo ""
    echo "Failed extensions (may not be available for this version):"
    for ext in "${failed_extensions[@]}"; do
        echo "  - $ext"
    done
fi

echo ""
echo "Cleaning up temporary files..."
rm -rf /tmp/*

echo -e "${GREEN}Minimal extension installation complete!${NC}"

# Exit successfully even if some extensions failed
exit 0
