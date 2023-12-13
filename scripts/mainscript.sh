#!/bin/bash

# $1 = OUTPUT DIR
# $2 = GRAPH PDF NAME
# $2 = TEST TIME - SECONDS

DEFAULT_TEST_TIME_SEC="4"
DEFAULT_CORE_COUNT="4"
DEFAULT_APPLY_STRESS="OFF"

OUTPUT_DIR="${1:-output}"
PDF_NAME="${2:-graphs.pdf}"
TEST_TIME_SEC="${3:-${DEFAULT_TEST_TIME_SEC}}"
MICRO_TIME=$((TEST_TIME_SEC * 1000000))
CORE_COUNT="${4:-${DEFAULT_CORE_COUNT}}"
APPLY_STRESS="${5:-${DEFAULT_APPLY_STRESS}}"

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
g++ -Wall -pedantic -pthread -DGATHER_ALL "${PROGRAM_CODE}" -o bin/latency_no_prio
g++ -Wall -pedantic -pthread -DPOSIX_PRORITY_SETUP "${PROGRAM_CODE}" -o bin/latency_with_prio_cpp
g++ -Wall -pedantic -pthread -DGATHER_ALL -DPRIO "${OLD_CODE}" -o bin/latency_with_prio_posix
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

"${WASMER}" compile bin/latency.wasm -o bin/latency-wasmer-cranelift.aot --enable-all --cranelift
"${WASMER}" compile bin/latency.wasm -o bin/latency-wasmer-llvm.aot --enable-all --llvm

"${WASMTIME}" compile bin/latency.wasm -o bin/latency.cwasm --wasm-features=all --wasi-modules=experimental-wasi-threads

rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"
sudo scripts/runscript.sh bin/latency_no_prio ${MICRO_TIME} "${OUTPUT_DIR}" "no_prio" "${CORE_COUNT}" "${APPLY_STRESS}"
sudo scripts/runscript.sh bin/latency_with_prio_cpp ${MICRO_TIME} "${OUTPUT_DIR}" "with_prio_cpp" "${CORE_COUNT}" "${APPLY_STRESS}"
sudo scripts/runscript.sh bin/latency_with_prio_posix ${MICRO_TIME} "${OUTPUT_DIR}" "with_prio_posix" "${CORE_COUNT}" "${APPLY_STRESS}"
sudo scripts/runscript.sh "${NODE} bin/latency_emcc.js" ${MICRO_TIME} "${OUTPUT_DIR}" "node" "${CORE_COUNT}" "${APPLY_STRESS}"
sudo scripts/runscript.sh "${WASMTIME} run bin/latency.cwasm --allow-precompiled --wasm-features=all --wasi-modules=experimental-wasi-threads" ${MICRO_TIME} "${OUTPUT_DIR}" "wasmtime" "${CORE_COUNT}" "${APPLY_STRESS}"
sudo scripts/runscript.sh "${WASMER} run --cranelift bin/latency-wasmer-cranelift.aot" ${MICRO_TIME} "${OUTPUT_DIR}" "wasmer_cranelift" "${CORE_COUNT}" "${APPLY_STRESS}"
sudo scripts/runscript.sh "${WASMER} run --llvm bin/latency-wasmer-llvm.aot" ${MICRO_TIME} "${OUTPUT_DIR}" "wasmer_llvm" "${CORE_COUNT}" "${APPLY_STRESS}"
sudo scripts/runscript.sh "${WAMR} bin/latency.aot" ${MICRO_TIME} "${OUTPUT_DIR}" "wamr" "${CORE_COUNT}" "${APPLY_STRESS}"

mkdir -p graphs
python scripts/graphs.py "${OUTPUT_DIR}" "graphs/${PDF_NAME}"
