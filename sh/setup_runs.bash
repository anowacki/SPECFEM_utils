#!/bin/bash
# Utility script to setup a new folder for a SPECFEM3D_GLOBE run.
# This creates a new folder, sets up the required links and folders inside
# it and also makes some scripts for running the simulation.
#
# This is useful to maintain separate subdirectories, each with its own Par_file,
# CMTSOLUTION and STATIONS file so that individual runs can be saved for later
# re-running or analysis.  I typically use a folder called 'RUNS' inside the
# SPECFEM3D_GLOBE base directory, and can therefore simulataneously run several
# different simulations by copying the binaries over to the subdirectory.  This
# approach is taken from the EXAMPLES directory.
#
# This script creates a default set of inputs, which can be edited to suit.  Change
# the parameters below these comments for your situtation on ARCHER, if you use
# that machine.
#
# It also creates a default script to submit to a PBS queuing system
# (go_mesher_solver_pbs.bash) and one to compile and copy over the executables
# (process.sh).  Running process.sh without an argument automatically submits
# the jobs to the queuing system, but the go_mesher_solver_pbs.bash script will
# require editing to match your Par_file.  The process.sh script uses locking
# to prevent simultaneous compilation of different binaries.
#
# Andy Nowacki, University of Leeds

################################################################################
# MACHINE-SPECIFIC VARIABLES
ppn_hector=32 ppn_archer=24 ppn_typhon=48  ppn_bcp2=16 # Processors per node
ppn[archer]=24
ppn[typhon]=48
################################################################################

################################################################################
# RUN DEFAULTS
MODEL=1D_isotropic_prem
NCHUNKS=1
NEX=240
NPROC=5
CHUNK_LON=0.0
CHUNK_LAT=0.0
CHUNK_ROT=0.0
CHUNK_WIDTH=90.0
RUNTIME=30.0
WALLTIME=24:00:00
unset MERGED
OCEANS=".false."
ELLIPTICITY=".false."
TOPOGRAPHY=".false."
GRAVITY=".false."
ROTATION=".false."
ATTENUATION=".true."
# SCRIPT DEFAULTS
JOB_SCRIPT="go_mesher_solver_pbs.bash"
################################################################################

# Print out usage and exit with error
usage () {
	cat <<-END >&2
	$(basename $0): Create a new directory for a SPECFEMF3D_GLOBE run
	
	Usage: $(basename $0) (options) [name]
	
	Pre-defined input files:
	   -Par [Par_file] : Use specified Par_file
	   -CMT [CMTSOLUTION file] : Use specified CMTSOLUTION file
	   -STA [STATIONS] : Use specified STATIONS file
	   
	Run options [defaults]:
	   -c [NCHUNKS]  : Number of chunks [$NCHUNKS]
	   -chunk [lon lat angle] : Set longitude, latitude and angle clockwise
	                   away from east of first chunk [$CHUNK_LON $CHUNK_LAT $CHUNK_ROT]
	   -e [NEX]      : Number of spectral elements per side [$NEX]
	   -m            : Make run for merged mesher and solver [separate]
	   -n [NPROC]    : Number of processes per side [$NPROC]
	   -N [jobname]  : Name of job in queue [same as 'name']
	   -path [dir]   : Location of MPI mesh files [chosen according to machine]
	   -t [mins]     : Simulation time in minutes [$RUNTIME]
	   -w [hh:mm:ss] : Walltime [$WALLTIME]
	
	Model options [defaults]:
	   -mod [model]  : Earth model [$MODEL]
	   -att          : Include effect of attenuation [off]
	   -ell          : Include effect ellipticity [off]
	   -grav         : Include effect of graviry [off]
	   -oceans       : Include effect of oceans [off]
	   -rot          : Include effect of rotation [off]
	   -topo         L Include effect of topography [off]
	END
	exit 1
}

# Functions which return numbers in the desired form, safe to append "d0" if floats
check_int () {
	[ $# -ne 1 ] && { echo "check_int: Error: Supply one argument." >&2; return 1; }
	printf "%d" "$1" 2>/dev/null ||
		{ echo "check_int: Can't get integer from argument \"$1\""; usage; }
}
check_float () {
	[ $# -ne 1 ] && { echo "check_float: Error: Supply one argument." >&2; return 1; }
	printf "%f" "$1" 2>/dev/null ||
		{ echo "check_float: Can't get decimal number from argument \"$1\""; usage; }
}
process_walltime () {
	[ $# -ne 1 ] && { echo "process_walltime: Error: Supply one argument." >&2; return 1; }
	[ "$1" = "${1//:/}" ] && echo "$1:00:00" && return
	[[ "$1" = ??:??:?? ]] || { echo "Please enter walltime in the form hh:mm:ss" >&2; exit 1; }
	printf "%d" "${1:0:2}" &>/dev/null && printf "%d" "${1:3:2}" &>/dev/null &&
		printf "%d" "${1:6:2}" &>/dev/null && echo "$1" ||
		{ echo "Please enter walltime in the form hh:mm:ss" >&2; exit 1; }
}
check_file () {
	# Make sure paths don't contain any special characters (spaces for now)
	[ $# -ne 1 ] && { echo "check_file: Error: Supply one argument.">&2; return 1; }
	if [[ "$1" =~ [\ \!\?\@\$\%\^\&\*\(\)] ]]; then
		echo "Paths cannot contain any strange characters" >&2; exit 1
	else
		echo "$1"
	fi
}
check_file_exists () {
	[ -r "$1" ] || { echo "check_file_exists: Error: Cannot read file \"$1\"";
		exit 1; }
	echo "$1"
}
# If a Par_file is defined, then warn that the option will be ignored
# Accepts one argument: name of option being defined
check_Par_file () {
	[ "$PAR_FILE" ] && {
		echo "Warning: Par_file is being used, so ignoring option $1"; return 1; }
}
# Get a variable from a Par_file
get_Par_file_var () {
	if [ $# -ne 2 ]; then
		echo "get_Par_file_var: Error: Usage: get_Par_file_var [Par_file] [varname]" >&2
		exit 1
	fi
	grep -e "^\s*$2\s*=" "$1" | awk '{print $3}'
}
# Cat the current SPECFEM3D_GLOBE version's Par_file
cat_Par_file () {
	git show HEAD:DATA/Par_file || { echo "cat_Par_file: Cannot cat DATA/Par_file" >&2; return 1; }
}

# Get a default value from the 'defaults' file in the directory above this
# Accepts one argument: name of variable
get_default () {
	[ -f "$DEFAULTS_FILE" ] ||
		{ echo "get_default: Cannot find defaults file at '$DEFAULTS_FILE'" >&2; exit 1; }
	local var
	var=$(grep -e "^\s*$1\s*=" "$DEFAULTS_FILE") ||
		{ echo "get_default: Cannot find variable '$1' in defaults file '$DEFAULTS_FILE'" >&2; exit 1; }
	echo "$var" | awk -F'=' '{print $2}' | awk '{print $1}'
}

################################################################################
# PATH TO SCRIPT
SCRIPTPATH="$(cd "$(dirname "$0")"; pwd -P)"
################################################################################
# VARIABLES SAVED ON DISK
DEFAULTS_FILE="$SCRIPTPATH/../defaults"

BUDGET=$(get_default archer_budget) # Budget to charge AUs to on ARCHER
EMAIL=$(get_default email)          # Email address
################################################################################

# Get arguments
[ $# -eq 0 ] && usage
while [ -n "$1" ]; do
	case "$1" in
		# Run options
		-Par*)  PAR_FILE=$(check_file_exists "$2"); shift 2 ;;
		-CMT*)  CMTSOLUTION=$(check_file_exists "$2"); shift 2 ;;
		-STA*)  STATIONS=$(check_file_exists "$2"); shift 2 ;;
		-c)     NCHUNKS=$(check_int $2); check_Par_file "-c"; shift 2 ;;
		-chunk) CHUNK_LON=$(check_float $2); CHUNK_LAT=$(check_float $3)
		        CHUNK_ROT=$(check_float $4); check_Par_file "-chunk"; shift 4 ;;
		-e)     NEX=$(check_int $2); check_Par_file "-e"; shift 2 ;;
		-m)     MERGED=1; check_Par_file "-m"; shift ;;
		-N)     JOBNAME="$2"; shift 2 ;;
		-n)     NPROC=$(check_int $2); check_Par_file "-n"; shift 2 ;;
		-path)  LOCAL_PATH=$(check_file "$2"); check_Par_file "-path"; shift 2 ;;
		-t)     RUNTIME=$(check_float $2); check_Par_file "-t"; shift 2 ;;
		-w)     WALLTIME=$(process_walltime "$2"); shift 2 ;;
		# Model options
		-mod)    MODEL="$2"; check_Par_file "-mod"; shift 2 ;;
		-att)    ATTENUATION=".true."; shift ;;
		-ell)    ELLIPTICITY=".true."; shift ;;
		-grav)   GRAVITY=".true."; shift ;;
		-oceans) OCEANS=".true."; shift ;;
		-rot)    ROTATION=".true."; shift ;;
		-topo)   TOPOGRAPHY=".true."; shift ;;
		
		*)      [ $# -ne 1 ] && echo "Unrecognised option \"$1\"" >&2 && usage
		        NAME=$(check_file "$1"); break ;;
	esac
done



# Make sure we actually supplied a name, which wouldn't be caught by the above
[ $# -ne 1 ] &&
	{ echo "$(basename $0): Error: Supply name of run directory as final argument"; exit 1; }

# Jobname is the same as directory name unless otherwise requested.
[ "$JOBNAME" ] || JOBNAME="$NAME"

# Test that we're being run one level down from a SPECFEM3D_GLOBE installation
if ! [ -d ../DATA -a \
       -d ../src/specfem3D -a \
       -d ../src/meshfem3D -a \
       -d ../src/shared ]; then
	{ echo "$(basename $0): Error: Can't find the necessary SPECFEM3D_GLOBE files"
	  printf "Run this script one level down from a SPECFEM3D_GLOBE "
	  echo "installation (e.g., in a subdirectory called 'RUNS')"; } > /dev/stderr
	exit 2
fi

# See whether we've been configured
if  ! [ -f ../config.log ]; then
	echo "$(basename $0): Error: SPECFEM3D_GLOBE has not been configured yet." >&2
	exit 2
fi

# Check that this name doesn't already exist
if [ -d "$NAME" ]; then
	echo "Directory $NAME already exists.  $(basename $0) will not overwrite." >&2
	exit 3
fi

# Default is to have same number of processors in each direction of the chunks
NPROC_XI=$NPROC NPROC_ETA=$NPROC

# If using a predefined Par_file, get some of these variables from there
if [ "$PAR_FILE" ]; then
	NCHUNKS=$(get_Par_file_var "$PAR_FILE" NCHUNKS)
	NPROC_XI=$(get_Par_file_var "$PAR_FILE" NPROC_XI)
	NPROC_ETA=$(get_Par_file_var "$PAR_FILE" NPROC_ETA)
fi

# Check if merged version being used without correct configuration
if grep -q -- "--enable-merged" ../config.log; then
	! [ "$MERGED" ] && {
		echo "***"
		echo "Warning: Code is configured for merged mesher-solver, but the -m flag not set."
		echo "Reconfigure the code to allow merged meshing and solving before running \`process.sh\`."
		echo "***"
	} >&2
else
	[ "$MERGED" ] && {
		echo "***"
		echo "Warning: Code is configured for separate mesher and solver, but the -m flag was set."
		echo "Reconfigure the code to allow merged meshing and solving before running \`process.sh\`."
		echo "***"
	} >&2
fi

# Total number of processes
nprocs=$((NCHUNKS * NPROC_XI * NPROC_ETA))

##########################
# Decide whether we're running on Archer or Typhon, or otherwise, and set
# some strings which depend on this accordingly
host=$(hostname | awk 'BEGIN {h="unknown"}
						/eslogin/         {h = "archer"}
						/polaris/         {h = "polaris"}
						/typhon/ || /t-0/ {h = "typhon"}
						/bigblue/         {h = "bluecrystal"}
					END {print h}')
if [ "$host" = "archer" ]; then
	# On ARCHER, we use Cray's aprun command
	runmesher="aprun -n \$numnodes -N \$N \$PWD/bin/xmeshfem3D"
	runsolver="aprun -n \$numnodes -N \$N \$PWD/bin/xspecfem3D"
	runmeshersolver="aprun -n \$numnodes -N \$N \$PWD/bin/xspecfem3D"
	# ARCHER nodes have no disk attached, so use PWD for scratch space
	[ -z "$LOCAL_PATH" ] && LOCAL_PATH=./DATABASES_MPI
	PBS_mail_line="#PBS -m ae
#PBS -M ${EMAIL}
#PBS -A ${BUDGET}"
	procs_per_node=$ppn_archer
	PBS_procs_line="#PBS -l select=$(( (nprocs + procs_per_node - 1)/procs_per_node ))"
else
	runmesher="mpiexec -np \$numnodes -machinefile \$confile \$PWD/bin/xmeshfem3D"
	runsolver="mpiexec -np \$numnodes -machinefile \$confile \$PWD/bin/xspecfem3D"
	runmeshersolver="mpiexec -np \$numnodes -machinefile \$confile \$PWD/bin/xspecfem3D"
	if [ $host = typhon ]; then
		# Typhon has disks with a /tmp/ directory world-writeable
		[ -z "$LOCAL_PATH" ] && LOCAL_PATH=/tmp/$USER/$NAME/DATABASES_MPI
		procs_per_node=$ppn_typhon
	elif [ $host = bluecrystal ]; then
		# BlueCrystal's nodes have scratch space in /local/
		[ -z "$LOCAL_PATH" ] && LOCAL_PATH=/local/$USER/$NAME/DATABASES_MPI
		procs_per_node=$ppn_bcp2
	else
		# Otherwise, safest to assume that we should write to local space
		[ -z "$LOCAL_PATH" ] && LOCAL_PATH=./DATABASES_MPI
		procs_per_node=1
	fi
	PBS_mail_line="#PBS -m ae"
	nodes=$((nprocs/procs_per_node)) # Rounded down
	if [ $nprocs -le $procs_per_node ]; then
		PBS_procs_line="#PBS -l nodes=1:ppn=$nprocs"
	elif [ $((nprocs%procs_per_node)) -eq 0 ]; then
		PBS_procs_line="#PBS -l nodes=$nodes:ppn=$procs_per_node"
	else
		PBS_procs_line="PBS -l nodes=$nodes:ppn=$procs_per_node+1:ppn=$((nprocs%procs_per_node))"
	fi
fi


##########################
# Make directory structure
curdir=$PWD
mkdir -p "$NAME"/OUTPUT_FILES \
		"$NAME"/bin \
		"$NAME"/DATA
[ "${LOCAL_PATH:0:2}" = "./" ] && mkdir -p "$NAME"/"$LOCAL_PATH"
(cd "$NAME"/DATA &&
for file in ../../../DATA/*; do
	[ -d "$file" ] && ln -s "$file"
done
) || { echo "Could not change into run directory at \"$NAME\"/DATA" >&2; exit 2; }

##########################
# Make input files
# Make CMTSOLUTION file
if [ "$CMTSOLUTION" ]; then
	cp "$CMTSOLUTION" "$NAME"/DATA/CMTSOLUTION
else
	# Default: N-S-striking thrust fault, dip 45 deg, Mw 7 at (lon,lat) = (0,0)
	cat <<-END > "$NAME"/DATA/CMTSOLUTION
	PDE 2000  1  1  0  0  0.00   0.0000    0.0000 100.0 7.0 7.0 NPOLE
	event name:     EXAMPLE
	time shift:      0.0000
	half duration:   0.0000
	latitude:        0.0000
	longitude:       0.0000
	depth:         100.0000
	Mrr:       0.398107E+27
	Mtt:      -0.000000E+00
	Mpp:      -0.398107E+27
	Mrt:      -0.172372E+11
	Mrp:      -0.243770E+11
	Mtp:      -0.172372E+11
	END
fi

# Make stations file
if [ "$STATIONS" ]; then
	cp "$STATIONS" "$NAME"/DATA/STATIONS
else
	d=5 # degrees spacing
	for ((lon=-180; lon<180; lon+=$d)); do
		for ((lat=$[90-$d]; lat>=-$[90-$d]; lat-=$d)); do
			printf "S%03d_%03d AN %6.1f %6.1f 0.0 0.0\n" $lon $lat $lat $lon
		done
	done > "$NAME"/DATA/STATIONS
	printf "S%03d_%03d AN %6.1f %6.1f 0.0 0.0\n" 0  90  90 0 >> "$NAME"/DATA/STATIONS
	printf "S%03d_%03d AN %6.1f %6.1f 0.0 0.0\n" 0 -90 -90 0 >> "$NAME"/DATA/STATIONS
fi

# Use absorbing conditions unless using the whole Earth
[ $NCHUNKS -eq 1 -o $NCHUNKS -eq 2 ] && ABSORBING_CONDITIONS=".true." || ABSORBING_CONDITIONS=".false."

# Par_file
if [ "${PAR_FILE}" ]; then
	cp "${PAR_FILE}" "$NAME"/DATA/Par_file
else
	# Make default Par_file by replacing some variables
	### NOTE: This defines a 'unique' directory for the meshfiles if we're running ###
	### on Typhon or another machine that's not Hector.  Be careful.               ###
	{ cat_Par_file || exit 1; } | awk '
	# Write a SPECFEM3D_GLOBE Par_file line that begins with name, setting its value to var,
	# and replacing the line that exists in the file
	function rep(name, var,   r) {
		r = "^\s*"name" *="
		if ($0 ~ r) {
			printf("%-32s= %s\n", $1, var)
			# print "Replacing",name,"with",var > "/dev/stderr"
			return 1
		}
		return 0
	}
	{
		# Run options
		if (rep("NCHUNKS", "'"$NCHUNKS"'") ||
		    rep("NEX_XI", "'"$NEX"'") ||
		    rep("NEX_ETA", "'"$NEX"'") ||
		    rep("NPROC_XI", "'"$NPROC_XI"'") ||
		    rep("NPROC_ETA", "'"$NPROC_ETA"'") ||
		    rep("ANGULAR_WIDTH_XI_IN_DEGREES", "'"$CHUNK_WIDTH"'") ||
		    rep("ANGULAR_WIDTH_ETA_IN_DEGREES", "'"$CHUNK_WIDTH"'") ||
		    rep("CENTER_LATITUDE_IN_DEGREES", "'"$CHUNK_LAT"'") ||
		    rep("CENTER_LONGITUDE_IN_DEGREES", "'"$CHUNK_LON"'") ||
		    rep("ABSORBING_CONDITIONS", "'"$ABSORBING_CONDITIONS"'") ||
		    rep("RECORD_LENGTH_IN_MINUTES", "'"$RUNTIME"'") ||
		    rep("LOCAL_PATH", "'"$LOCAL_PATH"'") ||
		# Model options
		    rep("MODEL", "'"$MODEL"'") ||
		    rep("ATTENUATION", "'"$ATTENUATION"'") ||
		    rep("ELLIPTICITY", "'"$ELLIPTICITY"'") ||
		    rep("GRAVITY", "'"$GRAVITY"'") ||
		    rep("OCEANS", "'"$OCEANS"'") ||
		    rep("ROTATION", "'"$ROTATION"'") ||
		    rep("TOPOGRAPHY", "'"$TOPOGRAPHY"'")) {
			next
		}
		
		print
	}
	' > "$NAME"/DATA/Par_file
fi

#################################################################################
# Make default script to process and submit job
if [ $MERGED ]; then
	required_binaries="bin/xcreate_header_file bin/xspecfem3D"
	make_clean="make clean"
	make="make xspecfem3D"
else
	required_binaries="bin/xcreate_header_file bin/xmeshfem3D bin/xspecfem3D"
	make_clean="make clean"
	make="make xmeshfem3D xspecfem3D"
fi

cat <<END > "$NAME"/process.sh
#!/bin/bash
# General processing script to make SPECFEM3D and submit the job script.
##################################################

# Don't submit job if we supply an argument
if [ \$# -ne 0 ]; then
   echo "Invoked with option \"\$1\".  Not submitting job"
   nosub=1
fi

currentdir=\$(pwd)

# sets up directory structure in current directoy
echo -n "   Removing previous output... "

mkdir -p OUTPUT_FILES
rm -rf OUTPUT_FILES/*

echo "done"

# compiles executables in root directory
i=1
while [ \$i -le 5 ]; do
	if [ ! -e ../../.compiling ]; then  # Test for existence of lock file
		# Create lock file and trap ^C so we don't leave it there
		touch ../../.compiling
		trap '{ echo Received SIGINT, removing lock file.; rm \$currentdir/../../.compiling; exit 1; }' SIGINT

		cp DATA/Par_file ../../DATA/
		cd ../..
		
		echo -n "   Saving code status... "
		git rev-parse --is-inside-work-tree >/dev/null 2>&1 &&
		    { git show
			  git diff -- . ':(exclude)DATA/Par_file' ':(exclude)DATA/CMTSOLUTION' ':(exclude)DATA/STATIONS'
		    } > \$currentdir/commit
		echo "done"
		
		echo -n "   Compiling in root directory... "
		{ ${make_clean} >/dev/null &&
		  ${make}; } &> \$currentdir/make.log ||
			{ echo -e "\nFailed to compile SPECFEM3D.  See make.log for more details" ; rm \$currentdir/../../.compiling; exit 1 ; }

		# Copy executables into working directory
		cp ${required_binaries} \$currentdir/bin/

		# Backup of constants setup
		cp setup/* \$currentdir/OUTPUT_FILES/

		# Delete lock file and remove interrupt trap
		rm -f .compiling
		trap - SIGINT

		# Change back to working directory
		echo "done"
		cd \$currentdir

		# submits job to run mesher & solver, unless we've requested otherwise
		if [ -z "\$nosub" ]; then
		   echo -n "   Submitting script... "
		   jobid=\$(qsub "$JOB_SCRIPT")
		   echo "job: \$jobid"

		   echo -n "All done:  "
		   echo \$(date)
		else
           echo "Job not submitted.  Use \"qsub $JOB_SCRIPT\" to run job."
		fi

		exit 0

# If lock file present, wait 10 seconds and try again.  Do this up to 5 times...
	else
		j=20; while [ \$j -gt 0 ]; do
			echo -e -n "\rLock file present in root SPECFEM3D directory.  Waiting \$j seconds...  "
			sleep 1
			j=\$[\$j-1]
		done
		echo
		i=\$[\$i+1]
	fi
done

echo "Lock file still present.  If another process is not making SPECFEM3D, try removing ../../.compiling" > /dev/stderr
exit 1
END
chmod +x "$NAME"/process.sh

#################################################################################
# Make default PBS job script
cat <<END > "$NAME/$JOB_SCRIPT"
#!/bin/bash
#PBS -S /bin/bash
#PBS -N $JOBNAME
#PBS -j oe
#PBS -o OUTPUT_FILES/job.o
${PBS_mail_line}
${PBS_procs_line}
#PBS -l walltime=${WALLTIME}

###########################################################

# Change to directory of script
cd "\$PBS_O_WORKDIR"

# Temporary mesh file location
BASEMPIDIR=\$(awk '/^ *LOCAL_PATH *=/{print \$3}' DATA/Par_file)

# Compute number of nodes from Par_file
NPROC_XI=\$(awk '/^ *NPROC_XI *=/{print \$3}' DATA/Par_file)
NPROC_ETA=\$(awk '/^ *NPROC_ETA *=/{print \$3}' DATA/Par_file)
NCHUNKS=\$(awk '/^ *NCHUNKS *=/{print \$3}' DATA/Par_file)
numnodes=\$((\$NCHUNKS * \$NPROC_XI * \$NPROC_ETA))

mkdir -p OUTPUT_FILES

# Backup files used for this simulation
cp DATA/Par_file OUTPUT_FILES/
cp DATA/STATIONS OUTPUT_FILES/
cp DATA/CMTSOLUTION OUTPUT_FILES/

# Save node information
cat \$PBS_NODEFILE > OUTPUT_FILES/compute_nodes
echo "\$PBS_JOBID" > OUTPUT_FILES/jobid

END

if [[ $host != hector && $host != archer ]]; then  # Create the machinefile if running on Typhon
	cat <<-END >> "$NAME/$JOB_SCRIPT"
	# Set up machine files
	export nodes=\`cat \$PBS_NODEFILE\`
	export nnodes=\`cat \$PBS_NODEFILE | wc -l\`
	mkdir -p \$HOME/machinefiles
	export confile=\$HOME/machinefiles/inf.\$PBS_JOBID.conf

	for i in \$nodes; do
	   echo \${i} >> \$confile
	done

	# Set up the BASEMPIDIR if it's local to the nodes
	if [[ "\${BASEMPIDIR:0:1}" == "/" ]]; then
	   echo -n "Creating directory for mesh files on nodes at \$BASEMPIDIR... "
	   for n in \`sort -u < \$PBS_NODEFILE\`; do
	      ssh \$n "mkdir -p \$BASEMPIDIR" ||\\
	         { echo -e "\nPar_file specifies a path local to the nodes, but we can't set it up."; exit 1; }
	   done
	   echo "Done."
	fi

	END
else  # Automatically calculate mppnppn for HECToR
	cat <<-END >> "$NAME/$JOB_SCRIPT"
	# Setup BASEMPIDIR
	mkdir -p \$BASEMPIDIR

	# Processors per node must be \$numnodes if less than ${procs_per_node}
	N=\$(echo \$numnodes | awk '{if(\$1<${procs_per_node}) print \$1; else print ${procs_per_node}}')

	END
fi

if [ $MERGED ]; then
	cat <<-END >> "$NAME/$JOB_SCRIPT"
	##
	## Run merged mesher and solver
	##
	sleep 2
	echo "\$(date): starting merged mesher and solver on \$numnodes processors"
	echo
	
	$runmeshersolver &&
	    echo "\$(date): mesher and solver done" ||
	    echo "\$(date): FAILED"
	
	END
else
	cat <<-END >> "$NAME/$JOB_SCRIPT"
	##
	## mesh generation
	##
	sleep 2

	echo
	echo "\$(date): starting mesher on \$numnodes processors"

	$runmesher &&
	    echo "\$(date): mesher done" ||
	    echo "\$(date): MESHER FAILED"

	##
	## forward simulation
	##
	sleep 20

	echo
	echo "\$(date): starting solver"

	$runsolver &&
	    echo "\$(date): solver done" ||
	    echo "\$(date): SOLVER FAILED"

	echo

	END
fi

if [[ $host != hector && $host != archer ]]; then # Remove local mesh files from nodes
	cat <<-END >> "$NAME/$JOB_SCRIPT"
	# Clear out mesh files on local nodes
	if [[ "\${BASEMPIDIR:0:1}" == "/" ]]; then
	   # How much room did the meshfiles use up?
	   echo -n "Mesh files took up "
	   for n in \$(sort -u < \$PBS_NODEFILE); do
	      echo "node \$n"
	      ssh \$n "du -ks \$BASEMPIDIR 2>/dev/null" 2>/dev/null
	   done | awk '\$1!="node"{s+=\$1}END{printf("%0.3f GB\n",s/1024^2)}'

	   # Remove the mesh files
	   echo -n "Removing mesh files from nodes...  "
	   for n in \$(sort -u < \$PBS_NODEFILE); do
	      ssh \$n "rm -rf \$BASEMPIDIR" 2>/dev/null ||\\
	         { echo -e "\nFailed to remove mesh files from directories local to nodes" ; exit 1 ; }
	   done && echo "Done"
	fi

	echo "Finished"
	exit 0

	END
fi

if [[ $host == hector || $host == archer ]]; then  # Remove DATABASES_MPI in the run as it takes so long
	cat <<-END >> "$NAME/$JOB_SCRIPT"
	# Remove database files
	GBused=\$(du -cks \$BASEMPIDIR/proc000000* | tail -n 1 | awk -v n=\$numnodes '{print \$1*n/1024^2}')
	echo "Mesh files took up \$GBused GB"
	echo -n "Removing mesh files from workspace...  "
	rm -r \$BASEMPIDIR &&
	    echo "Done" ||
	    echo "Failed to remove mesh files"

	echo "Finished"
	exit 0

	END
fi


# Make this file executable
chmod +x "$NAME/$JOB_SCRIPT"
