#!/bin/bash

PERF_DATA=/tmp/perf.data
PERF_LOG=/tmp/perf.log
PERF="/bin/perf"

kill $1 2>&1 > /dev/null 

while kill -0 "$1" 2>/dev/null; do
    sleep 1
done

${PERF} script -i ${PERF_DATA} > ${PERF_LOG}


