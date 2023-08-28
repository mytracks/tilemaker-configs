# Ski Pistes

This config is used to extract ski pistes, aerialwas etc. from an [OSM](https://www.openstreetmap.org) file and to convert it to an `mbtiles` file.

# Filter objects

First you have to extract just the relevant objects in order to limit the file size to be processed by `tilemaker`:

```
osmfilter planet.o5m --parameter-file=filter | osmconvert - -o=planet-pistes.osm.pbf
```

Or using the provided container image:

```sh
docker run --rm -v /data/sources:/data/sources -v config:/config -w /config mytracks/tilemaker sh -c "osmfilter /data/sources/planet.o5m --parameter-file=filter | osmconvert - -o=/data/sources/planet-pistes.osm.pbf"
```

# Create mbtiles

Now the `mbtiles` file can be created using `tilemaker`:

```
tilemaker --input planet-pistes.osm.pbf --output planet-pistes.mbtiles
```

Or using the provided container image:

```sh
docker run --rm -v /data/sources:/data/sources -v /data/mbtiles:/data/mbtiles tilemaker --input /data/sources/planet-pistes.osm.pbf --output /data/mbtiles/planet-pistes.mbtiles
```
