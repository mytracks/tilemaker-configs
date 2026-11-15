# OSM Routes

This config is used to extract all kinds of routes from an [OSM](https://www.openstreetmap.org) file and to convert it to an `mbtiles` file.

# Filter objects

First you have to extract just the `route` objects in order to limit the file size to be processed by `tilemaker`:

```
cd config
osmfilter planet.o5m --parameter-file=filter | osmconvert - -o=planet-routes.osm.pbf
```

Or using the provided container image:

```sh
docker run --rm -v /data/sources:/data/sources -v config:/config -w /config mytracks/tilemaker sh -c "osmfilter /data/sources/planet.o5m --parameter-file=filter | osmconvert - -o=/data/sources/planet-routes.osm.pbf"
```

It extracts all objects that contain at least one of the following route types: bicycle, tram, train, subway, monorail, tram, bus, trolleybus, ferry

## Which relations become routes

* **Cycle routes** (`route=bicycle`) need a network level, `network` = `icn`, `ncn`, `rcn` or
  `lcn` (or the walking network's `iwn` … `lwn`), with or without a `ref`. A relation without a level,
  such as a basic cycle network's, is left out. These are the cycle routes that the myTracks app
  prefers when it plans routes from the OpenMapTiles build (`route_bicycle` in its
  `transportation` layer, see the main README), so that the map shows the same ones. A way on such a
  route gets `bicycle_route=yes` and `bicycle_route_level`, the highest level among its cycle
  routes: `local`, `regional`, `national` or `international`.
* **All other routes** need a `ref`.

# Create mbtiles

Now the `mbtiles` file can be created using `tilemaker`:

```
tilemaker --input planet-routes.osm.pbf --output planet-routes.mbtiles
```

Or using the provided container image:

```sh
docker run --rm -v /data/sources:/data/sources -v config:/config -w /config -v /data/mbtiles:/data/mbtiles mytracks/tilemaker tilemaker --input /data/sources/planet-routes.osm.pbf --output /data/mbtiles/planet-routes.mbtiles
```

