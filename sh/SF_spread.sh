#!/bin/sh
# Return a list of stations, suitable for input to SPECFEM3D_GLOBE, which
# have their location specified by a set of rules.
#
# Commonly, it may be used for:
#	- lon, lat grids
#	- azimuth, distance grids, away from any point (including the event
#     in the CMTSOLUTION file by default if present)

# Defaults
NET="AN" # Network code
PREFIX="S" # Prefix to file names

usage() {
	cat <<-END >&2
	Usage: $(basename "$0") options
	   Create a set of stations in STATIONS file format for use with SPECFEM3D_GLOBE.

	Options (one of):
	   Fans:
	   -F a1 a2 da d1 d2 dd : Create a 'fan' of stations from the event or point,
	                       between azimuths <a1> and <a2>, spaced by <da>,
	                       with distances in range <d1>-<d2>, spaced by <dd>, all
	                       in degrees.  (If crossing the 0 azimuth direction, just
	                       use values less than 0 or greater than 360 degrees.)
	                       By default, the point is the event location in a nearby
	                       CMTSOLUTION file; specify another with -p.
	   -f amax da dmax dd : Create a 'relative fan' of stations from the events or
	                       point, with the azimuth and distance centred on a second
	                       point.  Maximum azimuth offset <amax>, azimuth spacing <da>,
	                       maximum distance offset <dmax> and distance spacing <dd>.
	                       By default, the second point is the mean station location in
	                       a nearby STATIONS file; specify another with -s

	      Fan stations are named like:
	                           <prefix><az number>.<d number>
	      where <az number> is the index of the azimuth, and <d number> is the index of
	      the distance, both starting at 1.

	   Grids:
	   -G lon1 lon2 dlon lat1 lat2 dlat :
	                       Create a lon-lat grid of stations with longitudes in range
	                       <lon1>-<lon2> and latitudes <lat1>-<lat2>, spaced
	                       respectively by <dlon> and <dlat>, all degrees.
	   -g dmax dd        : Create a relative lon-lat grid centred around the mean station
	                       location with maximum (latitudinal) distance from the centre
	                       of <dmax> degrees, and spacing <dd>.  Alternatively, set the
	                       relative point with -p.

	      Grid stations are named like:
	          <prefix><lon number>.<lat number>
	      where <lon number> is the index of the azimuth, and <d number> is the index
	      of the distance, both starting at 1.

	Additional options:
	   -C file           : Use the CMTSOLUTION file <file> for the fan point
	                       [searches for STATIONS files or uses the provided point].
	   -N net            : Set two-letter seismic network code ["$NET"].
	   -P prefix         : Prefix to station names ["$PREFIX"].
	   -p lon lat        : Centre the fan or relative grid about the point at <lon>,
	                       <lat>.
	   -S file           : Use the STATIONS file <file> for the relative grid
	                       [searches for STATIONS files or uses the provided point].
	   -s lon lat        : Centre the relative fan about <lon>, <lat>.
	END
	exit 1
}

die() { echo "$(basename "$0"): Error: $@" >&2; exit 1; }

get_float() {
	[ $# -ne 1 ] && { echo "get_float: Error: Supply one argument." >&2; return 1; }
	printf "%f" "$1" 2>/dev/null ||
		{ echo "check_float: Can't get decimal number from argument \"$1\""; return 1; }
}

get_positive_float() { [ "${1:0:1}" != "-" ] && get_float "$1" || return 1; }

get_file() { [ -r "$1" ] && echo "$1" || return 1; }

# Unset all variables which determine which type of spread to create
unset_all() { unset fan relfan grid relgrid; }

# Get command line options
[ $# -gt 0 ] || usage
while [ "$1" ]; do
	case "$1" in
		# Compulsory
		-F)
			[ $# -ge 7 ] &&
			a1=$(get_float "$2") &&
			a2=$(get_float "$3") &&
			da=$(get_positive_float "$4") &&
			d1=$(get_positive_float "$5") &&
			d2=$(get_positive_float "$6") &&
			dd=$(get_positive_float "$7") || usage
			unset_all
			fan=1
			shift 7;;
		-f)
			[ $# -ge 5 ] &&
			amax=$(get_positive_float "$2") &&
			da=$(get_positive_float "$3") &&
			dmax=$(get_positive_float "$4") &&
			dd=$(get_positive_float "$5") || usage
			unset_all
			relfan=1
			shift 5;;
		-G)
			[ $# -ge 7 ] &&
			lon1=$(get_float "$2") &&
			lon2=$(get_float "$3") &&
			dlon=$(get_positive_float "$4") &&
			lat1=$(get_float "$5") &&
			lat2=$(get_float "$6") &&
			dlat=$(get_positive_float "$7") || usage
			unset_all
			grid=1
			shift 7;;
		-g)
			[ $# -ge 3 ] &&
			dmax=$(get_positive_float "$2") &&
			dd=$(get_positive_float "$3") || usage
			unset_all
			relgrid=1
			shift 3;;
		# Optional
		-C)
			CMTSOLUTION=$(get_file "$2") || die "Cannot read CMTSOLUTION file \"$2\""
			shift 2;;
		-N)
			NET=${2:0:2}; shift 2;; # Truncated to first two letters
		-P)
			PREFIX="$2"; shift 2;;
		-p)
			[ $# -ge 3 ] &&
			lon=$(get_float "$2") &&
			lat=$(get_float "$3") || usage
			shift 3;;
		-S)
			STATIONS=$(get_file "$2") || die "Cannot read STATIONS file \"$2\""
			shift 2;;
		-s) [ $# -ge 3 ] &&
			slon=$(get_float "$2") &&
			slat=$(get_float "$3") || usage
			shift 3;;
		*) usage;;
	esac
done

# Get the (relative) fan start point from a file if not given on command line
if ([ "$fan" ] || [ "$relfan" ]) && ! [ "$lon" ]; then
	for f in "$CMTSOLUTION" CMTSOLUTION DATA/CMTSOLUTION _dummy; do
		[ "$f" = "_dummy" ] && die "No point set and cannot find a CMTSOLUTION file"
		if [ -f "$f" ]; then
			read lon lat <<< $(awk '
				/^ *longitude:/ {lon=$2}
				/^ *latitude:/ {lat=$2}
				END{print lon, lat}' "$f")
			echo "Using point (lon, lat) = ($lon, $lat) from file $f" >&2
			break
		fi
	done
fi

# Mean station location by default if no other point for relative spreads
if ([ "$relgrid" ] && ! [ "$lon" ]) || ([ "$relfan" ] && ! [ "$slon" ]); then
	for f in "$STATIONS" STATIONS DATA/STATIONS _dummy; do
		[ "$f" = "_dummy" ] && die "No station point set and cannot find a STATIONS file"
		if [ -f "$f" ]; then
			read slon slat <<< $(
				awk "$(cat "$(dirname "$0")/funcs.awk")
					NF >= 4 {
						lon[++n] = \$4
						lat[n] = \$3
					}
					END {
						if (n == 0) {
							print \"No stations in file \" FILENAME > \"/dev/stderr\"
							exit(1)
						} else {
							spherical_mean(lon, lat, n, a)
							print a[1], a[2]
						}
					}" "$f") || die "No point set and no points in station file $f"
			echo "Using station point (lon, lat) = ($slon, $slat) from file $f" >&2
			[ "$relgrid" ] && lon=$slon lat=$slat
			break
		fi
	done
fi

# Azimuthal fan away from a point, or in CMTSOLUTION file if none specified
if [ "$fan" ]; then
	# Make fan
	awk -v a1=$a1 -v a2=$a2 -v da=$da -v d1=$d1 -v d2=$d2 -v dd=$dd \
		-v lon=$lon -v lat=$lat -v net=$NET -v prefix=$PREFIX "
		$(cat "$(dirname "$0")/funcs.awk")
		BEGIN {
			v[1] = 0
			v[2] = 0
			for (a=a1; a<=a2; a+=da) {
				ia++
				id = 0
				for (d=d1; d<=d2; d+=dd) {
					id++
					step(lon, lat, a, d, v)
					printf(\"%s%03d.%03d %s %f %f 0.0 0.0\n\", \
						prefix, ia, id, net, v[2], (v[1] + 180)%360 - 180)
				}
			}
		}" || die "Problem calculating fan coordinates"
elif [ "$relfan" ]; then
	# Make relative fan
	awk -v amax=$amax -v da=$da -v dmax=$dmax -v dd=$dd -v lon=$lon -v lat=$lat \
		-v slon=$slon -v slat=$slat -v net=$NET -v prefix=$PREFIX "
		$(cat "$(dirname "$0")/funcs.awk")
		BEGIN {
			v[1] = 0
			v[2] = 0
			az = azimuth(lon, lat, slon, slat)
			dist = delta(lon, lat, slon, lat)
			for (a=az-amax; a<=az+amax; a+=da) {
				ia++
				id = 0
				for (d=dist-dmax; d<=dist+dmax; d+=dd) {
					id++
					step(lon, lat, a, d, v)
					printf(\"%s%03d.%03d %s %f %f 0.0 0.0 \n\", \
						prefix, ia, id, net, v[2], (v[1] + 180)%360 - 180)
				}
			}
		}" || die "Problem calculating relative fan coordinates"
elif [ "$grid" ]; then
	# Make grid
	awk -v lon1=$lon1 -v lon2=$lon2 -v lat1=$lat1 -v lat2=$lat2 \
		-v dlon=$dlon -v dlat=$dlat -v net=$NET -v prefix=$PREFIX '
		function abs(x) {return x >= 0 ? x : -x}
		BEGIN {
			v[1] = 0
			v[2] = 0
			for (lon=lon1; lon<=lon2; lon+=dlon) {
				ilon++
				ilat = 0
				for (lat=lat1; lat<=lat2; lat+=dlat) {
					ilat++
					if (abs(lat) > 90) {
						print "Error: latitude ("lat") invalid" > "/dev/stderr"
						err = 1
						exit(err)
					}
					printf("%s%03d.%03d %s %f %f 0.0 0.0\n", \
						prefix, ilon, ilat, net, v[2], v[1])
				}
			}
		}' || die "Problem calculating grid coordinates"
elif [ "$relgrid" ]; then
	# Make relative grid
	awk -v lon1=$slon -v lat1=$slat -v dmax=$dmax -v dd=$dd -v net=$NET -v prefix=$PREFIX '
		function abs(x) {return x >= 0 ? x : -x}
		BEGIN {
			for (lon=lon1-dmax; lon<=lon1+dmax; lon+=dd) {
				ilon++
				ilat = 0
				for (lat=lat1-dmax; lat<=lat1+dmax; lat+=dd) {
					ilat++
					if (abs(lat) > 90) {
						print "Error: latitude ("lat") invalid" > "/dev/stderr"
						err = 1
						exit(err)
					}
					printf("%s%03d.%03d %s %f %f 0.0 0.0\n", \
						prefix, ilon, ilat, net, lat, (lon+180)%360-180)
				}
			}
		}' || die "Problem calculating relative grid coordinates"
fi
