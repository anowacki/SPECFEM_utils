#!/bin/bash
# Plot the setup as described by the files in the directory DATA, using GMT.

usage() {
	cat <<-END >&2
	Usage: $(basename $0) [-c CMTSOLUTION] [-p Par_file] [-s STATIONS]
	Plot the setup of the current run, as per the files in the DATA directory.
	Alternatively, supply files using the -c, -s and -p options to plot
	different files.
	END
	exit 1
}

# Defaults
CMTSOLUTION="DATA/CMTSOLUTION"
Par_file="DATA/Par_file"
STATIONS="DATA/STATIONS"

while [ "$1" ]; do
	case "$1" in
		-c) CMTSOLUTION="$2"; shift 2;;
		-p) Par_file="$2"; shift 2;;
		-s) STATIONS="$2"; shift 2;;
		*) usage;;
	esac
done

for f in "$CMTSOLUTION" "$STATIONS" "$Par_file"; do
	[ -f "$f" ] || { echo "Cannot find file \"$f\"" >&2; exit 1; }
done

FIG=$(mktemp /tmp/SF_plot.psXXXXXX)
trap 'rm -f "$FIG"' EXIT

# Plot size
size=12

# Get some information
read NCHUNKS lat lon rest <<< $(awk '
	/^ *NCHUNKS *=/ {print $3}
	/latitude:/ || /longitude:/ {print $2}' "$Par_file" "$CMTSOLUTION")

# Get projection
if [ $NCHUNKS -lt 6 ]; then
	case $NCHUNKS in
		1) horiz=90;;
		2|3) horiz=150;;
		4|5) echo "$(basename $0): NCHUNKS cannot be 4 or 5" >&2; exit 1;;
	esac
	J=A$lon/$lat/$horiz/${size}c
else
	J=Q$lon/$lat/${size}c
fi

# Plot coastlines
pscoast -J$J -Rd -Dc -Slightblue -Glightgreen -Wblack -K -P > "$FIG"

# Plot stations
awk '{print $4,$3}' "$STATIONS" |
	psxy -J -R -Si0.2c -Gblue -O -K >> "$FIG"

# Plot focal mechanisms
awk 'NR==1 {printf("%s %s %s ", $9, $8, $10)}
	NR>=8 && NR<=14 {printf("%s ", $2)}
	END {print 0,0,0}' "$CMTSOLUTION" |
	psmeca -J -R -Sm0.8c -M -T0 -O -K >> "$FIG"

# Plot chunk edges, if applicable
[ $NCHUNKS -lt 6 ] &&
	"$(dirname "$(type -p "$0")")/chunk_corners.sh" -l "$Par_file" |
		psxy -J -R -O -W3p,red -Bnsew >> "$FIG"

gv "$FIG"
