#!/bin/bash
set -e

echo "🚀 Starting GeoServer (2.28) with custom entrypoint..."

# Ensure GeoServer WAR is properly deployed
if [ -f /usr/local/tomcat/webapps/geoserver.war.bak ]; then
    echo "📦 Deploying GeoServer WAR file..."
    cp /usr/local/tomcat/webapps/geoserver.war.bak /usr/local/tomcat/webapps/geoserver.war
fi

# Set GeoServer data directory if not already set
export GEOSERVER_DATA_DIR=${GEOSERVER_DATA_DIR:-"/geoserver_data/data"}

# Ensure data directory exists and has proper permissions
if [ ! -d "$GEOSERVER_DATA_DIR" ]; then
    echo "❌ GeoServer data directory not found: $GEOSERVER_DATA_DIR"
    exit 1
fi

# Create symbolic link for GeoServer data directory if needed
if [ ! -d "/geoserver_data" ]; then
    mkdir -p /geoserver_data
fi

# Run additional setup scripts - POST-STARTUP ENABLED, SSO DISABLED
run_post_startup() {
    local post_script="/scripts/post-startup.sh"
    local sso_script="/scripts/setup-sso.sh"

    # Run post-startup if exists
    if [ -f "$post_script" ]; then
        echo "⚙️ Running post-startup.sh..."
        (
            bash "$post_script" >> /var/log/post-startup.log 2>&1 && \
            echo "✅ post-startup.sh completed" || \
            echo "⚠️ post-startup.sh failed (see /var/log/post-startup.log)"
        ) &
    fi

    # SSO setup disabled for now
    echo "🚫 SSO setup script disabled for testing"
    # if [ -f "$sso_script" ]; then
    #     echo "🔐 Running setup-sso.sh..."
    #     (
    #         sleep 10
    #         bash "$sso_script" >> /var/log/setup-sso.log 2>&1 && \
    #         echo "✅ setup-sso.sh completed" || \
    #         echo "⚠️ setup-sso.sh failed (see /var/log/setup-sso.log)"
    #     ) &
    # fi
}

# Configure CORS (inspired by https://github.com/oscarfonts/docker-geoserver)
# if enabled, this will add the filter definitions
# to the end of the web.xml
# (this will only happen if our filter has not yet been added before)
if [ "${GEOSERVER_CORS_ENABLED}" = "true" ] || [ "${GEOSERVER_CORS_ENABLED}" = "True" ]; then
  if ! grep -q DockerGeoServerCorsFilter "/usr/local/tomcat/webapps/geoserver/WEB-INF/web.xml"; then
    echo "Enable CORS for /usr/local/tomcat/webapps/geoserver/WEB-INF/web.xml"
    echo "CORS Configuration:"
    echo "  - Origins: ${GEOSERVER_CORS_ALLOWED_ORIGINS:-*}"
    echo "  - Methods: ${GEOSERVER_CORS_ALLOWED_METHODS:-GET,POST,PUT,DELETE,HEAD,OPTIONS}"
    echo "  - Headers: ${GEOSERVER_CORS_ALLOWED_HEADERS:-*}"
    echo "  - Exposed Headers: ${GEOSERVER_CORS_EXPOSED_HEADERS:-Access-Control-Allow-Origin,Access-Control-Allow-Credentials}"
    echo "  - Support Credentials: ${GEOSERVER_CORS_SUPPORT_CREDENTIALS:-false}"
    echo "  - Preflight Max Age: ${GEOSERVER_CORS_PREFLIGHT_MAXAGE:-10}"
    
    sed -i "\:</web-app>:i\\
    <filter>\n\
      <filter-name>DockerGeoServerCorsFilter</filter-name>\n\
      <filter-class>org.apache.catalina.filters.CorsFilter</filter-class>\n\
      <init-param>\n\
          <param-name>cors.allowed.origins</param-name>\n\
          <param-value>${GEOSERVER_CORS_ALLOWED_ORIGINS:-*}</param-value>\n\
      </init-param>\n\
      <init-param>\n\
          <param-name>cors.allowed.methods</param-name>\n\
          <param-value>${GEOSERVER_CORS_ALLOWED_METHODS:-GET,POST,PUT,DELETE,HEAD,OPTIONS}</param-value>\n\
      </init-param>\n\
      <init-param>\n\
        <param-name>cors.allowed.headers</param-name>\n\
        <param-value>${GEOSERVER_CORS_ALLOWED_HEADERS:-*}</param-value>\n\
      </init-param>\n\
      <init-param>\n\
        <param-name>cors.exposed.headers</param-name>\n\
        <param-value>${GEOSERVER_CORS_EXPOSED_HEADERS:-Access-Control-Allow-Origin,Access-Control-Allow-Credentials}</param-value>\n\
      </init-param>\n\
      <init-param>\n\
        <param-name>cors.support.credentials</param-name>\n\
        <param-value>${GEOSERVER_CORS_SUPPORT_CREDENTIALS:-false}</param-value>\n\
      </init-param>\n\
      <init-param>\n\
        <param-name>cors.preflight.maxage</param-name>\n\
        <param-value>${GEOSERVER_CORS_PREFLIGHT_MAXAGE:-10}</param-value>\n\
      </init-param>\n\
    </filter>\n\
    <filter-mapping>\n\
      <filter-name>DockerGeoServerCorsFilter</filter-name>\n\
      <url-pattern>/*</url-pattern>\n\
    </filter-mapping>" "/usr/local/tomcat/webapps/geoserver/WEB-INF/web.xml";
  fi
fi

# Start Tomcat (GeoServer) in background
catalina.sh run &
TOMCAT_PID=$!

# Wait until GeoServer is responding
echo "⏳ Waiting for GeoServer to start on port 8080..."
MAX_RETRIES=60
RETRY_COUNT=0

until curl -s http://127.0.0.1:8080/geoserver/ > /dev/null; do
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo "❌ GeoServer failed to start after $MAX_RETRIES attempts"
    echo "🔍 Checking if Tomcat is running..."
    if ps aux | grep -q "catalina.sh run"; then
      echo "✅ Tomcat is running, but GeoServer might have deployment issues"
    else
      echo "❌ Tomcat is not running"
    fi
    exit 1
  fi
  sleep 5
  echo "🕓 GeoServer not ready yet... (attempt $RETRY_COUNT/$MAX_RETRIES)"
done
echo "✅ GeoServer is up!"

# Run post-startup scripts after GeoServer is ready
run_post_startup

# Keep Tomcat (GeoServer) running in foreground
wait $TOMCAT_PID
