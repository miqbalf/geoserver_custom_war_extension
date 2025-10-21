# Enhanced GeoServer Dockerfile based on GeoNode implementation
# Custom GeoServer build with CORS support and environment configuration

ARG IMAGE_VERSION=9-jdk17-temurin
ARG JAVA_HOME=/usr/local/openjdk-17
FROM tomcat:${IMAGE_VERSION}

# Metadata
LABEL maintainer="muh.firdausiqbal@gmail.com"
LABEL description="Custom GeoServer 2.28 base image with CORS and environment configuration"

# GeoServer version and environment
ARG GEOSERVER_VERSION=2.28.0
ARG GEOSERVER_CORS_ENABLED=true
ARG GEOSERVER_CORS_ALLOWED_ORIGINS=*
ARG GEOSERVER_CORS_ALLOWED_METHODS=GET,POST,PUT,DELETE,HEAD,OPTIONS
ARG GEOSERVER_CORS_ALLOWED_HEADERS=*

# Set GeoServer environment variables
ENV GEOSERVER_VERSION=${GEOSERVER_VERSION}
ENV GEOSERVER_DATA_DIR="/geoserver_data/data"
ENV GEOSERVER_CORS_ENABLED=$GEOSERVER_CORS_ENABLED
ENV GEOSERVER_CORS_ALLOWED_ORIGINS=$GEOSERVER_CORS_ALLOWED_ORIGINS
ENV GEOSERVER_CORS_ALLOWED_METHODS=$GEOSERVER_CORS_ALLOWED_METHODS
ENV GEOSERVER_CORS_ALLOWED_HEADERS=$GEOSERVER_CORS_ALLOWED_HEADERS

#
# Download and install GeoServer
#
RUN apt-get update -y && apt-get install -y \
    curl \
    wget \
    unzip \
    procps \
    less \
    python3 \
    python3-pip \
    python3-dev \
    jq \
    && rm -rf /var/lib/apt/lists/*

RUN cd /usr/local/tomcat/webapps \
    && wget --no-check-certificate --progress=bar:force:noscroll \
    https://sourceforge.net/projects/geoserver/files/GeoServer/${GEOSERVER_VERSION}/geoserver-${GEOSERVER_VERSION}-war.zip \
    && unzip -q geoserver-${GEOSERVER_VERSION}-war.zip \
    && mv geoserver.war geoserver.war.bak \
    && mkdir -p geoserver \
    && cd geoserver && jar -xf ../geoserver.war.bak \
    && rm ../geoserver.war.bak ../geoserver-${GEOSERVER_VERSION}-war.zip \
    && mkdir -p $GEOSERVER_DATA_DIR

# Download and install GeoFence extensions
RUN cd /tmp \
    && wget --no-check-certificate --progress=bar:force:noscroll \
    https://sourceforge.net/projects/geoserver/files/GeoServer/${GEOSERVER_VERSION}/extensions/geoserver-${GEOSERVER_VERSION}-geofence-plugin.zip \
    && wget --no-check-certificate --progress=bar:force:noscroll \
    https://sourceforge.net/projects/geoserver/files/GeoServer/${GEOSERVER_VERSION}/extensions/geoserver-${GEOSERVER_VERSION}-geofence-server-postgres-plugin.zip \
    && unzip -o -q geoserver-${GEOSERVER_VERSION}-geofence-plugin.zip -d /usr/local/tomcat/webapps/geoserver/WEB-INF/lib/ \
    && unzip -o -q geoserver-${GEOSERVER_VERSION}-geofence-server-postgres-plugin.zip -d /usr/local/tomcat/webapps/geoserver/WEB-INF/lib/ \
    && rm geoserver-${GEOSERVER_VERSION}-geofence-plugin.zip geoserver-${GEOSERVER_VERSION}-geofence-server-postgres-plugin.zip



# Install Python dependencies for configuration management
RUN pip install --no-cache-dir --break-system-packages j2cli invoke==2.2.0 requests==2.31.0 pyyaml

# Create tmp directory for scripts
RUN mkdir -p /usr/local/tomcat/tmp
WORKDIR /usr/local/tomcat/tmp

# Copy scripts and templates
COPY ./scripts /scripts
COPY ./templates /templates
COPY ./entrypoint.sh /usr/local/tomcat/tmp/entrypoint.sh

# Set permissions
RUN chmod +x /scripts/*.sh /usr/local/tomcat/tmp/entrypoint.sh

# Create GeoServer data directory and set permissions
RUN mkdir -p $GEOSERVER_DATA_DIR && \
    chmod -R 755 $GEOSERVER_DATA_DIR && \
    mkdir -p $GEOSERVER_DATA_DIR/security && \
    mkdir -p $GEOSERVER_DATA_DIR/gwc && \
    mkdir -p $GEOSERVER_DATA_DIR/workspaces

# Create cache directory for extensions
RUN mkdir -p /tmp/geoserver-extensions-cache

# Expose port
EXPOSE 8080

# Java options for Java 17 (removed MaxPermSize and PermSize, updated GC)
ENV JAVA_OPTS="-Djava.awt.headless=true -Dgwc.context.suffix=gwc -XX:+UnlockDiagnosticVMOptions -XX:+LogVMOutput -XX:LogFile=/var/log/jvm.log -Xms512m -Xmx2048m -XX:+UseG1GC -Dfile.encoding=UTF8 -Djavax.servlet.request.encoding=UTF-8 -Djavax.servlet.response.encoding=UTF-8 -Duser.timezone=GMT -Dorg.geotools.shapefile.datetime=false -DGS-SHAPEFILE-CHARSET=UTF-8 -DGEOSERVER_CSRF_DISABLED=true -DPRINT_BASE_URL=http://geoserver:8080/geoserver/pdf"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=5 \
    CMD curl -f http://127.0.0.1:8080/geoserver/rest/about/version.json -u admin:admin || exit 1

# Use custom entrypoint script
CMD ["/usr/local/tomcat/tmp/entrypoint.sh"]