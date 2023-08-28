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
