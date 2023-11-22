#!/bin/bash

# $1 = PROGRAM NAME
# $2 = TEST DURATION
# $3 = OUTPUT FILE NAME STAT
# $4 = OUTPUT FILE NAME DATA
# $5 = CORE COUNT

TEMPFILE=$(mktemp)
DEFAULT_DURATION="30000000"
PROGRAM=${1:-"a.out"}
DURATION="${2:-${DEFAULT_DURATION}}"
POSSIBLEOUT_STATS=$(mktemp)
POSSIBLEOUT_DATA=$(mktemp)
OUTFILE_STATS=${3:-${POSSIBLEOUT_STATS}}
OUTFILE_DATA=${4:-${POSSIBLEOUT_DATA}}
CORES=${5:-"4"}

[[ -f scripts/runscript-custom.sh ]] && source scripts/runscript-custom.sh

echo "Starting latency measure \"${PROGRAM}\" test for ${DURATION}us ($((DURATION/1000000))s)."
echo "Parsed data stored in $(realpath ${OUTFILE_STATS})."
echo "Raw stored in $(realpath ${OUTFILE_DATA})"
${PROGRAM} 4 "${DURATION}" > ${TEMPFILE} &
sleep 1
sudo chrt -f -a -p 80 $(ps -ef | grep "[0-9] ${PROGRAM}" | awk '{print $2}')
wait
grep 'T: *\([0-9]*\) *( *\([0-9]*\) *) P: *\([0-9]*\) *I: *\([0-9]*\) *C: *\([0-9]*\) *Min: *\([0-9]*\) *Act: *\([0-9]*\) *Avg: *\([0-9]*\) *Max: *\([0-9]*\)' "${TEMPFILE}" | sed 's|T: *\([0-9]*\) *( *\([0-9]*\) *) P: *\([0-9]*\) *I: *\([0-9]*\) *C: *\([0-9]*\) *Min: *\([0-9]*\) *Act: *\([0-9]*\) *Avg: *\([0-9]*\) *Max: *\([0-9]*\)|\1;\2;\3;\4;\4;\6;\7;\8;\9|g' > ${OUTFILE_STATS}
grep ', DATA' "${TEMPFILE}" | sed 's|.*DATA;||g' > ${OUTFILE_DATA}
chmod aug+rw "${OUTFILE_STATS}"
chmod aug+rw "${OUTFILE_DATA}"
echo "Finished"
echo ""
# echo "Run cyclic test for ${DURATION}. Parsed data stored in $(realpath ${OUTFILE_STATS}). Raw stored in $(realpath ${OUTFILE_DATA})"
# cat "${OUTFILE_STATS}"
