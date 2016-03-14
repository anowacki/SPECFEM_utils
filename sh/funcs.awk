# This file contains AWK functions.  Use them with the following syntax:
#	awk -f $THIS_DIR/funcs.awk -f your_AWK_program
# OR
# export AWKPATH=$THIS_DIR then use gawk's @include feature:
#	gawk '@include "funcs.awk"; {print}'
#
# Notes about awk to remember:
#	- 0 is false, > 0 is true

##########
# Error handling
##########
function error(prog_name, error_string) {
	print prog_name": Error: "error_string > "/dev/stderr"
	exit
}

function warning(prog_name, error_string) {
	print prog_name": Warning: "error_string > "/dev/stderr"
}


##########
# Numerical
##########

# Return absolute value
function abs(x) {
	return (x > 0) ? x : -x
}

# Check a number is an integer
function isInteger(a) {
	if (a%1 == 0) return 1; else return 0
}

##########
# Trigonometry
##########

function pi() { return 4*atan2(1, 1) }
function torad(x) { return x*atan2(1,1)/45 }
function todeg(x) { return x*45/atan2(1,1) }

# Inverse cosine
function acos(x) { return atan2(sqrt(1 - x^2), x) }

# Inverse sine
function asin(x) { return atan2(x, sqrt(1 - x^2)) }

# Tangent
function tan(x) { return sin(x)/cos(x) }

##########
# Coordinate conversion
##########

# Return latitude in degrees from cartesian coordinates
function cart2lat(x, y, z,   r) {
	r = cart2r(x, y, z)
	return todeg(asin(z/r))
}

# Return longitude in degrees from cartesian coordinates
function cart2lon(x, y, z) {
	return todeg(atan2(y, x))
}

# Return radius from cartesian coordinates
function cart2r(x, y, z) {
	return sqrt(x^2 + y^2 + z^2)
}

# Fill in an array with (lon, lat, r) from cartesian coordinates
function cart2geog(x, y, z, a) {
	a[1] = cart2lon(x, y, z)
	a[2] = cart2lat(x, y, z)
	a[3] = cart2r(x, y, z)
}

# Return x coordinate from geographic coordinates
function geog2x(lon, lat, r) {
	return r*cos(torad(lat))*cos(torad(lon))
}

# Return y coordinate from geographic coordinates
function geog2y(lon, lat, r) {
	return r*cos(torad(lat))*sin(torad(lon))
}

# Return z coordinate from geographic coordinates
function geog2z(lon, lat, r) {
	return r*sin(torad(lat))
}

# Fill in an array with (x, y, z) from geographic coordinates
function geog2cart(lon, lat, r, a) {
	a[1] = geog2x(lon, lat, r)
	a[2] = geog2y(lon, lat, r)
	a[3] = geog2z(lon, lat, r)
}

# Cartesian distance between two points
function cartdist(x1, y1, z1, x2, y2, z2) {
	return sqrt((x2-x1)^2 + (y2-y1)^2 + (z2-z1)^2)
}

##########
# Spherical geometry
##########
# Return the great circle distance between two geographic points on a sphere (all degrees)
function delta(lon1, lat1, lon2, lat2,   rlon1, rlat1, rlon2, rlat2) {
	rlon1 = torad(lon1)
	rlat1 = torad(lat1)
	rlon2 = torad(lon2)
	rlat2 = torad(lat2)
	return todeg( \
	       atan2( \
		         sqrt((cos(rlat2)*sin(rlon2-rlon1))^2 + (cos(rlat1)*sin(rlat2) - \
                      sin(rlat1)*cos(rlat2)*cos(rlon2-rlon1))^2) , \
                 sin(rlat1)*sin(rlat2) + cos(rlat1)*cos(rlat2)*cos(rlon2-rlon1)))
}

# Fill in the vector a with the lon and lat of a point d degrees away from that point
# along an azimuth of a (all degrees)
function step(lon, lat, az, d, a,   lon1, lat1, raz, rd, lon2, lat2) {
	lon1 = torad(lon)
	lat1 = torad(lat)
	raz = torad(az)
	rd = torad(d)
    lat2 = asin(sin(lat1)*cos(rd) + cos(lat1)*sin(rd)*cos(raz))
    lon2 = lon1 + atan2(sin(raz)*sin(rd)*cos(lat1), cos(rd) - sin(lat1)*sin(lat2))
	a[1] = todeg(lon2)
	a[2] = todeg(lat2)
	return
}

# Spherical mean of a set of longitudes and latitudes, which are arrays of length n,
# and which are in degrees.
function spherical_mean(lon, lat, n, a,   i, X, Y, Z, v) {
	for (i=1; i<=n; i++) {
		geog2cart(lon[i], lat[i], 1, v)
		X += v[1]
		Y += v[2]
		Z += v[3]
	}
	cart2geog(X/n, Y/n, Z/n, v)
	a[1] = v[1]
	a[2] = v[2]
	return
}

##########
# Vectors
##########

# Fill a vector with values
function xyz2vec(x, y, z, v) {
	delete v
	v[1] = x
	v[2] = y
	v[3] = z
}

# Transform a vector by a transformation matrix R
function vtransform(M, v, vm) {
	matvmul(3, M, v, vm)
}

##########
# General arrays
##########

# Return the maximum value present in an array
function maxval(a,   v, max, first) {
	first = 1
	for (v in a) {
		if (first) {
			max = a[v]
			first = 0
		}
		if (a[v] > max) max = a[v]
	}
	return max
}

# Return the minimum value present in an array
function minval(a,   v, min, first) {
	first = 1
	for (v in a) {
		if (first) {
			min = a[v]
			first = 0
		}
		if (a[v] < min) min = a[v]
	}
	return min
}

# Return the number of items in an array
function arrayLength(a,   i, n) {
	for (i in a) n++
	return n
}

# Return the sum of all elements in an array
function arraySum(a,   i, s) {
	s = 0
	for (i in a) s += a[i]
	return s
}

# Return the product of all elements in an array
function arrayProd(a,   i, p) {
	p = 1
	for (i in a) p *= a[i]
	return p
}

##########
# Matrices
##########

# Creates a rotation matrix from three angles.  These three angles rotate in turn
# about the x1, x2 and x3 axes, clockwise when looking down the axes towards the
# origin.  a, b and c are in degrees
function abc2rotmat(ad, bd, cd, R,   \
		R1, R2, R3, R21, sina, cosa, sinb, cosb, sinc, cosc) {
	a = torad(ad)
	b = torad(bd)
	c = torad(cd)
	sina = sin(a)
	cosa = cos(a)
	R1[1,1] =  1.     ; R1[1,2] =  0.     ; R1[1,3] =  0.
	R1[2,1] =  0.     ; R1[2,2] =  cosa   ; R1[2,3] =  sina
	R1[3,1] =  0.     ; R1[3,2] = -sina   ; R1[3,3] =  cosa
	sinb = sin(b)
	cosb = cos(b)
	R2[1,1] =  cosb   ; R2[1,2] =  0.     ; R2[1,3] = -sinb
	R2[2,1] =  0.     ; R2[2,2] =  1.     ; R2[2,3] =  0.
	R2[3,1] =  sinb   ; R2[3,2] =  0.     ; R2[3,3] =  cosb
	sinc = sin(c)
	cosc = cos(c)
	R3[1,1] =  cosc   ; R3[1,2] =  sinc   ; R3[1,3] =  0.
	R3[2,1] = -sinc   ; R3[2,2] =  cosc   ; R3[2,3] =  0.
	R3[3,1] =  0.     ; R3[3,2] =  0.     ; R3[3,3] =  1.
	sqmatmul(3, R2, R1, R21)
	sqmatmul(3, R3, R21, R)
}

# Multiply two nxn matrices together
function sqmatmul(n, A, B, C,   i, j, k) {
	for (i=1; i<=n; i++) {
		for (j=1; j<=n; j++) {
			C[i,j] = 0
			for (k=1; k<=n; k++) {
				C[i,j] += A[i,k]*B[k,j]
			}
		}
	}
}

# Multiply an n-vector by a square nxn matrix
function matvmul(n, M, v, V,   i, j) {
	delete V
	for (i=1; i<=n; i++) {
		V[i] = 0
		for (j=1; j<=n; j++) {
			V[i] += M[i,j]*v[j]
		}
	}
}

# Write out a square matrix to stdout in a neat-ish way
function sqmat_disp(n, A,   max, min, fmt, i, j) {
	max = abs(maxval(A))
	min = abs(minval(A))
	if (min > max) max = min
	if (max > 1e4 || max < 1e-4) fmt = "%8.2f "
	else                         fmt = "%8.2e "
	for (i=1; i<=n; i++) {
		for (j=1; j<=n; j++) printf(fmt, A[i,j])
		printf("\n")
	}
}

##########
# Date and time functions
##########

# Evaluates a conditional to true if y is a leap year: in awk, non-zero is true
function isLeap(y) {
	if (!isInteger(y)) error("funcs: isLeap", "year must be an integer")
	if ((y%4 == 0 && y%100 != 0) || y%400 == 0) {
		return 1
	} else {
		return 0
	}
}

# Return the number of days in a year
function daysInYear(year) {
	return isLeap(year) ? 366 : 365
}

# Converts a year and day-of-year to day,month,day-of-month.
# date is an array with three elements which are filled with: year,month,day-of-month
function DOY2Cal(y,d,date,   days,m,sumDays,i) {
	if (!isInteger(y) || !isInteger(m) || !isInteger(d)) {
		error("funcs: DOY2cal", "year, month and day must be integers")
	}
	# Check DOY is okay
	if (d > 366 || d < 1) {
		print "DOY2Cal: Day-of-year must be in range 1--366." > "/dev/stderr"
		exit
	}
	
	# Check leap year and set up array of days accordingly
	if (isLeap(y)) {
		days[0]=0    ; days[1]=31   ; days[2]=60  ; days[3]=91  ; days[4]=121
		days[5]=152  ; days[6]=182  ; days[7]=213 ; days[8]=244 ; days[9]=274
		days[10]=305 ; days[11]=335 ; days[12]=366
	} else {
		if (d == 366) {
			print "DOY2Cal: "y" is not a leap year, but day given as "d"." > "/dev/stderr"
			exit
		}
		days[0]=0    ; days[1]=31   ; days[2]=59  ; days[3]=90  ; days[4]=120
		days[5]=151  ; days[6]=181  ; days[7]=212 ; days[8]=243 ; days[9]=273
		days[10]=304 ; days[11]=334 ; days[12]=365
	}

	# Return year month day-of-month
	sumDays = 0
	for (i=1; i<=12; i++) {
		m = i
		if (d <= days[i]) break
	}
	date[1] = y
	date[2] = m
	date[3] = d-days[m-1]
}

# Convert calendar date into day-of-year.  Args are year,month,day.  Returns DOY
function Cal2DOY(y,m,d,   days) {
	if (!isInteger(y) || !isInteger(m) || !isInteger(d)) {
		error("funcs: Cal2DOY", "year, month and day must be integers")
	}
	if (m > 12 || m < 1 || d > 31 || d < 1) {
		print "Cal2DOY: Month or day not in correct range" > "/dev/stderr"
		exit 2
	}
	
	# Check leap year and set up array of days accordingly
	if (isLeap(y)) {
		days[0]=0    ; days[1]=31   ; days[2]=60  ; days[3]=91  ; days[4]=121
		days[5]=152  ; days[6]=182  ; days[7]=213 ; days[8]=244 ; days[9]=274
		days[10]=305 ; days[11]=335 ; days[12]=366
	} else {
		days[0]=0    ; days[1]=31   ; days[2]=59  ; days[3]=90  ; days[4]=120
		days[5]=151  ; days[6]=181  ; days[7]=212 ; days[8]=243 ; days[9]=273
		days[10]=304 ; days[11]=334 ; days[12]=365
	}
	
	# Check that day exists in that month
	if (d > days[m]-days[m-1]) {
		print "Cal2DOY: number of days "d" is longer than in month "m"." > "/dev/stderr"
		exit
	}
	
	# Return year day-of-year
	return d + days[m-1]
}

# Function which just returns the month from the DOY
function DOY2Month(y,d,   date) {
	date[1] = 0
	date[2] = 0
	date[3] = 0
	DOY2Cal(y,d,date)
	return date[2]
}

# Return just the day of the month from the DOY
function DOY2Day(y,d,   date) {
	date[1] = 0
	date[2] = 0
	date[3] = 0
	DOY2Cal(y,d,date)
	return date[3]
}

# Return the number of days between two dates.  The second date must be later than
# the first.
function daysSinceDate(y1,m1,d1,y2,m2,d2,   doy1,doy2,days,y) {
	if (y2 < y1 || (y2==y1 && m2<m1) || (y2==y1 && m2==m1 && d2<d1)) {
		print "daysSinceDate: Second date must be after the first" > "/dev/stderr"
		exit
	}
	doy1 = Cal2DOY(y1,m1,d1)
	doy2 = Cal2DOY(y2,m2,d2)
	if (y1 == y2) return doy2 - doy1
	days = (daysInYear(y1) - doy1) + doy2
	for (y=y1+1; y<y2; y++) days += daysInYear(y)
	return days
}

# Fill in the date array with the year, month and day given by the starting
# date, plus some offset in days
function dateAfterDays(y, m, d, days, date,   doy, k) {
	doy = Cal2DOY(y,m,d)
	if (days > 1) {
		for (k=1; k<=days; k++) {
			doy++
			if (doy > daysInYear(y)) {
				y++
				doy = 1
			}
		}
	} else {
		for (k=-1; k>=days; k--) {
			doy--
			if (doy == 0) {
				y--
				doy = daysInYear(y)
			}
		}
	}
	DOY2Cal(y,doy,date)
}

# Convert YYYYDDD to ISO format (YYYY-MM-DD)
function YYYYDDD2ISO(s,   date) {
	DOY2Cal(substr(s,1,4)+0, substr(s,5,3)+0, date)
	return sprintf("%04i-%02i-%02i", date[1], date[2], date[3])
}

##########
# Histogram functions
##########

# Fill two arrays, the first containing the low end of the bins,
# the second containing the counts within that bin, and
# return n, the number of bins.
function histogram(x, width, bins, hist,   n, min, max, i, j) {
	n = arrayLength(x)
	min = binMinimum(x, width)
	max = binMaximum(x, width)
	n = int((max-min)/width) + 1
	for (i=1; i<=n; i++) {
		bins[i] = min + width*(i-1)
		hist[i] = 0
		for (j in x) {
			if (x[j] >= bins[i] && x[j] < bins[i]+width) hist[i]++
		}
	}
	return n
}

# Create a histogram with percentage rather than counts
function histogramPercent(x, width, bins, hist,   s) {
	n = histogram(x, width, bins, hist)
	s = arraySum(x)
	if (s == 0) s = 1
	for (i=1; i<=n; i++) hist[i] *= 100/s
}

# Create a two-dimensional histogram from two arrays (x and y),
# given binwidths xw and yw, respectively.  hist is an array containing the counts
# at [ix,iy], xbins and ybins contain the lower bin edges, and N[1] contains the
# number of xbins, N[2] the number of ybins.
function histogram2d(x, y, xw, yw, xbins, ybins, hist, N,   \
		n, xmin, xmax, nx, ymin, ymax, ny, i, j, k) {
	n = arrayLength(x)
	if (arrayLength(y) != n) error("histogram2d", "x and y arrays not the same length")
	xmin = binMinimum(x, xw)
	xmax = binMaximum(x, xw)
	nx = int((xmax - xmin)/xw) + 1
	ymin = binMinimum(y, yw)
	ymax = binMaximum(y, yw)
	ny = int((ymax - ymin)/yw) + 1
	N[1] = nx
	N[2] = ny
	for (i=1; i<=nx; i++) {
		xbins[i] = xmin + xw*(i-1)
		for (j=1; j<=ny; j++) {
			ybins[j] = ymin + yw*(j-1)
			hist[i,j] = 0
			for (k=1; k<=n; k++) {
				if (x[k] >= xbins[i] && x[k] < xbins[i]+xw &&
					y[k] >= ybins[j] && y[k] < ybins[j]+yw) hist[i,j]++
			}
		}
	}
}

# Create a 2D histogram by percentage, not counts
function histogram2dPercent(x, y, xw, yw, xbins, ybins, hist, N,   s, i) {
	histogram2d(x, y, xw, yw, xbins, ybins, hist, N)
	s = arraySum(hist)
	if (s == 0) s = 1
	for (i in hist) hist[i] *= 100/s
}

# Return the minimum lower edge of a set of bins with width w,
# given an array of values, x.
function binMinimum(x, w,   min) {
	min = w*int(minval(x)/w)
	if (min < 0) min -= w
	return min
}

# Return the maximum lower edge of a set of bins with width w,
# given an array of values x.
function binMaximum(x, w,   max) {
	max = w*int(maxval(x)/w)
	if (max < 0) max -= w
	return max
}

# Print out an x-count representation of a histogram
function printHistogram(bins, hist,   n, w, i) {
	n = arrayLength(bins)
	w = bins[2] - bins[1]
	if (arrayLength(hist) != n) error("printHistogram", "histogram array is not the expected size")
	for (i=1; i<=n; i++) {
		print bins[i], hist[i]
	}
}

# Print out an x-y-count representation of a 2D histogram
function printHistogram2d(xbins, ybins, hist,   nx, ny, i, j) {
	nx = arrayLength(xbins)
	ny = arrayLength(ybins)
	for (j=1; j<=ny; j++) {
		for (i=1; i<=nx; i++) {
			print xbins[i], ybins[j], hist[i,j]
		}
	}
}
