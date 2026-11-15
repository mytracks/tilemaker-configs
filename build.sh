#!/bin/bash

#docker build -t mytracks/tilemaker .

podman build --ulimit nofile=65536:65536 -t mytracks/tilemaker .

# Test
# podman run -v /data:/data --userns=keep-id --rm -ti localhost/mytracks/tilemaker:latest bash

# In Container: convert OSM to MBTiles
# java -jar /opt/planetiler.jar --osm-path=/data/sources/austria-latest.osm.pbf --mbtiles=/data/mbtiles/austria.mbtiles
# java -jar /opt/planetiler.jar --osm-path=/data/sources/planet.osm.pbf --mbtiles=/data/mbtiles/planet-openmaptiles-spike.mbtiles

# Tag and push to docker.io
# podman tag localhost/mytracks/tilemaker:latest docker.io/mytracks/tilemaker:2026-11-07
# podman push docker.io/mytracks/tilemaker:2026-11-07
