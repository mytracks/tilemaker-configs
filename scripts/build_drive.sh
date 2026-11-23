#!/bin/bash

# Builds the drive tile set: build_drive.sh <source.o5m> <output.mbtiles>
#
# The source is cut to the region, filtered, and built cell by cell into one file. tilemaker holds
# all geometry of its input in memory, about 4 GB for Upper Bavaria alone, so the region does not
# fit into one run.
#
# A cell is a square of zoom-14 tiles, and tilemaker is told to write exactly these tiles: where
# two runs write the same tile, merging does not replace it but puts both contents into it. The
# data of a cell reaches a margin beyond it, so that every tile of the cell is complete.
#
# Environment:
#   DRIVE_CONFIG  directory of the tile set's config (default /tilemaker-configs/drive/config)
#   DRIVE_REGION  west,south,east,north (default: the config's file "region")
#   DRIVE_CELL    tiles per side of a cell (default 48, about one degree of longitude)
#   DRIVE_WORK    directory for temporary files (default: beside the output)

set -e

source=$1
output=$2
config=${DRIVE_CONFIG:-/tilemaker-configs/drive/config}
region=${DRIVE_REGION:-$(cat "$config/region")}
cell=${DRIVE_CELL:-48}
work=${DRIVE_WORK:-$(dirname "$output")/drive-work}

if [ -z "$source" ] || [ -z "$output" ]; then
    echo "Usage: build_drive.sh <source.o5m> <output.mbtiles>"
    exit 1
fi

rm -rf "$work"
mkdir -p "$work"
rm -f "$output"

# Degrees of the data's margin around a cell: more than two tiles.
margin=0.05

# The zoom-14 tiles that lie completely inside the region: first column, column after the last,
# first row, row after the last. Rows count from the north.
range=$(awk -v r="$region" 'BEGIN {
    split(r, b, ","); n = 16384; pi = atan2(0, -1)
    x0 = (b[1] + 180) / 360 * n; x0i = int(x0); if (x0i < x0) x0i++
    x1i = int((b[3] + 180) / 360 * n)
    s = sin(b[4] * pi / 180); y0 = (0.5 - log((1 + s) / (1 - s)) / (4 * pi)) * n
    y0i = int(y0); if (y0i < y0) y0i++
    s = sin(b[2] * pi / 180); y1i = int((0.5 - log((1 + s) / (1 - s)) / (4 * pi)) * n)
    print x0i, x1i, y0i, y1i
}')
read -r x0 x1 y0 y1 <<< "$range"
echo "Region $region: columns $x0 to $((x1 - 1)), rows $y0 to $((y1 - 1)), cells of $cell tiles"

# west,south,east,north of the tiles from column $1 and row $2 up to, not including, column $3 and
# row $4, widened by $5 degrees on every side.
box () {
    awk -v xa="$1" -v ya="$2" -v xb="$3" -v yb="$4" -v m="$5" 'BEGIN {
        n = 16384; pi = atan2(0, -1)
        west = xa / n * 360 - 180; east = xb / n * 360 - 180
        t = pi * (1 - 2 * ya / n); north = atan2((exp(t) - exp(-t)) / 2, 1) * 180 / pi
        t = pi * (1 - 2 * yb / n); south = atan2((exp(t) - exp(-t)) / 2, 1) * 180 / pi
        printf "%.7f,%.7f,%.7f,%.7f", west - m, south - m, east + m, north + m
    }'
}

# The region with its margin, complete: a way that crosses the box keeps all its nodes, without
# which tilemaker stops.
echo "Cutting and filtering the region"
osmconvert "$source" -b="$(box "$x0" "$y0" "$x1" "$y1" $margin)" --complete-ways --complete-multipolygons -o="$work/region.o5m"
osmfilter "$work/region.o5m" --parameter-file="$config/filter" -o="$work/filtered.o5m"
rm -f "$work/region.o5m"

for ((cx = x0; cx < x1; cx += cell)); do
    for ((cy = y0; cy < y1; cy += cell)); do
        ex=$((cx + cell < x1 ? cx + cell : x1))
        ey=$((cy + cell < y1 ? cy + cell : y1))

        osmconvert "$work/filtered.o5m" -b="$(box "$cx" "$cy" "$ex" "$ey" $margin)" --complete-ways --complete-multipolygons -o="$work/cell.osm.pbf"
        # A cell of open sea has nothing but a header.
        if [ "$(stat -c %s "$work/cell.osm.pbf")" -lt 1000 ]; then
            echo "Cell $cx/$cy: empty"
            continue
        fi

        # A hair inside the cell, so that tilemaker writes the cell's tiles and not their neighbors.
        tiles=$(box "$cx" "$cy" "$ex" "$ey" -0.000001)
        sed "s/\"bounding_box\": *\[[^]]*\]/\"bounding_box\": [${tiles//,/, }]/" "$config/config.json" > "$work/config.json"
        echo "Cell $cx/$cy: $(stat -c %s "$work/cell.osm.pbf") bytes"
        tilemaker --input "$work/cell.osm.pbf" --output "$output" --merge --config "$work/config.json" --process "$config/process.lua" > "$work/tilemaker.log" 2>&1 \
            || { cat "$work/tilemaker.log"; exit 1; }
    done
done

rm -rf "$work"
echo "Built $output"
