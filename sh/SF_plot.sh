#!/bin/bash
# Plot the setup as described by the files in the directory DATA, using GMT.

usage() {
	cat <<-END >&2
	Usage: $(basename $0)
	Plot the setup of the current run, as per the files in the DATA directory
	END
	exit 1
}

[ "$1" ] && usage

[ -d "DATA" ] || { echo "Cannot find DATA directory" >&2; exit 1; }
for f in CMTSOLUTION STATIONS Par_file; do
	[ -f "DATA/$f" ] || { echo "Cannot find file DATA/$f" >&2; exit 1; }
done

FIG=$(mktemp /tmp/SF_plot.psXXXXXX)
trap 'rm -f "$FIG"' EXIT

# Plot size
size=12

# Get some information
read NCHUNKS lat lon rest <<< $(awk '
	/^ *NCHUNKS *=/ {print $3}
	/latitude:/ || /longitude:/ {print $2}' DATA/Par_file DATA/CMTSOLUTION)

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
awk '{print $4,$3}' DATA/STATIONS |
	psxy -J -R -Si0.2c -Gblue -O -K >> "$FIG"

# Plot focal mechanisms
awk 'NR==1 {printf("%s %s %s ", $9,$8,$10)}
	NR>=8 && NR<=14 {
		gsub("E+"," "); printf("%s ",$2);  expn=18 # To keep plot about same size
	}
	END {print expn,"0 0"}' DATA/CMTSOLUTION |
	psmeca -J -R -Sm0.2c -T0 -O -K >> "$FIG"

# Plot chunk edges, if applicable
[ $NCHUNKS -lt 6 ] &&
	"$(dirname "$(type -p "$0")")/chunk_corners.sh" -l |
		psxy -J -R -O -W3p,red -Bnsew >> "$FIG"

gv "$FIG"
