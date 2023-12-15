#!/bin/bash

# $1 = OUTPUT DIR
# $2 = GRAPH PDF NAME
# $3 = TEST TIME - SECONDS
# $4 = CORE COUNT

DEFAULT_TEST_TIME_SEC="4"
DEFAULT_CORE_COUNT="4"

OUTPUT_DIR="${1:-output}"
PDF_NAME="${2:-graphs.pdf}"
TEST_TIME_SEC="${3:-${DEFAULT_TEST_TIME_SEC}}"
MICRO_TIME=$((TEST_TIME_SEC * 1000000))
CORE_COUNT="${4:-${DEFAULT_CORE_COUNT}}"

ARCH="$(dpkg --print-architecture)"
WASI_SDK_CLANG='/home/simon/repo/wasi-sdk/dist/wasi-sdk-20.20g2393be41c8df/bin/clang++'
WASI_SDK_SYSROOT='--sysroot=/home/simon/repo/wasi-sdk/dist/wasi-sdk-20.20g2393be41c8df/share/wasi-sysroot'
WASMTIME='/home/simon/.wasmtime/bin/wasmtime'
WASMER='/home/simon/.wasmer/bin/wasmer'
PROGRAM_CODE='code/rewrite.cpp'
OLD_CODE='code/latency.cpp'
NODE="$(which node)"
WAMRC="$(which wamrc)"
WAMR="$(which iwasm)"

[[ -f scripts/mainscript-custom.sh ]] && source scripts/mainscript-custom.sh

rm -rf bin
mkdir -p bin
g++ -Wall -pedantic -pthread -std=c++17 -DPRIO "${OLD_CODE}" -o bin/latency_original_posix_with_prio
g++ -Wall -pedantic -pthread -std=c++17 "${PROGRAM_CODE}" -o bin/latency_rewrite_no_prio
g++ -Wall -pedantic -pthread -std=c++17 -DPOSIX_PRORITY_SETUP "${PROGRAM_CODE}" -o bin/latency_rewrite_with_posix_prio

emcc -pthread -DGATHER_ALL -sINITIAL_MEMORY=268435456 "${PROGRAM_CODE}" -o bin/latency_emcc.js

if [ -f "${WASI_SDK_CLANG}" ]; then
   ${WASI_SDK_CLANG} ${WASI_SDK_SYSROOT} -pthread --target=wasm32-wasi-threads -fno-exceptions -Wl,--import-memory,--export-memory,--max-memory=67108864 "${PROGRAM_CODE}" -o artifacts/latency.wasm
fi
cp artifacts/latency.wasm bin/latency.wasm

if [ -f "${WAMRC}" ]; then
	${WAMRC} --enable-multi-thread -o bin/latency.aot bin/latency.wasm
	${WAMRC} --enable-multi-thread --target=aarch64v8 -o artifacts/latency-arm.aot bin/latency.wasm
else
	cp artifacts/latency-arm.aot bin/latency.aot
fi

"${WASMER}" compile bin/latency.wasm -o bin/latency-wasmer-cranelift.wasmu --enable-all --cranelift
"${WASMER}" compile bin/latency.wasm -o bin/latency-wasmer-llvm.wasmu --enable-all --llvm

WASMTIME_NEW_CLI=0 "${WASMTIME}" compile bin/latency.wasm -o bin/latency.cwasm --wasm-features=all --wasi-modules=experimental-wasi-threads

rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"
sudo scripts/runscript.sh bin/latency_original_posix_with_prio ${MICRO_TIME} "${OUTPUT_DIR}" "original_posix_prio" "${CORE_COUNT}" "OFF"
sudo scripts/runscript.sh bin/latency_rewrite_no_prio ${MICRO_TIME} "${OUTPUT_DIR}" "rewrite_no_prio" "${CORE_COUNT}" "OFF"
sudo scripts/runscript.sh bin/latency_rewrite_with_posix_prio ${MICRO_TIME} "${OUTPUT_DIR}" "rewrite_posix_prio" "${CORE_COUNT}" "OFF"
sudo scripts/runscript.sh bin/latency_rewrite_no_prio ${MICRO_TIME} "${OUTPUT_DIR}" "rewrite_chrt_prio" "${CORE_COUNT}" "ON"
sudo scripts/runscript.sh "${NODE} bin/latency_emcc.js" ${MICRO_TIME} "${OUTPUT_DIR}" "node" "${CORE_COUNT}" "ON"
sudo scripts/runscript.sh "${WASMTIME} run bin/latency.cwasm --allow-precompiled --wasm-features=all --wasi-modules=experimental-wasi-threads" ${MICRO_TIME} "${OUTPUT_DIR}" "wasmtime" "${CORE_COUNT}" "ON"
sudo scripts/runscript.sh "${WASMER} run --cranelift bin/latency-wasmer-cranelift.wasmu" ${MICRO_TIME} "${OUTPUT_DIR}" "wasmer_cranelift" "${CORE_COUNT}" "ON"
sudo scripts/runscript.sh "${WASMER} run --llvm bin/latency-wasmer-llvm.wasmu" ${MICRO_TIME} "${OUTPUT_DIR}" "wasmer_llvm" "${CORE_COUNT}" "ON"
sudo scripts/runscript.sh "${WAMR} bin/latency.aot" ${MICRO_TIME} "${OUTPUT_DIR}" "wamr" "${CORE_COUNT}" "ON"

mkdir -p graphs
echo "Generating graphs: python scripts/graphs.py ${OUTPUT_DIR} graphs/${PDF_NAME}"
python scripts/graphs.py "${OUTPUT_DIR}" "graphs/${PDF_NAME}"
