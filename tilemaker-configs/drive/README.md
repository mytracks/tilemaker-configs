# OSM Drive

This config builds the tile set `drive`: roads and buildings from [OSM](https://www.openstreetmap.org)
for the driving game osmDrive, which generates its 3D world from them. It adds to the
OpenMapTiles build, which the game keeps reading for ground cover and water; `drive` holds what a
map does not need and a driving game does: lanes and what they are for, widths, speed limits,
pavements, traffic signals and signs, passages through buildings, building parts and roofs.

The game's side of this contract is the specification `drive-tile-set` in the osmDrive
repository. A change of a layer or an attribute here needs a change there.

## What the tile set is

* **Zoom 14 only.** The game builds its world in pieces of one zoom-14 tile each.
* **A region:** one bounding box, in `config/region` as `west,south,east,north`. It is set to the
  whole world, `-180,-85.0511,180,85.0511` (Web Mercator ends at that latitude); a smaller box
  builds a part. (`bounding_box` in `config.json` says the same for a run of tilemaker by hand;
  the build script replaces it cell by cell.) The tile set's `bounds` are the tiles completely
  inside the box; the game takes roads and buildings from `drive` for every tile inside the
  bounds and from OpenMapTiles elsewhere.
* **Nothing is simplified or merged.** Every point of a way is in the tile, and ways that share a
  point in OSM share it in the tile. The game builds a road network from the lines.
* **The finest grid** tilemaker writes (`high_resolution`, 8192 units per tile, about 0.2 m in
  Central Europe), since a building's corner is seen from the road.
* **What is mapped, nothing derived.** An attribute is there when OSM gives it in a form that
  can be read, as a number in meters or km/h. No height from levels, no width from lanes. The
  game estimates what is missing, so a better estimate needs no new build.

## Build

`scripts/build_drive.sh <source.o5m> <output.mbtiles>` builds the tile set, and
`scripts/update_tiles.sh` runs it with the other tile sets from the planet:

1. The region is cut from the source with `osmconvert -b= --complete-ways
   --complete-multipolygons`. Without the two options a way that crosses the box loses nodes, and
   tilemaker stops at the first such way.
2. `osmfilter` keeps everything with a `highway`, `building`, `building:part` or
   `traffic_calming` tag (`config/filter`).
3. tilemaker builds the region **cell by cell** into one file (`--merge`). It holds all geometry
   of its input in memory, about 4 GB for Upper Bavaria alone (`--store` does not change that),
   so the region does not fit into one run. A cell is a square of 48 zoom-14 tiles, about one
   degree of longitude. tilemaker is told to write exactly the cell's tiles, because where two
   runs write the same tile, merging puts both contents into it instead of replacing it. The
   data of a cell reaches 0.05 degrees beyond it, so that every tile is complete.
4. The cells are reached by **cutting in quarters**: the region into four pieces, each piece into
   four again, until a piece is one cell. Every cut reads its whole input, so cutting each cell
   from the region would read the region once per cell, more than 100,000 times for the planet.
   In quarters, each level reads the data about once, and a piece without data (open sea) ends
   its whole branch. Temporary files need about twice the size of the filtered region.

Compared with cutting every cell from the region (around Munich, 20 cells of 8 tiles, 858 tiles,
2026-11-23): the same cells with input files of the same size, the same tiles and bounds, and in
every tile the same features; in 518 tiles they are written in a different order.

For the whole world the source is filtered without being cut first, which would only copy it.
This has not been run yet: the time and the size of the result are not known. The tiles so far
were built for Central Europe, `5.5,45.5,17.5,55.5`.

The tiles built are those that lie completely inside the region's box, and the file's `bounds` are
the box of these tiles: slightly smaller than `config/region`.

Compared with a single run over the same area (Munich, 64 tiles): the same tiles, 50 of them of
the same size to the byte, the others different by a few bytes in 100,000, where a line is cut at
a cell's edge instead of in the tile's buffer.

Measured on a Mac with tilemaker 2.4.0 under emulation (2026-11-23), for Geofabrik's extract of
Upper Bavaria (261 MB as `.osm.pbf`): 126 MB after the filter, 7084 tiles, 54 MB as `.mbtiles`,
the largest tile 138 kB compressed; filter 85 s, tilemaker 122 s, 4 GB of memory.

To build a small area for trying, with the tools of the container image:

```sh
DRIVE_CONFIG=tilemaker-configs/drive/config DRIVE_REGION=11.45,48.05,11.75,48.25 \
  scripts/build_drive.sh upper-bavaria.o5m munich-drive.mbtiles
```

The tile server needs an entry for the file under the name `drive`, so that it serves
`/data/drive.json` and `/data/drive/{z}/{x}/{y}.pbf`.

## Layer `road`

Lines. Every way a car can use:

| `highway`                                              | `class`     | `link` |
|--------------------------------------------------------|-------------|--------|
| `motorway`, `trunk`, `primary`, `secondary`, `tertiary` | the same    |        |
| `motorway_link` … `tertiary_link`                      | without `_link` | 1  |
| `unclassified`, `residential`, `living_street`, `road` | `minor`     |        |
| `service`                                              | `service`   |        |
| `track`                                                | `track`     |        |
| `busway`                                               | `busway`    |        |

Left out: every other `highway` (paths, footways, cycleways, steps, pedestrian zones, ways under
construction), ways with `area=yes`, and ways closed to motor vehicles: the first tag present of
`motorcar`, `motor_vehicle`, `vehicle`, `access` decides, and `no` closes the way. Private ways
are kept.

| Attribute    | Type   | Value                                                                 | From                         |
|--------------|--------|-----------------------------------------------------------------------|------------------------------|
| `class`      | String | see above; always there                                               | `highway`                    |
| `link`       | Number | 1 on a link road                                                      | `highway=*_link`             |
| `structure`  | String | `bridge`, `tunnel`, or `passage` for a way through or under a building | `bridge`, `tunnel`, `covered` |
| `layer`      | Number | whole number other than 0, -10 … 10                                   | `layer`                      |
| `oneway`     | Number | 1, or -1 against the line's direction                                 | `oneway`, implied on motorways and roundabouts |
| `roundabout` | Number | 1                                                                     | `junction=roundabout`, `circular` |
| `lanes`      | Number | whole number 1 … 16, both directions together                         | `lanes`                      |
| `width`      | Number | meters, rounded to 0.1                                                | `width`                      |
| `maxspeed`   | Number | km/h, whole number                                                    | `maxspeed`                   |
| `surface`    | String | the tag's value                                                       | `surface`                    |
| `service`    | String | the tag's value, on class `service` only                              | `service`                    |
| `lanes_forward`, `lanes_backward` | Number | whole number 1 … 16: the lanes along the line and against it | `lanes:forward`, `lanes:backward` |
| `lanes_both_ways` | Number | whole number: lanes in the middle that both directions turn from | `lanes:both_ways`            |
| `turn_lanes` | String | what each lane is for, from left to right: `left\|through\|through;right` | `turn:lanes`           |
| `turn_lanes_forward`, `turn_lanes_backward` | String | the same for one direction of a road in two | `turn:lanes:forward`, `turn:lanes:backward` |
| `placement`  | String | where the line lies among the lanes: `right_of:1`, `middle_of:2`, `left_of:1`, `transition` | `placement` |
| `lane_markings` | Number | 0 where the lanes are not marked                                   | `lane_markings=no`           |
| `sidewalk_left`, `sidewalk_right` | String | `yes`, `no`, or `separate` for a pavement mapped as a way of its own | `sidewalk`, `sidewalk:both`, `sidewalk:left`, `sidewalk:right` |
| `name`       | String | the tag's value                                                       | `name`                       |
| `ref`        | String | the tag's value                                                       | `ref`                        |
| `priority_road` | String | `designated`, `yes_unposted` or `end`                              | `priority_road`              |

* `structure`: `tunnel=building_passage` is a `passage`; any other tunnel is a `tunnel`; a bridge
  is a `bridge`; `covered=yes`, `arcade` or `colonnade` without tunnel and bridge is a `passage`.
* `width` reads meters (`3`, `3.5 m`, `3,5`) and feet (`12 ft`, `12'`). `maxspeed` reads km/h
  (`50`, `50 km/h`) and miles (`30 mph`, 48). Anything else (`narrow`, `none`, `signals`, `walk`,
  `DE:urban`) gives no attribute: the tile guesses nothing.

* Directions: "forward" is along the line as it is in the tile, "backward" against it, as in
  OSM. Where `oneway` is -1, traffic runs backward; the tile turns nothing around.
* `turn_lanes` is the tag in lower case without spaces, lanes parted by `|` and the uses of one
  lane by `;`; `none` and an empty place both mean a lane without arrows. A value with anything
  but these words and signs, or longer than 120 characters, gives no attribute.
* `sidewalk_left` and `sidewalk_right` are seen along the line. `sidewalk=both`, `left`,
  `right`, `no`, `none`, `yes` and `separate` set both; `sidewalk:both` sets both again, and
  `sidewalk:left` and `sidewalk:right` have the last word. A road that says nothing has neither
  attribute: unknown is not `no`.
* `name` and `ref` are for telling which lines belong to one street, the two carriageways of a
  boulevard above all, and for signs one day. Only the plain `name`, no other language.

Not in the tile: lanes for buses and bicycles (`lanes:psv`, `cycleway`), parking lanes
(`parking:*`), lane widths (`width:lanes`) and where lanes may be changed (`change:lanes`).

## Layer `road_point`

Points: nodes of roads that say who drives when, and a few that shape the road. A point lies on
a point of its road's line, since no line is simplified. The layer also holds such nodes of ways
the `road` layer leaves out (a crossing of a cycleway with a footpath); a point without a road
through it is not for cars.

| `highway` or tag                  | `kind`            |
|-----------------------------------|-------------------|
| `highway=traffic_signals`         | `signals`         |
| `highway=stop`                    | `stop`            |
| `highway=give_way`                | `give_way`        |
| `highway=crossing`                | `crossing`        |
| `highway=mini_roundabout`         | `mini_roundabout` |
| `highway=turning_circle`, `turning_loop` | `turning_circle` |
| `traffic_calming` on a node that is none of these | `calming` |

| Attribute   | Type   | Value                                                          | From                                   |
|-------------|--------|----------------------------------------------------------------|----------------------------------------|
| `kind`      | String | see above; always there                                        |                                        |
| `direction` | String | `forward`, `backward` or `both`: the traffic it is for, along the road's line or against it | `traffic_signals:direction` on signals, else `direction` |
| `crossing`  | String | the tag's value, on a crossing                                 | `crossing`                             |
| `markings`  | String | the tag's value, on a crossing: `zebra`, `lines`, `no`, …      | `crossing:markings`                    |
| `signals`   | Number | 1 on a crossing with signals                                   | `crossing=traffic_signals`, `crossing:signals=yes` |
| `island`    | Number | 1 on a crossing with a refuge in the middle                    | `crossing:island=yes`                  |
| `calming`   | String | the tag's value: `bump`, `hump`, `table`, `choker`, …          | `traffic_calming`                      |

* `direction` with a compass point or an angle says where a sign faces, not which traffic it is
  for, and gives no attribute. A sign without `direction` is for the traffic that reaches the
  junction it stands before; the game has to work that out.
* Signals mapped once in the middle of a junction and signals mapped at each stop line both
  occur; the tile does not tell them apart.
* Not in the tile: signs other than stop and give way (`traffic_sign`), street lamps, trees,
  barriers.

Measured for the 144 tiles around Munich (2026-11-25, `11.45,48.05,11.75,48.25` cut from Upper
Bavaria): 5.42 MB with these attributes and the `road_point` layer, 5.07 MB without, 7 % more;
the largest tile 112.6 kB, was 108.5 kB. The tile of Munich's old town (14/8718/5685) has 1094
roads, 564 of them with a name, about 510 with pavements said, 85 with `turn_lanes` and 32 with
turn lanes per direction, and 454 points: 300 crossings, 134 signals, 18 give-way signs.

## Layer `building`

Polygons with their holes: every `building` (other than `no`) and every `building:part`, as
closed ways and multipolygons. Outlines and parts lie side by side; the game leaves out an outline
that has parts inside it. Buildings with `location=underground` are left out.

| Attribute     | Type   | Value                                                  | From                                    |
|---------------|--------|--------------------------------------------------------|-----------------------------------------|
| `part`        | Number | 1 on a building part                                   | `building:part` without `building`      |
| `kind`        | String | the tag's value when it is more than `yes`             | `building`, on a part `building:part`   |
| `height`      | Number | meters, rounded to 0.1                                 | `height`, else `building:height`        |
| `min_height`  | Number | meters                                                 | `min_height`, else `building:min_height` |
| `levels`      | Number | as mapped, may have a fraction                         | `building:levels`                       |
| `min_level`   | Number |                                                        | `building:min_level`                    |
| `roof_shape`  | String | the tag's value                                        | `roof:shape`                            |
| `roof_height` | Number | meters                                                 | `roof:height`                           |
| `roof_levels` | Number |                                                        | `roof:levels`                           |
| `colour`      | String | the tag's value                                        | `building:colour`                       |
| `roof_colour` | String | the tag's value                                        | `roof:colour`                           |

Lengths read meters and feet like `width` above.
