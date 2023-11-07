#!/bin/bash

g++ -Wall -pedantic -pthread -DPRIO -DGATHER_ALL cycle.cpp -o with_prio
g++ -Wall -pedantic -pthread -DGATHER_ALL cycle.cpp -o no_prio
emcc -pthread -DGATHER_ALL cycle.cpp -o cycle.js

TEST_TIME_SEC=10
MICRO_TIME=$((TEST_TIME_SEC * 1000000))

sudo ./runscript.sh ./no_prio ${MICRO_TIME} out_no_prio data_no_prio 4
sudo ./runscript.sh ./with_prio ${MICRO_TIME} out_with_prio data_with_prio 4
sudo ./runscript.sh "node cycle.js" ${MICRO_TIME} out_node data_node 4
