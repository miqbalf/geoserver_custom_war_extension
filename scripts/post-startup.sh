#!/bin/bash
# Post-startup configuration script for GeoServer
set -e

# Prevent multiple simultaneous executions
LOCK_FILE="/tmp/post-startup.lock"
if [ -f "$LOCK_FILE" ]; then
    echo "⚠️ Post-startup script already running, skipping..."
    exit 0
fi

# Create lock file
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

echo "🔧 Running GeoServer post-startup configuration..."

# Set default values for environment variables
GEOSERVER_DATA_DIR=${GEOSERVER_DATA_DIR:-"/geoserver_data/data"}
GEOSERVER_CORS_ENABLED=${GEOSERVER_CORS_ENABLED:-"true"}
GEOSERVER_CORS_ALLOWED_ORIGINS=${GEOSERVER_CORS_ALLOWED_ORIGINS:-"*"}
GEOSERVER_CORS_ALLOWED_METHODS=${GEOSERVER_CORS_ALLOWED_METHODS:-"GET,POST,PUT,DELETE,HEAD,OPTIONS"}
GEOSERVER_CORS_ALLOWED_HEADERS=${GEOSERVER_CORS_ALLOWED_HEADERS:-"*"}

# Database connection variables
DATABASE_HOST=${DATABASE_HOST:-"postgres"}
DATABASE_PORT=${DATABASE_PORT:-"5432"}
DATABASE_NAME=${DATABASE_NAME:-"gis_carbon_data"}
DATABASE_USER=${DATABASE_USER:-"gis_user"}
DATABASE_PASSWORD=${DATABASE_PASSWORD:-"gis_password"}
DATABASE_SCHEMA=${DATABASE_SCHEMA:-"public"}

# GeoServer connection variables
GEOSERVER_HOST=${GEOSERVER_HOST:-"localhost"}
GEOSERVER_PORT=${GEOSERVER_PORT:-"8080"}
GEOSERVER_USER=${GEOSERVER_USER:-"admin"}
GEOSERVER_PASS=${GEOSERVER_PASS:-"admin"}

# Workspace and datastore names
WORKSPACE=${WORKSPACE:-"gis_carbon"}
DATASTORE=${DATASTORE:-"gis_carbon_postgis"}

echo "📋 Environment configuration:"
echo "  - GEOSERVER_DATA_DIR: $GEOSERVER_DATA_DIR"
echo "  - DATABASE_HOST: $DATABASE_HOST"
echo "  - DATABASE_PORT: $DATABASE_PORT"
echo "  - DATABASE_NAME: $DATABASE_NAME"
echo "  - WORKSPACE: $WORKSPACE"
echo "  - DATASTORE: $DATASTORE"

# --- 1️⃣ Configure CORS (inspired by GeoNode approach) ---
echo "🌐 Configuring CORS settings..."
if [ "${GEOSERVER_CORS_ENABLED}" = "true" ] || [ "${GEOSERVER_CORS_ENABLED}" = "True" ]; then
    if ! grep -q DockerGeoServerCorsFilter "$CATALINA_HOME/webapps/geoserver/WEB-INF/web.xml"; then
        echo "✅ Enabling CORS for $CATALINA_HOME/webapps/geoserver/WEB-INF/web.xml"
        sed -i "\:</web-app>:i\\
    <filter>\n\
      <filter-name>DockerGeoServerCorsFilter</filter-name>\n\
      <filter-class>org.apache.catalina.filters.CorsFilter</filter-class>\n\
      <init-param>\n\
          <param-name>cors.allowed.origins</param-name>\n\
          <param-value>${GEOSERVER_CORS_ALLOWED_ORIGINS}</param-value>\n\
      </init-param>\n\
      <init-param>\n\
          <param-name>cors.allowed.methods</param-name>\n\
          <param-value>${GEOSERVER_CORS_ALLOWED_METHODS}</param-value>\n\
      </init-param>\n\
      <init-param>\n\
        <param-name>cors.allowed.headers</param-name>\n\
        <param-value>${GEOSERVER_CORS_ALLOWED_HEADERS}</param-value>\n\
      </init-param>\n\
      <init-param>\n\
        <param-name>cors.allowCredentials</param-name>\n\
        <param-value>true</param-value>\n\
      </init-param>\n\
      <init-param>\n\
        <param-name>cors.preflightMaxAge</param-name>\n\
        <param-value>86400</param-value>\n\
      </init-param>\n\
    </filter>\n\
    <filter-mapping>\n\
      <filter-name>DockerGeoServerCorsFilter</filter-name>\n\
      <url-pattern>/*</url-pattern>\n\
    </filter-mapping>" "$CATALINA_HOME/webapps/geoserver/WEB-INF/web.xml"
    else
        echo "✅ CORS already configured"
    fi
else
    echo "🚫 CORS disabled"
fi

# --- 2️⃣ Wait for GeoServer to be ready ---
MAX_RETRIES=30
RETRY_DELAY=5
GEOSERVER_URL="http://127.0.0.1:8080/geoserver"
GEOSERVER_REST="$GEOSERVER_URL/rest"

echo "⏳ Waiting for GeoServer REST API to become available..."
for i in $(seq 1 $MAX_RETRIES); do
    if curl -sf -u "$GEOSERVER_USER:$GEOSERVER_PASS" "$GEOSERVER_REST/about/version.json" > /dev/null; then
        echo "✅ GeoServer is ready!"
        break
    fi
    echo "⏳ GeoServer not ready yet (attempt $i/$MAX_RETRIES)..."
    sleep $RETRY_DELAY
    if [ $i -eq $MAX_RETRIES ]; then
        echo "❌ GeoServer did not become ready after $((MAX_RETRIES * RETRY_DELAY)) seconds."
        exit 1
    fi
done

# --- 2️⃣ Helper for REST API calls ---
geoserver_rest() {
    local method=$1
    local endpoint=$2
    local data=$3
    local max_retries=3
    local retry_count=0

    while [ $retry_count -lt $max_retries ]; do
        local http_code
        http_code=$(curl -s -w "%{http_code}" -o /tmp/response.json \
            -u "$GEOSERVER_USER:$GEOSERVER_PASS" \
            -X "$method" \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            ${data:+-d "$data"} \
            "$GEOSERVER_REST/$endpoint" 2>/dev/null)
        
        if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
            echo "$http_code"
            return 0
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            echo "⚠️ HTTP $http_code, retrying in 2 seconds... (attempt $retry_count/$max_retries)"
            sleep 2
        fi
    done
    
    echo "❌ Failed after $max_retries attempts, HTTP code: $http_code"
    return 1
}

# --- 3️⃣ Create workspace (if not exists) ---
echo "📁 Checking for workspace '$WORKSPACE'..."
if ! curl -sf -u "$GEOSERVER_USER:$GEOSERVER_PASS" "$GEOSERVER_REST/workspaces/$WORKSPACE.json" > /dev/null 2>&1; then
    echo "📁 Creating workspace '$WORKSPACE'..."
    if STATUS=$(geoserver_rest POST "workspaces" "{\"workspace\": {\"name\": \"$WORKSPACE\"}}"); then
        if [ "$STATUS" = "201" ]; then
            echo "✅ Workspace '$WORKSPACE' created successfully."
        else
            echo "⚠️ Workspace creation returned HTTP $STATUS"
        fi
    else
        echo "❌ Failed to create workspace '$WORKSPACE'"
    fi
else
    echo "✅ Workspace '$WORKSPACE' already exists."
fi

# --- 4️⃣ Create datastore (if not exists) ---
echo "🗄️ Checking for datastore '$DATASTORE'..."
if ! curl -sf -u "$GEOSERVER_USER:$GEOSERVER_PASS" "$GEOSERVER_REST/workspaces/$WORKSPACE/datastores/$DATASTORE.json" > /dev/null 2>&1; then
    echo "🗄️ Creating datastore '$DATASTORE'..."
    if STATUS=$(geoserver_rest POST "workspaces/$WORKSPACE/datastores" "{
        \"dataStore\": {
            \"name\": \"$DATASTORE\",
            \"type\": \"PostGIS\",
            \"enabled\": true,
            \"connectionParameters\": {
                \"entry\": [
                    {\"@key\": \"host\", \"$\": \"$DATABASE_HOST\"},
                    {\"@key\": \"port\", \"$\": \"$DATABASE_PORT\"},
                    {\"@key\": \"database\", \"$\": \"$DATABASE_NAME\"},
                    {\"@key\": \"schema\", \"$\": \"$DATABASE_SCHEMA\"},
                    {\"@key\": \"user\", \"$\": \"$DATABASE_USER\"},
                    {\"@key\": \"passwd\", \"$\": \"$DATABASE_PASSWORD\"},
                    {\"@key\": \"dbtype\", \"$\": \"postgis\"},
                    {\"@key\": \"Expose primary keys\", \"$\": \"true\"}
                ]
            }
        }
    }"); then
        if [ "$STATUS" = "201" ]; then
            echo "✅ Datastore '$DATASTORE' created successfully."
        else
            echo "⚠️ Datastore creation returned HTTP $STATUS"
        fi
    else
        echo "❌ Failed to create datastore '$DATASTORE'"
    fi
else
    echo "✅ Datastore '$DATASTORE' already exists."
fi

# --- 5️⃣ Configure global settings (safe PUT) ---
echo "⚙️ Updating global settings..."
if STATUS=$(geoserver_rest PUT "settings" '{
    "global": {
        "settings": {
            "contact": {
                "addressCity": "Jakarta",
                "addressCountry": "Indonesia",
                "contactEmail": "admin@gis-carbon-ai.com",
                "contactOrganization": "GIS Carbon AI",
                "contactPerson": "Administrator",
                "contactPosition": "System Administrator"
            },
            "charset": "UTF-8",
            "cors": {
                "allowCredentials": true,
                "allowHeaders": "*",
                "allowMethods": "GET,POST,PUT,DELETE,HEAD,OPTIONS",
                "allowOrigins": "*",
                "enabled": true
            },
            "globalServices": true,
            "numDecimals": 4,
            "onlineResource": "http://geoserver.org",
            "proxyBaseUrl": "http://localhost:8080/geoserver",
            "schemaBaseUrl": "http://schemas.opengis.net",
            "verbose": false,
            "verboseExceptions": false
            }
        }
    }'); then
    if [ "$STATUS" = "200" ]; then
        echo "✅ Global settings updated successfully."
    else
        echo "⚠️ Global settings update returned HTTP $STATUS"
    fi
else
    echo "❌ Failed to update global settings"
fi

# --- 6️⃣ Configure GeoFence (if available) ---
echo "🔒 Checking for GeoFence extension..."
echo "🔍 Debug: GEOSERVER_USER=$GEOSERVER_USER, GEOSERVER_REST=$GEOSERVER_REST"
# Wait for GeoFence to be fully loaded
MAX_GEOFENCE_RETRIES=10
GEOFENCE_RETRY_DELAY=5
for i in $(seq 1 $MAX_GEOFENCE_RETRIES); do
    echo "🔍 Debug: Testing GeoFence endpoint: $GEOSERVER_REST/geofence/info"
    if curl -sf -u "$GEOSERVER_USER:$GEOSERVER_PASS" "$GEOSERVER_REST/geofence/info" > /dev/null 2>&1; then
        echo "🔒 GeoFence extension detected after $i attempts"
        break
    fi
    if [ $i -eq $MAX_GEOFENCE_RETRIES ]; then
        echo "ℹ️ GeoFence extension not available or not yet loaded after $MAX_GEOFENCE_RETRIES attempts"
        exit 0
    fi
    echo "⏳ GeoFence not ready yet (attempt $i/$MAX_GEOFENCE_RETRIES)..."
    sleep $GEOFENCE_RETRY_DELAY
done

if curl -sf -u "$GEOSERVER_USER:$GEOSERVER_PASS" "$GEOSERVER_REST/geofence/info" > /dev/null 2>&1; then
    echo "🔒 GeoFence extension detected and working!"
    
    # Process GeoFence datasource configuration template
    echo "🔒 Configuring GeoFence datasource from template..."
    if [ -f "/templates/geofence/geofence-datasource-ovr.properties.j2" ]; then
        # Create GeoFence configuration directory if it doesn't exist
        mkdir -p "$GEOSERVER_DATA_DIR/geofence"
        
        # Process the template with current environment variables
        cat > "$GEOSERVER_DATA_DIR/geofence/geofence-datasource-ovr.properties" << EOF
geofenceVendorAdapter.databasePlatform=org.hibernate.spatial.dialect.postgis.PostgisDialect
geofenceDataSource.driverClassName=org.postgresql.Driver
geofenceDataSource.url=jdbc:postgresql://$DATABASE_HOST:$DATABASE_PORT/$DATABASE_NAME
geofenceDataSource.username=$DATABASE_USER
geofenceDataSource.password=$DATABASE_PASSWORD
geofenceEntityManagerFactory.jpaPropertyMap[hibernate.default_schema]=$DATABASE_SCHEMA

# avoid hibernate transaction issues
geofenceDataSource.testOnBorrow=true
geofenceDataSource.validationQuery=SELECT 1
geofenceEntityManagerFactory.jpaPropertyMap[hibernate.testOnBorrow]=true
geofenceEntityManagerFactory.jpaPropertyMap[hibernate.validationQuery]=SELECT 1

geofenceDataSource.removeAbandoned=true
geofenceDataSource.removeAbandonedTimeout=60
geofenceDataSource.connectionProperties=ApplicationName=GeoFence;
EOF
        echo "✅ GeoFence datasource configuration created"
    else
        echo "⚠️ GeoFence template not found"
    fi
    
    # Check GeoFence status
    GEOFENCE_INFO=$(curl -s -u "$GEOSERVER_USER:$GEOSERVER_PASS" "$GEOSERVER_REST/geofence/info")
    echo "🔒 GeoFence instance: $GEOFENCE_INFO"
    
    # Check GeoFence rules count
    RULES_COUNT=$(curl -s -u "$GEOSERVER_USER:$GEOSERVER_PASS" "$GEOSERVER_REST/geofence/rules/count")
    echo "🔒 GeoFence rules count: $RULES_COUNT"
    
    echo "✅ GeoFence is ready for use!"
else
    echo "ℹ️ GeoFence extension not available or not yet loaded"
fi

echo "🎉 Post-startup configuration completed successfully!"
