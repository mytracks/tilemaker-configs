# Examples

```sh
tilemaker --input /data/tmp/planet/planet-latest.osm.pbf --output omt-planet.mbtiles --store cache
```

```sh
osmium renumber -o planet-renumbered.osm.pbf /data/tmp/planet/planet-latest.osm.pbf
tilemaker --input planet-renumbered.osm.pbf --output omt-planet.mbtiles --store cache --compact
```

