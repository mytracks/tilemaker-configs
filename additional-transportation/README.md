# OSM Routes

This config is used to extract additional transportation layers from an [OSM](https://www.openstreetmap.org) file and to convert it to a `mbtiles` file.

# Prerequisites

To follow this workflow you need the following tools:

* [osmconvert](https://wiki.openstreetmap.org/wiki/Osmconvert)
* [osmfilter](https://wiki.openstreetmap.org/wiki/Osmfilter)
* [tilemaker](https://tilemaker.org) >= 2.1

# Convert to o5m

If you start with a `.osm.pbf` file such as the `austria-latest.osm.pbf` you first have to convert it to an `o5m` file like this:

```
osmconvert austria-latest.osm.pbf -o=austria-latest.o5m
```

# Filter routes

Next you have to extract just the `route` objects in order to limit the file size to be processed by `tilemaker`:

```
osmfilter austria-latest.o5m --parameter-file=transportation_filter | osmconvert - -o=austria-additional-transportation.osm.pbf
```

It extracts all transportation features that are track, path or minor.

# Create mbtiles

Now the `mbtiles` file can be created using `tilemaker`:

```
tilemaker --input austria-additional-transportation.osm.pbf --output austria-additional-transportation.mbtiles
```
