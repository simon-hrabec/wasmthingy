#!/bin/bash

# $1 = OUTPUT DIR
# $2 = GRAPH PDF NAME
# $2 = TEST TIME - SECONDS

DEFAULT_TEST_TIME_SEC="8"

OUTPUT_DIR="${1:-output}"
PDF_NAME="${2:-graphs.pdf}"
TEST_TIME_SEC="${3:-${DEFAULT_TEST_TIME_SEC}}"
MICRO_TIME=$((TEST_TIME_SEC * 1000000))

ARCH="$(dpkg --print-architecture)"
WASI_SDK_CLANG='/home/simon/repo/wasi-sdk/dist/wasi-sdk-20.20g2393be41c8df/bin/clang++'
WASI_SDK_SYSROOT='--sysroot=/home/simon/repo/wasi-sdk/dist/wasi-sdk-20.20g2393be41c8df/share/wasi-sysroot'
WASMTIME='/home/simon/.wasmtime/bin/wasmtime'
WASMER='/home/simon/.wasmer/bin/wasmer'
PROGRAM_CODE='code/rewrite.cpp'
OLD_CODE='code/latency.cpp'
NODE="$(which node)"
WAMRC="$(which wamrc)"

[[ -f scripts/mainscript-custom.sh ]] && source scripts/mainscript-custom.sh

rm -rf bin
mkdir -p bin
g++ -Wall -pedantic -pthread -DGATHER_ALL "${PROGRAM_CODE}" -o bin/latency_no_prio
g++ -Wall -pedantic -pthread -DPOSIX_PRORITY_SETUP "${PROGRAM_CODE}" -o bin/latency_with_prio_cpp
g++ -Wall -pedantic -pthread -DGATHER_ALL -DPRIO "${OLD_CODE}" -o bin/latency_with_prio_posix
emcc -pthread -DGATHER_ALL -sINITIAL_MEMORY=268435456 "${PROGRAM_CODE}" -o bin/latency_emcc.js
if [ -f "${WASI_SDK_CLANG}" ]; then
   ${WASI_SDK_CLANG} ${WASI_SDK_SYSROOT} -pthread --target=wasm32-wasi-threads -fno-exceptions -Wl,--import-memory,--export-memory,--max-memory=67108864 "${PROGRAM_CODE}" -o bin/latency.wasm
else
   cp artifacts/latency.wasm bin/latency.wasm
fi
if [ -f "${WAMRC}" ]; then
	${WAMRC} --enable-multi-thread -o bin/latency.aot bin/latency.wasm
else
	cp artifacts/latency-arm.aot bin/latency.aot
fi

if [[ "$a" == "arm64" ]]; then
	WAMR="artifacts/iwasm-arm"
else
	WAMR="artifacts/iwasm-x86"
fi

rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"
sudo scripts/runscript.sh bin/latency_no_prio ${MICRO_TIME} "${OUTPUT_DIR}" "no_prio" 4
sudo scripts/runscript.sh bin/latency_with_prio_cpp ${MICRO_TIME} "${OUTPUT_DIR}" "with_prio_cpp" 4
sudo scripts/runscript.sh bin/latency_with_prio_posix ${MICRO_TIME} "${OUTPUT_DIR}" "with_prio_posix" 4
sudo scripts/runscript.sh "${NODE} bin/latency_emcc.js" ${MICRO_TIME} "${OUTPUT_DIR}" "node" 4
sudo scripts/runscript.sh "${WASMTIME} --wasm-features=threads --wasi-modules=experimental-wasi-threads bin/latency.wasm" ${MICRO_TIME} "${OUTPUT_DIR}" "wasmtime" 4
sudo scripts/runscript.sh "${WASMER} --singlepass bin/latency.wasm" ${MICRO_TIME} "${OUTPUT_DIR}" "wasmer_singlepass" 4
sudo scripts/runscript.sh "${WASMER} --cranelift bin/latency.wasm" ${MICRO_TIME} "${OUTPUT_DIR}" "wasmer_cranelift" 4
sudo scripts/runscript.sh "${WASMER} --llvm bin/latency.wasm" ${MICRO_TIME} "${OUTPUT_DIR}" "wasmer_llvm" 4
sudo scripts/runscript.sh "${WAMR} bin/latency.aot" ${MICRO_TIME} "${OUTPUT_DIR}" "wamr" 4

mkdir -p graphs
python scripts/graphs.py "${OUTPUT_DIR}" "graphs/${PDF_NAME}"

rm hist.pdf
rm hist2.pdf