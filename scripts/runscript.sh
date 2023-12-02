#!/bin/bash

# $1 = PROGRAM NAME
# $2 = TEST DURATION
# $3 = OUTPUT DIR
# $4 = OUTPUT NAME
# $5 = CORE COUNT

TEMPFILE=$(mktemp)
POSSIBLE_OUTPUT_DIR=$(mktemp -d)
POSSIBLE_NAME=${RANDOM}

DEFAULT_DURATION="30000000"
PROGRAM=${1:-"a.out"}
DURATION="${2:-${DEFAULT_DURATION}}"
OUTPUT_DIR=${3:-${POSSIBLE_OUTPUT_DIR}}
NAME=${4:-${POSSIBLE_NAME}}
CORES=${6:-"4"}

OUTFILE_STATS="${OUTPUT_DIR}/stats_${NAME}"
OUTFILE_LATENCY="${OUTPUT_DIR}/latency_${NAME}"
OUTFILE_JITTER="${OUTPUT_DIR}/jitter_${NAME}"

[[ -f scripts/runscript-custom.sh ]] && source scripts/runscript-custom.sh

echo "tempfile - ${TEMPFILE}"
echo "Starting latency measure \"${PROGRAM}\" test for ${DURATION}us ($((DURATION/1000000))s)."
echo "Parsed data stored in $(realpath ${OUTFILE_STATS})."
echo "Latencies stored in $(realpath ${OUTFILE_LATENCY})"
echo "Jitter stored in $(realpath ${OUTFILE_JITTER})"
echo "Running \"${PROGRAM} 4 ${DURATION} > ${TEMPFILE} &\""
${PROGRAM} 4 "${DURATION}" > ${TEMPFILE} &
sleep 1
sudo chrt -f -a -p 80 $(ps -ef | grep "[0-9] ${PROGRAM}" | awk '{print $2}')
wait
grep 'T: *\([0-9]*\) *( *\([0-9]*\) *) P: *\([0-9]*\) *I: *\([0-9]*\) *C: *\([0-9]*\) *Min: *\([0-9]*\) *Act: *\([0-9]*\) *Avg: *\([0-9]*\) *Max: *\([0-9]*\)' "${TEMPFILE}" | sed 's|T: *\([0-9]*\) *( *\([0-9]*\) *) P: *\([0-9]*\) *I: *\([0-9]*\) *C: *\([0-9]*\) *Min: *\([0-9]*\) *Act: *\([0-9]*\) *Avg: *\([0-9]*\) *Max: *\([0-9]*\)|\1;\2;\3;\4;\4;\6;\7;\8;\9|g' > ${OUTFILE_STATS}
grep 'LATENCY_DATA' "${TEMPFILE}" | sed 's|.*LATENCY_DATA: ;||g' | sed -z 's|\n|;|g;s|;$|\n|' > ${OUTFILE_LATENCY}
grep 'JITTER_DATA' "${TEMPFILE}" | sed 's|.*JITTER_DATA: ;||g' | sed -z 's|\n|;|g;s|;$|\n|' > ${OUTFILE_JITTER}
chmod aug+rw "${OUTFILE_STATS}"
chmod aug+rw "${OUTFILE_LATENCY}"
chmod aug+rw "${OUTFILE_JITTER}"
echo "Finished"
echo ""
