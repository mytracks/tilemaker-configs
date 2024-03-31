#!/bin/bash

if [ -e /data/mbtiles/openmaptiles-new.mbtiles ]; then
    if [ -e /data/mbtiles/openmaptiles-old.mbtiles ]; then
        rm /data/mbtiles/openmaptiles-old.mbtiles
    fi
    if [ -e /data/mbtiles/openmaptiles.mbtiles ]; then
        mv /data/mbtiles/openmaptiles.mbtiles /data/mbtiles/openmaptiles-old.mbtiles
    fi
    mv /data/mbtiles/openmaptiles-new.mbtiles /data/mbtiles/openmaptiles.mbtiles
    echo "New openmaptiles.mbtiles activated."
fi

if [ -e /data/mbtiles/planet-routes-new.mbtiles ]; then
    if [ -e /data/mbtiles/planet-routes-old.mbtiles ]; then
        rm /data/mbtiles/planet-routes-old.mbtiles
    fi
    if [ -e /data/mbtiles/routes.mbtiles ]; then
        mv /data/mbtiles/routes.mbtiles /data/mbtiles/planet-routes-old.mbtiles
    fi
    mv /data/mbtiles/planet-routes-new.mbtiles /data/mbtiles/routes.mbtiles
    echo "New routes.mbtiles activated."
fi

if [ -e /data/mbtiles/planet-pistes-new.mbtiles ]; then
    if [ -e /data/mbtiles/planet-pistes-old.mbtiles ]; then
        rm /data/mbtiles/planet-pistes-old.mbtiles
    fi
    if [ -e /data/mbtiles/planet_pistes.mbtiles ]; then
        mv /data/mbtiles/planet_pistes.mbtiles /data/mbtiles/planet-pistes-old.mbtiles
    fi
    mv /data/mbtiles/planet-pistes-new.mbtiles /data/mbtiles/planet_pistes.mbtiles
    echo "New planet_pistes.mbtiles activated."
fi
