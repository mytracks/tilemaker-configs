#!/bin/bash

# Exit on error
set -e

loadPlanetOsm=false

# Check if source folder exists
if [ ! -d /data/sources ]; then
  echo "Folder /data/sources does not exist. You have to mount /data into the container."
  exit -1
fi

# Check if tiles folder exists
if [ ! -d /data/mbtiles ]; then
  echo "Folder /data/mbtiles does not exist. You have to mount /data into the container."
  exit -1
fi

# Check date of existing /data/sources/planet.osm.pbf
if [ -e /data/sources/planet.osm.pbf ]; then
    echo "/data/sources/planet.osm.pbf exists. Checking date."

    planetDate=$(date +%s --reference /data/sources/planet.osm.pbf)
    now=$(date +%s)
    diffDays=$((($now - $planetDate) / 60 / 60 / 24))

    # Check if older than 7 days
    if [[ $diff -gt 7 ]]; then
        echo "/data/sources/planet.osm.pbf tool old. Loading latest version."
        loadPlanetOsm=true
    else
        echo "/data/sources/planet.osm.pbf is up-to-date."
    fi
else
    echo "/data/sources/planet.osm.pbf does not exist. Loading latest version."
    loadPlanetOsm=true
fi

if $loadPlanetOsm; then
    echo "Loading latest planet OSM file."
    rm -f /data/sources/planet.osm.pbf
    rm -f /data/sources/planet.o5m
    curl -L https://planet.openstreetmap.org/pbf/planet-latest.osm.pbf -o /data/sources/planet.osm.pbf
fi

if [ /data/mbtiles/openmaptiles-new.mbtiles -ot /data/sources/planet.osm.pbf ]; then
    echo "Generating /data/mbtiles/openmaptiles-new.mbtiles"
    rm -f /data/mbtiles/openmaptiles-new.mbtiles
    java -jar /opt/planetiler.jar --osm-path=/data/sources/planet.osm.pbf --mbtiles=/data/mbtiles/openmaptiles-new.mbtiles
else
    echo "/data/mbtiles/openmaptiles-new.mbtiles up-to-date"
fi

echo "Ready."
exit 0
