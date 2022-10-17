# OSM Routes

This config is used to extract ski pistes from an [OSM](https://www.openstreetmap.org) file and to convert it to an `mbtiles` file.

# Prerequisites

To follow this workflow you need the following tools:

* [tilemaker](https://tilemaker.org) >= 2.1

# Create mbtiles

Now the `mbtiles` file can be created using `tilemaker`:

```
tilemaker --input germany-routes.osm.pbf --output germany-routes.mbtiles
```
