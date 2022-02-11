# OSM Routes

This config is used to extract all kinds of routes from an [OSM](https://www.openstreetmap.org) file and to convert it to a `mbtiles` file.

# Prerequisites

The follow this workflow you need the following tools:

* [osmconvert](https://wiki.openstreetmap.org/wiki/Osmconvert)
* [osmfilter](https://wiki.openstreetmap.org/wiki/Osmfilter)
* [tilemaker](https://tilemaker.org)

# Convert to o5m

If you start with a `.osm.pbf` file such as the `germany-latest.osm.pbf` you first have to convert it to an `o5m` file like this:

```
osmconvert germany-latest.osm.pbf -o=germany-latest.o5m
```

# Filter routes

Next you have to extract just the `route` objects in order limit the file size to be processed by `tilemaker`:

```
osmfilter germany-latest.o5m --parameter-file=route_filter | osmconvert - -o=routes-germany.osm.pbf
```

It extracts all objects that contain at least one of the following route types: bicycle, tram, train, subway, monorail, tram, bus, trolleybus, ferry

# Create mbtiles

Now the `mbtiles` file can be created using `tilemaker`:

```
tilemaker --input germany-routes.osm.pbf --output germany-routes.mbtiles
```
