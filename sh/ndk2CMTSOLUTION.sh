#!/bin/bash
# Convert a Global CMT project's ndk format into the input CMTSOLUTION file
# for use with SPECFEM3D_GLOBE.

####
# Usage function
####
usage() {
	cat <<-END >&2
	$(basename $0): Convert GlobalCMT project .ndk file into CMTSOLUTION file
	echo "Usage: `basename $0` < [5 lines ndk format] > [CMTSOLUTION]
	END
	exit 1
}

####
# Get input and check format
####
TEMP=/tmp/ndk2CMTSOLUTION.$$.$RANDOM.tmp
cat /dev/stdin > $TEMP
if [ $(wc -l < $TEMP 2> /dev/null) -ne 5 ]; then
	echo "Input must be GlobalCMT project .ndk description of one earthquake (5 lines)" > /dev/stderr
	usage
fi
# Output in CMTSOLUTION format
awk '
	NR == 1 {
		code = $1
		date = $2
		year = substr(date,1,4)
		month = substr(date,6,2)
		day = substr(date,9,2)
		time = $3
		hour = substr(time,1,2)
		min = substr(time,4,2)
		sec = substr(time,7)
		elat = $4
		elon = $5
		edep = $6
		eM1 = $7
		eM2 = $8
		for (i=9; i<=NF; i++) {
			label = label " " $i
		}
	}
	NR == 3 {
		lat = $4
		lon = $6
		dep = $8
	}
	NR == 4 {
		expn = $1
		Mrr = $2
		Mtt = $4
		Mpp = $6
		Mrt = $8
		Mrp = $10
		Mtp = $12
	}
	END {
		printf("%4s%5d%3d%3d%3d%3d%6.2f %s %s %s %s %s %s\n", \
          code,year,month,day,hour,min,sec,elat,elon,edep,eM1,eM2,label)
		print "event name:     " label
		print "time shift:      0.0000"
		print "half duration:   0.0000"
		print "latitude:        " elat
		print "longitude:       " elon
		print "depth:         " edep
		print "Mrr:    " Mrr "E+" expn
		print "Mtt:    " Mtt "E+" expn
		print "Mpp:    " Mpp "E+" expn
		print "Mrt:    " Mrt "E+" expn
		print "Mrp:    " Mrp "E+" expn
		print "Mtp:    " Mtp "E+" expn

	}
	' $TEMP 


# Clear away temp file
/bin/rm -f $TEMP

exit 0
