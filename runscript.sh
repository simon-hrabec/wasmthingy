#!/bin/bash

TEMPFILE=$(mktemp)
DEFAULT_DURATION="30000000"
PROGRAM=${1:-"a.out"}
DURATION="${2:-${DEFAULT_DURATION}}"
POSSIBLEOUT=$(mktemp)
OUTFILE=${3:-${POSSIBLEOUT}}
CORES=${4:-"4"}
echo "Starting latency measure test for ${DURATION}. Parsed data stored in $(realpath ${OUTFILE})"
./${PROGRAM} 4 "${DURATION}" > ${TEMPFILE}
grep 'T: *\([0-9]*\) *( *\([0-9]*\) *) P: *\([0-9]*\) *I: *\([0-9]*\) *C: *\([0-9]*\) *Min: *\([0-9]*\) *Act: *\([0-9]*\) *Avg: *\([0-9]*\) *Max: *\([0-9]*\)' "${TEMPFILE}" | sed 's|T: *\([0-9]*\) *( *\([0-9]*\) *) P: *\([0-9]*\) *I: *\([0-9]*\) *C: *\([0-9]*\) *Min: *\([0-9]*\) *Act: *\([0-9]*\) *Avg: *\([0-9]*\) *Max: *\([0-9]*\)|\1;\2;\3;\4;\4;\6;\7;\8;\9|g' > ${OUTFILE}
chmod aug+rw "${OUTFILE}"
echo "Run cyclic test for ${DURATION}. Parsed data stored in $(realpath ${OUTFILE})"
cat "${OUTFILE}"