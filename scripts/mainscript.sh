#!/bin/bash

# $1 = OUTPUT DIR
# $2 = GRAPH PDF NAME

OUTPUT_DIR="${1:-output}"
PDF_NAME="${2:-graphs.pdf}"

WASI_SDK_CLANG='/home/simon/repo/wasi-sdk/dist/wasi-sdk-20.20g2393be41c8df/bin/clang++ --sysroot=/home/simon/repo/wasi-sdk/dist/wasi-sdk-20.20g2393be41c8df/share/wasi-sysroot'
WASMTIME='/home/simon/.wasmtime/bin/wasmtime'
WASMER='/home/simon/.wasmer/bin/wasmer'
PROGRAM_CODE='code/rewrite.cpp'
OLD_CODE='code/latency.cpp'

[[ -f scripts/mainscript-custom.sh ]] && source scripts/mainscript-custom.sh

rm -rf bin
mkdir -p bin
g++ -Wall -pedantic -pthread -DGATHER_ALL "${PROGRAM_CODE}" -o bin/latency_no_prio
g++ -Wall -pedantic -pthread -DPOSIX_PRORITY_SETUP "${PROGRAM_CODE}" -o bin/latency_with_prio_cpp
g++ -Wall -pedantic -pthread -DGATHER_ALL -DPRIO "${OLD_CODE}" -o bin/latency_with_prio_posix
emcc -pthread -DGATHER_ALL "${PROGRAM_CODE}" -o bin/latency_emcc.js
${WASI_SDK_CLANG} -pthread --target=wasm32-wasi-threads -fno-exceptions -Wl,--import-memory,--export-memory,--max-memory=67108864 "${PROGRAM_CODE}" -o bin/latency.wasm

TEST_TIME_SEC=4
MICRO_TIME=$((TEST_TIME_SEC * 1000000))

rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"
sudo scripts/runscript.sh bin/latency_no_prio ${MICRO_TIME} "${OUTPUT_DIR}/out_no_prio" "${OUTPUT_DIR}/data_no_prio" 4
sudo scripts/runscript.sh bin/latency_with_prio_cpp ${MICRO_TIME} "${OUTPUT_DIR}/out_with_prio_cpp" "${OUTPUT_DIR}/data_with_prio_cpp" 4
sudo scripts/runscript.sh bin/latency_with_prio_posix ${MICRO_TIME} "${OUTPUT_DIR}/out_with_prio_posix" "${OUTPUT_DIR}/data_with_prio_posix" 4
sudo scripts/runscript.sh "node bin/latency_emcc.js" ${MICRO_TIME} "${OUTPUT_DIR}/out_node" "${OUTPUT_DIR}/data_node" 4
sudo scripts/runscript.sh "${WASMTIME} --wasm-features=threads --wasi-modules=experimental-wasi-threads bin/latency.wasm" ${MICRO_TIME} "${OUTPUT_DIR}/out_wasmtime" "${OUTPUT_DIR}/data_wasmtime" 4
sudo scripts/runscript.sh "${WASMER} bin/latency.wasm" ${MICRO_TIME} "${OUTPUT_DIR}/out_wasmer" "${OUTPUT_DIR}/data_wasmer" 4

mkdir -p graphs
python scripts/graphs.py "${OUTPUT_DIR}" "graphs/${PDF_NAME}"

rm hist.pdf
rm hist2.pdf