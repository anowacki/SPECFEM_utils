#!/bin/bash
# Plot the location and beachball of the CMT described in a CMTSOLUTION file

usage() {
	echo "Usage: `basename $0` [CMTSOLUTION]" > /dev/stderr
	exit 1
}

if [ $# -ne 1 ]; then
	usage
elif [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
	usage
fi

# Plot parameters
size=12 # / cm

# Get parameters from CMTSOLUTION file
FIG=$(mktemp /tmp/plot_CMTSOLUTION.psXXXXXX)
trap 'rm -f "$FIG"' EXIT
INFILE=$1
J=$(awk '/latitude:/{lat=$2} /longitude:/{lon=$2} END{print "G" lon "/" lat}
' $INFILE)/${size}c

# Plot coastlines
pscoast -J$J -Rd -Dc -Slightblue -Glightgreen -Wblack -K -P > $FIG

# Plot focal mechanism
awk 'NR==1 {printf("%s %s %s ", $9,$8,$10)}
	NR>=8 && NR<=14 {
		gsub("E+"," "); printf("%s ",$2); expn=$3; expn=25 # To keep plot about same size
	}
	END {print expn,"0 0"}' $INFILE |
	psmeca -J -R -Sm1c -T0 -O >> $FIG

gv $FIG 2>/dev/null

exit 0
