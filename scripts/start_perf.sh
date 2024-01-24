#!/bin/bash

PERF_DATA=/tmp/perf.data
PERF_LOG=/tmp/perf.log
PERF="/bin/perf"

rm -rf ${PERF_DATA}
rm -rf ${PERF_LOG}

touch ${PERF_DATA}
touch ${PERF_LOG}

${PERF} record -a -e kvm:kvm_vmgexit_msr_protocol_enter -e kvm:kvm_pio -e sched:sched_process_exec -e sched:sched_process_fork -o ${PERF_DATA} > /dev/null 2>&1 &

PERF_PID=$! 2>&1 > /dev/null
sleep 1

echo $PERF_PID
