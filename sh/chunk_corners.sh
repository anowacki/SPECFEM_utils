#!/bin/sh
# Return the corners of a 1- or 2-chunk simulation.  Optionally, return
# the lines connecting them.

usage() {
	cat <<-END >&2
	Usage: $(basename $0) (options) (Par_file)
	Output the corners of the simulation defined by <Par_file>, which must be
	given if it cannot be found in DATA/Par_file.
	Options:
	   -l : Output lines connecting points
	END
	exit 1
}

while [ "$1" ]; do
	case "$1" in
		-l) lines=1; shift;;
		*) [ $# -eq 1 ] && [ -f "$1" ] || usage
		   break;;
	esac
done

file="${1:-DATA/Par_file}"
[ -f "$file" ] || { echo "$(basename "$0"): Cannot find Par_file \"$file\"" >&2; exit 1; }

[ -f "$(dirname $(type -p "$0"))/funcs.awk" ] || { echo "Cannot find \"$(dirname "$0")/funcs.awk\"" >&2; exit 1; }

awk -v lines="$lines" "
$(cat "$(dirname "$0")"/funcs.awk)
"'
function print_lon_lat(v,   a) {
	cart2geog(v[1], v[2], v[3], a)
	print a[1], a[2]
}

# Get variables
/^ *NCHUNKS *=/ {n = $3}
/^ *ANGULAR_WIDTH_XI_IN_DEGREES *=/ {xi = torad($3); xid = $3+0}
/^ *ANGULAR_WIDTH_ETA_IN_DEGREES *=/ {eta = torad($3)}
/^ *CENTER_LATITUDE_IN_DEGREES *=/ {lat = $3}
/^ *CENTER_LONGITUDE_IN_DEGREES *=/ {lon = $3}
/^ *GAMMA_ROTATION_AZIMUTH *=/ {gamma = torad($3); gammad = $3+0}

END {
	if (n > 2) {
		print "chunk_corners.sh: No output given for NCHUNKS = " n > "/dev/stderr"
		exit
	}

	# Make a square around (0, 0) (gamma = 0)
	# 4 3
	# 1 2
	XI = tan(xi/2)
	ETA = tan(eta/2)
	G = 1/sqrt(1 + x^2 + y^2)
	P1[1] = G;  P1[2] = -XI*G;  P1[3] = -ETA*G
	P2[1] = G;  P2[2] =  XI*G;  P2[3] = -ETA*G
	P3[1] = G;  P3[2] =  XI*G;  P3[3] =  ETA*G
	P4[1] = G;  P4[2] = -XI*G;  P4[3] =  ETA*G
	
	# Add on the extra two points for the 2-chunk case
	# 5 4 3
	# 6 1 2
	if (n == 2) {
		abc2rotmat(0, 0, xid, R)
		matvmul(3, R, P4, P5)
		matvmul(3, R, P1, P6)
	}
	
	# Rotate to the correct gamma at (0, 0)
	abc2rotmat(-gammad, 0, 0, R)
	matvmul(3, R, P1, Q1)
	matvmul(3, R, P2, Q2)
	matvmul(3, R, P3, Q3)
	matvmul(3, R, P4, Q4)
	if (n == 2) {
		matvmul(3, R, P5, Q5)
		matvmul(3, R, P6, Q6)
	}	
	
	# Rotate to the correct orientation
	abc2rotmat(0, lat, -lon, R)
	matvmul(3, R, Q1, R1)
	matvmul(3, R, Q2, R2)
	matvmul(3, R, Q3, R3)
	matvmul(3, R, Q4, R4)
	if (n == 2) {
		matvmul(3, R, Q5, R5)
		matvmul(3, R, Q6, R6)
	}
	
	# Output points
	print_lon_lat(R1)
	print_lon_lat(R2)
	print_lon_lat(R3)
	print_lon_lat(R4)
	if (n == 2) {
		print_lon_lat(R5)
		print_lon_lat(R6)
	}
	if (lines) {
		print_lon_lat(R1)
		if (n == 2) print_lon_lat(R4)
	}
}' "$file"
