# Tilemaker Configs

This repository contains configurations to generate OSM `mbtiles` using `tilemaker`.

The configuration in the [routes](./routes/) folder extracts all kinds of _routes_, such as _buses_, _trams_ and _bicycle routes_, from an OSM extracts and makes it available as `mbtiles` file.

The [pistes](./pistes/) folder contains a configuration for ski pistes.

## Prerequisites

* [osmconvert](https://wiki.openstreetmap.org/wiki/Osmconvert)
* [osmfilter](https://wiki.openstreetmap.org/wiki/Osmfilter)
* [tilemaker](https://tilemaker.org) >= 2.1

## Preparation

To process a complete planet file on a machine with not too much memory the full plant file has to be filtered first using `osmfilter`. Therefore the file has to be provided as `o5m` file. To convert an `osm.pbf` to an `o5m` file you can use `osmconvert`:

```sh
osmconvert planet.osm.pbf -o=planet.o5m
```

Or using the provided container image:
```sh
docker run -v /data/sources:/data/sources mytracks/tilemaker osmconvert /data/sources/planet.osm.pbf -o=/data/sources/planet.o5m
```

## OpenMapTiles with Planetiler

`planetiler-openmaptiles/` holds layers of the OpenMapTiles profile that replace Planetiler's own
when the container image is built (see the `Dockerfile`). `Transportation.java` is adapted for
route planning on foot and by bicycle in the myTracks app, which reads the `transportation` layer
at zoom 14:

* **No simplification at zoom 14.** Simplifying the merged lines dropped a junction's vertex from
  a way running straight through it, so that the ways meeting there no longer shared a point.
  Bridges and tunnels still share no point with the ways they cross, as in OSM.
* **More tags at zoom 14:** `sac_scale`, `trail_visibility`, `tracktype`, `smoothness`,
  `oneway_bicycle` (from `oneway:bicycle`) and `incline`.
