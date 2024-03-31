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

    # Check if older than 2 days
    if [[ $diffDays -gt 2 ]]; then
        echo "/data/sources/planet.osm.pbf too old. Loading latest version."
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

# create openmaptiles-new.mbtiles
if [ /data/mbtiles/openmaptiles.mbtiles -ot /data/sources/planet.osm.pbf ]; then
    echo "Generating /data/mbtiles/openmaptiles-new.mbtiles"
    rm -f /data/mbtiles/openmaptiles-new.mbtiles
    sh -c "cd / && java -jar /opt/planetiler.jar --osm-path=/data/sources/planet.osm.pbf --mbtiles=/data/mbtiles/openmaptiles-new.mbtiles"
else
    echo "/data/mbtiles/openmaptiles.mbtiles is up-to-date"
fi

# create planet.o5m
if [ /data/sources/planet.o5m -ot /data/sources/planet.osm.pbf ]; then
    echo "Generating /data/sources/planet.o5m"
    rm -f /data/sources/planet.o5m
    osmconvert /data/sources/planet.osm.pbf -o=/data/sources/planet.o5m
else
    echo "/data/mbtiles/planet.o5m is up-to-date"
fi

tilemaker () {
    type=$1

    # create planet-$type.osm.pbf
    if [ /data/sources/planet-$type.osm.pbf -ot /data/sources/planet.o5m ]; then
        echo "Generating /data/sources/planet-$type.osm.pbf"
        rm -f /data/sources/planet-$type.osm.pbf
        sh -c "cd /tilemaker-configs/$type/config && osmfilter /data/sources/planet.o5m --parameter-file=filter | osmconvert - -o=/data/sources/planet-$type.osm.pbf"
    else
        echo "/data/sources/planet-$type.osm.pbf is up-to-date"
    fi

    # create planet-$type-new.mbtiles
    if [ /data/mbtiles/planet-$type.mbtiles -ot /data/sources/planet-$type.osm.pbf ]; then
        echo "Generating /data/mbtiles/planet-$type-new.mbtiles"
        sh -c "cd /tilemaker-configs/$type/config && tilemaker --input /data/sources/planet-$type.osm.pbf --output /data/mbtiles/planet-$type-new.mbtiles"
    else
        echo "/data/mbtiles/planet-$type.mbtiles is up-to-date"
    fi
}

tilemaker "pistes"
tilemaker "routes"

activate () {
    type=$1

    if [ -e /data/mbtiles/planet-$type-new.mbtiles ]; then
        # Delete old one if exists
        if [ -e /data/mbtiles/planet-$type-old.mbtiles ]; then
            rm /data/mbtiles/planet-$type-old.mbtiles
        fi
        # Make the currently active the old one
        if [ -e /data/mbtiles/planet-$type.mbtiles ]; then
            mv /data/mbtiles/planet-$type.mbtiles /data/mbtiles/planet-$type-old.mbtiles
        fi
        # Make the new the active one
        mv /data/mbtiles/planet-$type-new.mbtiles /data/mbtiles/planet-$type.mbtiles
        echo "New planet-$type.mbtiles activated."
    fi
}

# Activate new files
activate "openmaptiles"
activate "routes"
activate "pistes"

# Restarting tileserver-gl
kubectl rollout restart deployment tileserver-gl

echo "Ready."
exit 0
