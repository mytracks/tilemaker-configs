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
# The cells are not cut from the region one by one: every cut reads its whole input, and the
# planet has more than 100,000 cells. The region is cut into quarters instead, each quarter into
# quarters again, until a piece is one cell. A cut then reads only the piece above it, and a piece
# without data (open sea) ends its whole branch.
#
# Environment:
#   DRIVE_CONFIG  directory of the tile set's config (default /tilemaker-configs/drive/config)
#   DRIVE_REGION  west,south,east,north (default: the config's file "region");
#                 the whole planet is -180,-85.0511,180,85.0511
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
# row $4, widened by $5 degrees on every side, but not beyond the edge of the world.
box () {
    awk -v xa="$1" -v ya="$2" -v xb="$3" -v yb="$4" -v m="$5" 'BEGIN {
        n = 16384; pi = atan2(0, -1)
        west = xa / n * 360 - 180 - m; east = xb / n * 360 - 180 + m
        t = pi * (1 - 2 * ya / n); north = atan2((exp(t) - exp(-t)) / 2, 1) * 180 / pi + m
        t = pi * (1 - 2 * yb / n); south = atan2((exp(t) - exp(-t)) / 2, 1) * 180 / pi - m
        if (west < -180) west = -180; if (east > 180) east = 180
        if (south < -90) south = -90; if (north > 90) north = 90
        printf "%.7f,%.7f,%.7f,%.7f", west, south, east, north
    }'
}

# The part of $1 inside the tiles $2 $3 $4 $5 with its margin, written to $6. Complete: a way that
# crosses the box keeps all its nodes, without which tilemaker stops.
cut () {
    osmconvert "$1" -b="$(box "$2" "$3" "$4" "$5" $margin)" --complete-ways --complete-multipolygons -o="$6"
}

# A file of open sea has nothing but a header.
is_empty () {
    [ "$(stat -c %s "$1")" -lt 1000 ]
}

echo "Cutting and filtering the region"
if [ "$x0" -eq 0 ] && [ "$x1" -eq 16384 ]; then
    # All the way around the world: there is nothing to cut off, and cutting would copy the planet.
    osmfilter "$source" --parameter-file="$config/filter" -o="$work/filtered.o5m"
else
    cut "$source" "$x0" "$y0" "$x1" "$y1" "$work/region.o5m"
    osmfilter "$work/region.o5m" --parameter-file="$config/filter" -o="$work/filtered.o5m"
    rm -f "$work/region.o5m"
fi

cells=$(( ((x1 - x0 + cell - 1) / cell) * ((y1 - y0 + cell - 1) / cell) ))
done_cells=0

# Builds the cell of the tiles $2 $3 $4 $5 from the file $1, which holds at least the cell with
# its margin.
build_cell () {
    done_cells=$((done_cells + 1))
    cut "$1" "$2" "$3" "$4" "$5" "$work/cell.osm.pbf"
    if is_empty "$work/cell.osm.pbf"; then
        echo "Cell $2/$3 ($done_cells of $cells): empty"
        return
    fi

    # A hair inside the cell, so that tilemaker writes the cell's tiles and not their neighbors.
    local tiles
    tiles=$(box "$2" "$3" "$4" "$5" -0.000001)
    sed "s/\"bounding_box\": *\[[^]]*\]/\"bounding_box\": [${tiles//,/, }]/" "$config/config.json" > "$work/config.json"
    echo "Cell $2/$3 ($done_cells of $cells): $(stat -c %s "$work/cell.osm.pbf") bytes"
    tilemaker --input "$work/cell.osm.pbf" --output "$output" --merge --config "$work/config.json" --process "$config/process.lua" > "$work/tilemaker.log" 2>&1 \
        || { cat "$work/tilemaker.log"; exit 1; }
}

# Builds the tiles $2 $3 $4 $5 from the file $1, which holds at least these tiles with their
# margin. $6 is the depth of the recursion and names the temporary files.
build () {
    local file=$1 ax=$2 ay=$3 bx=$4 by=$5 depth=$6
    local nx=$(( (bx - ax + cell - 1) / cell )) ny=$(( (by - ay + cell - 1) / cell ))
    if [ "$nx" -le 1 ] && [ "$ny" -le 1 ]; then
        build_cell "$file" "$ax" "$ay" "$bx" "$by"
        return
    fi

    # Halves along the borders of cells, so that the cells are the same however the region is
    # divided on the way to them.
    local mx=$(( nx > 1 ? ax + (nx + 1) / 2 * cell : bx ))
    local my=$(( ny > 1 ? ay + (ny + 1) / 2 * cell : by ))
    local columns=("$ax $mx" "$mx $bx") rows=("$ay $my" "$my $by")
    local column row px qx py qy part=0 piece
    for column in "${columns[@]}"; do
        read -r px qx <<< "$column"
        [ "$px" -lt "$qx" ] || continue
        for row in "${rows[@]}"; do
            read -r py qy <<< "$row"
            [ "$py" -lt "$qy" ] || continue
            part=$((part + 1))

            # A single cell is cut straight into what tilemaker reads.
            if [ $((qx - px)) -le "$cell" ] && [ $((qy - py)) -le "$cell" ]; then
                build_cell "$file" "$px" "$py" "$qx" "$qy"
                continue
            fi

            piece="$work/piece-$depth-$part.o5m"
            cut "$file" "$px" "$py" "$qx" "$qy" "$piece"
            if is_empty "$piece"; then
                local skipped=$(( ((qx - px + cell - 1) / cell) * ((qy - py + cell - 1) / cell) ))
                done_cells=$((done_cells + skipped))
                echo "Cells from $px/$py to $((qx - 1))/$((qy - 1)) ($done_cells of $cells): empty"
            else
                build "$piece" "$px" "$py" "$qx" "$qy" $((depth + 1))
            fi
            rm -f "$piece"
        done
    done
}

build "$work/filtered.o5m" "$x0" "$y0" "$x1" "$y1" 0

rm -rf "$work"
echo "Built $output"
