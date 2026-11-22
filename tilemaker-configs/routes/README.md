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

It extracts all objects that contain at least one of the following route types: bicycle, hiking, foot, mtb, tram, subway, bus

## Which relations become routes

* **Cycle routes** (`route=bicycle`) need a network level, `network` = `icn`, `ncn`, `rcn` or
  `lcn` (or the walking network's `iwn` … `lwn`), with or without a `ref`. A relation without a level,
  such as a basic cycle network's, is left out. These are the cycle routes that the myTracks app
  prefers when it plans routes from the OpenMapTiles build (`route_bicycle` in its
  `transportation` layer, see the main README), so that the map shows the same ones. A way on such a
  route gets `bicycle_route=yes` and `bicycle_route_level`, the highest level among its cycle
  routes: `local`, `regional`, `national` or `international`.
* **Hiking routes** (`route=hiking` and `route=foot`) and **MTB routes** (`route=mtb`) follow the
  same rule and give `hiking_route` / `mtb_route` = `yes` and `hiking_route_level` /
  `mtb_route_level`. They get none of the attributes per `ref` and none of the aggregated ones
  (`<kind>_name`, `<kind>_ref` ...), which only the legacy app reads for the kinds it knows.
* **All other routes** need a `ref`.

Stop signs (nodes with `highway=stop` and no `railway`) are left out of the points: their class
`stop` would be drawn as a tram or railway stop (`railway=stop`).

## Which routes a way belongs to

For `bicycle`, `hiking`, `mtb`, `bus`, `tram` and `subway`, a way has an attribute `<kind>_lines`,
which the myTracks app reads to show and select a single route. It holds one record per relation,
by ascending id, with a line break before each record and one after the last. The fields of a
record are separated by tabs:

`id`, `key`, `ref`, `name`, `operator`, `network`

* `id` is the relation's id.
* `key` is `#<ref>|<operator>|<network>` for a public transport line with an operator or a network:
  all directions and variants of the line share it. It is empty otherwise.
* Tabs and line breaks inside values are spaces.

So `<kind>_lines` contains a line break, the id and a tab exactly when the way belongs to that
relation, and a tab, the key and a tab when it belongs to that line.

## After changing this config

`scripts/update_tiles.sh` compares only the dates of the data. After a change to `filter` or
`process.lua`, delete `/data/sources/planet-routes.osm.pbf` before running it, or the set is built
with the change only once a newer planet arrives.

# Create mbtiles

Now the `mbtiles` file can be created using `tilemaker`:

```
tilemaker --input planet-routes.osm.pbf --output planet-routes.mbtiles
```

Or using the provided container image:

```sh
docker run --rm -v /data/sources:/data/sources -v config:/config -w /config -v /data/mbtiles:/data/mbtiles mytracks/tilemaker tilemaker --input /data/sources/planet-routes.osm.pbf --output /data/mbtiles/planet-routes.mbtiles
```

