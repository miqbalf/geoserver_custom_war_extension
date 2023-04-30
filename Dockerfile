#Modified from Dockerfile Geonode Geoserver

ARG IMAGE_VERSION=9.0-jdk11-openjdk-slim-bullseye
ARG JAVA_HOME=/usr/local/openjdk-11
FROM tomcat:$IMAGE_VERSION

ENV GEOSERVER_VERSION=2.22.2
ENV GEOSERVER_DATA_DIR="/geoserver_data/data"

#
# Download and install GeoServer
#
RUN apt-get update -y && apt-get install curl wget unzip -y
RUN cd /usr/local/tomcat/webapps \
    && wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate 'https://docs.google.com/uc?export=download&id=1RTdvzMYtOKlWEiS52d9wWRMrYI2gdOxq' -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=1RTdvzMYtOKlWEiS52d9wWRMrYI2gdOxq" -O geoserver.war && rm -rf /tmp/cookies.txt \    #&& unzip -q geoserver.zip -d geoserver_zip \
    && unzip -q geoserver.war -d geoserver \
    && rm geoserver.war \
    #&& rm -rf geoserver_zip \
    && mkdir -p $GEOSERVER_DATA_DIR

VOLUME $GEOSERVER_DATA_DIR