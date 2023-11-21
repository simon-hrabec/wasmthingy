#!/bin/bash

WASI_SDK_CLANG='/home/simon/repo/wasi-sdk/dist/wasi-sdk-20.20g2393be41c8df/bin/clang++ --sysroot=/home/simon/repo/wasi-sdk/dist/wasi-sdk-20.20g2393be41c8df/share/wasi-sysroot'
WASMTIME='/home/simon/.wasmtime/bin/wasmtime'
WASMER='/home/simon/.wasmer/bin/wasmer'
PROGRAM_CODE='code/rewrite.cpp'
OLD_CODE='code/latency.cpp'

rm -rf bin
mkdir -p bin
g++ -Wall -pedantic -pthread -DGATHER_ALL "${PROGRAM_CODE}" -o bin/latency_no_prio
g++ -Wall -pedantic -pthread -DPOSIX_PRORITY_SETUP "${PROGRAM_CODE}" -o bin/latency_with_prio_cpp
g++ -Wall -pedantic -pthread -DGATHER_ALL -DPRIO "${OLD_CODE}" -o bin/latency_with_prio_posix
emcc -pthread -DGATHER_ALL "${PROGRAM_CODE}" -o bin/latency_emcc.js
${WASI_SDK_CLANG} -pthread --target=wasm32-wasi-threads -fno-exceptions -Wl,--import-memory,--export-memory,--max-memory=67108864 "${PROGRAM_CODE}" -o bin/latency.wasm

TEST_TIME_SEC=4
MICRO_TIME=$((TEST_TIME_SEC * 1000000))

rm -rf output
mkdir -p output
sudo scripts/runscript.sh bin/latency_no_prio ${MICRO_TIME} output/out_no_prio output/data_no_prio 4
sudo scripts/runscript.sh bin/latency_with_prio_cpp ${MICRO_TIME} output/out_with_prio_cpp output/data_with_prio_cpp 4
sudo scripts/runscript.sh bin/latency_with_prio_posix ${MICRO_TIME} output/out_with_prio_posix output/data_with_prio_posix 4
sudo scripts/runscript.sh "node bin/latency_emcc.js" ${MICRO_TIME} output/out_node output/data_node 4
sudo scripts/runscript.sh "${WASMTIME} --wasm-features=threads --wasi-modules=experimental-wasi-threads bin/latency.wasm" ${MICRO_TIME} output/out_wasmtime output/data_wasmtime 4
sudo scripts/runscript.sh "${WASMER} bin/latency.wasm" ${MICRO_TIME} output/out_wasmer output/data_wasmer 4

python scripts/graphs.py