#!/bin/bash
# convert a SHEBA results file into a list of stations suitable as input to 
# SPECFEM3D_GLOBE

function usage {
	echo "Usage: `basename $0` [SHEBA results file] > [STATIONS file]" > /dev/stderr
	exit 1
}

if [ $# -ne 1 ]; then
	usage
elif [ ! -f $1 ]; then
	usage
fi

awk '{print $20,$5,$6}' $1 |
	sort -u |
	awk '{print $1, "AN", $2, $3, "0.0 0.0"}'
