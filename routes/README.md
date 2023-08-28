# OSM Routes

This config is used to extract all kinds of routes from an [OSM](https://www.openstreetmap.org) file and to convert it to an `mbtiles` file.

# Filter objects

First you have to extract just the `route` objects in order to limit the file size to be processed by `tilemaker`:

```
osmfilter planet.o5m --parameter-file=filter | osmconvert - -o=planet-routes.osm.pbf
```

Or using the provided container image:

```sh
docker run --rm -v /data/sources:/data/sources -v config:/config -w /config mytracks/tilemaker osmfilter /data/sources/planet.o5m --parameter-file=filter | osmconvert - -o=/data/sources/planet-routes.osm.pbf
```

It extracts all objects that contain at least one of the following route types: bicycle, tram, train, subway, monorail, tram, bus, trolleybus, ferry

# Create mbtiles

Now the `mbtiles` file can be created using `tilemaker`:

```
tilemaker --input planet-routes.osm.pbf --output planet-routes.mbtiles
```

Or using the provided container image:

```sh
docker run --rm -v /data/sources:/data/sources -v /data/mbtiles:/data/mbtiles tilemaker --input /data/sources/planet-routes.osm.pbf --output /data/mbtiles/planet-routes.mbtiles
```

