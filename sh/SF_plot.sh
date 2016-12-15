#!/bin/bash
# Plot the setup as described by the files in the directory DATA, using GMT.

usage() {
	cat <<-END >&2
	Usage: $(basename $0) [-c CMTSOLUTION] [-p Par_file] [-s STATIONS] [-d directory]
	Plot the setup of the current run, as per the files in the DATA directory.
	Options:
	   -b      : Batch mode: do not show plot with gv.
	   -c file : Specify CMTSOLUTION file to use [DATA/CMTSOLUTION]
	   -d dir  : Specify directory in which to file files you have not specified
	             with -c, -p or -s [DATA]
	   -o file : Save PostScript plot to <file>.  If the extension is \`pdf', convert
	             to PDF first.
	   -p file : Specify Par_file to use [DATA/Par_file]
	   -s file : Specift STATIONS file to use [DATA/STATIONS]
	END
	exit 1
}

while [ "$1" ]; do
	case "$1" in
		-b) batch=1; shift;;
		-c) CMTSOLUTION="$2"; shift 2;;
		-d) DIR="$2"; shift 2;;
		-o) ofile="$2"; shift 2;;
		-p) Par_file="$2"; shift 2;;
		-s) STATIONS="$2"; shift 2;;
		*) usage;;
	esac
done

# Default names and directories overridden if chosen on command line
DIR="${DIR:-DATA}"
CMTSOLUTION="${CMTSOLUTION:-${DIR}/CMTSOLUTION}"
Par_file="${Par_file:-${DIR}/Par_file}"
STATIONS="${STATIONS:-${DIR}/STATIONS}"

for f in "$CMTSOLUTION" "$STATIONS" "$Par_file"; do
	[ -r "$f" ] || { echo "Cannot find file \"$f\"" >&2; exit 1; }
done

FIG=$(mktemp /tmp/SF_plot.psXXXXXX)
trap 'rm -f "$FIG"' EXIT

# Plot size
size=12

# Get some information
read NCHUNKS lat lon dep rest <<< $(awk '
	/^ *NCHUNKS *=/ {n = $3}
	/latitude:/ {lat = $2}
	/longitude:/ {lon = $2}
	/depth:/ {dep = $2}
	END {print n, lat, lon, dep}' "$Par_file" "$CMTSOLUTION")

# Get projection
if [ $NCHUNKS -lt 6 ]; then
	case $NCHUNKS in
		1) horiz=90;;
		2|3) horiz=150;;
		4|5) echo "$(basename $0): NCHUNKS cannot be 4 or 5" >&2; exit 1;;
	esac
	J=A$lon/$lat/$horiz/${size}c
else
	J=Q$lon/${size}c
fi

# Plot coastlines
pscoast -J$J -Rd -Dc -Slightblue -Glightgreen -Wblack -K -P > "$FIG"

# Plot stations
awk '{print $4,$3}' "$STATIONS" |
	psxy -J -R -Si0.2c -Gblue -O -K >> "$FIG"

# Plot focal mechanisms
awk -v lon=$lon -v lat=$lat -v dep=$dep '
	BEGIN {printf("%f %f %f ", lon, lat, dep)}
	NR>=8 && NR<=14 {printf("%s ", $2)}
	END {print 0,0,0}' "$CMTSOLUTION" |
	psmeca -J -R -Sm0.8c -M -T0 -O -K >> "$FIG"

# Plot chunk edges, if applicable
[ $NCHUNKS -lt 6 ] &&
	"$(dirname "$(type -p "$0")")/chunk_corners.sh" -l "$Par_file" |
		psxy -J -R -O -W3p,red -Bnsew >> "$FIG"

# Display, save
[ -z "$batch" ] && gv "$FIG"
if [ "$ofile" ]; then
	[ -d "$(dirname "$ofile")" ] || { echo "Output file directory does not exist" >&2; exit 1; }
	[ "${ofile: -4}" = ".pdf" ] && ps2pdf_crop "$FIG" "$ofile" || mv "$FIG" "$ofile"
fi
