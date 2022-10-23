# Ski Pistes

This config is used to extract ski pistes, aerialwas etc. from an [OSM](https://www.openstreetmap.org) file and to convert it to an `mbtiles` file.

# Filter objects

First you have to extract just the relevant objects in order to limit the file size to be processed by `tilemaker`:

```
osmfilter planet-latest.o5m --parameter-file=filter | osmconvert - -o=pistes-planet.osm.pbf
```

# Create mbtiles

Now the `mbtiles` file can be created using `tilemaker`:

```
tilemaker --input planet-pistes.osm.pbf --output planet-pistes.mbtiles
```
