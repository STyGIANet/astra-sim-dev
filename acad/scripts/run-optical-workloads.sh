#!/bin/bash

EXP=$1
N_CORES=$2
# find the absolute path to this script
source config.sh

NODES=(8)
MSG_SIZES=(4000000)
PROPAGATION_DELAY=("0.0005ms")
ALLREDUCE_ALGS=("halvingDoubling")
ALGS=("optical")
# Recompile ns3
cd ${SCRIPT_DIR}
# ./build-8.sh -l
./build-optical-interconnect.sh -c
##############################################################################
# Allreduce across various message sizes, node sizes and propagation delay
for NODE in ${NODES[@]};do
	N=0
	NUM_NODES=$NODE
	for MSG_SIZE in ${MSG_SIZES[@]};do
		
		for ALG in ${ALGS[@]};do

			if [[ $ALG == "ethereal" ]];then
				ROUTING="SOURCE_ROUTING"
				APP_LOADBALANCE_ALG="ethereal"
			elif [[ $ALG == "mp-rdma-2" ]];then
				ROUTING="ECMP"
				APP_LOADBALANCE_ALG="mp-rdma-2"
			elif [[ $ALG == "mp-rdma-4" ]];then
				ROUTING="ECMP"
				APP_LOADBALANCE_ALG="mp-rdma-4"
			elif [[ $ALG == "mp-rdma-8" ]];then
				ROUTING="ECMP"
				APP_LOADBALANCE_ALG="mp-rdma-8"
			elif [[ $ALG == "reps" ]];then
				ROUTING="REPS"
				APP_LOADBALANCE_ALG="none"
			elif [[ $ALG == "spray" ]];then
				ROUTING="END_HOST_SPRAY"
				APP_LOADBALANCE_ALG="none"
			elif [[ $ALG == "optical" ]]; then
				ROUTING="OPTICAL"
				APP_LOADBALANCE_ALG="none"
			elif [[ $ALG == "none" ]]; then
				ROUTING="ECMP"
				APP_LOADBALANCE_ALG="none"
			fi

			for ALLREDUCE_ALG in ${ALLREDUCE_ALGS[@]};do

				for PDELAY in ${PROPAGATION_DELAY[@]};do

					while [[ $(( $(ps aux | grep AstraSimNetwork-optimized | wc -l) )) -gt $N_CORES ]];do
						sleep 30;
						echo "running $N experiment(s)..."
					done

					WORKLOAD=${ET_WORKLOAD_DIR}/AllReduce-$NUM_NODES-$MSG_SIZE-leaf-spine
					SYSTEM=${SYSTEM_DIR}/system-$ALLREDUCE_ALG-$APP_LOADBALANCE_ALG.json
					NETWORK=${NETWORK_DIR}/config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${PDELAY}.txt
					MEMORY=${MEMORY_DIR}/remote_memory.json
					LOGICAL_TOPOLOGY=${LOGICAL_TOPO_DIR}/logical-topo-$NUM_NODES.json
					OUTPUT_FILE=${RESULTS_DIR}/AllReduce-$NUM_NODES-$MSG_SIZE-leaf-spine-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${PDELAY}.out
					cd ${PROJECT_DIR}
					if [[ $EXP == 1 ]];then
						(time "${NS3_DIR}"/build/scratch/ns3.42-AstraSimNetwork-optimized \
								--workload-configuration=${WORKLOAD} \
								--system-configuration=${SYSTEM} \
								--network-configuration=${NETWORK} \
								--remote-memory-configuration=${MEMORY} \
								--logical-topology-configuration=${LOGICAL_TOPOLOGY} \
								--optical-routing-configuration=${OPTICAL_ROUTING} \
								--comm-group-configuration=\"empty\" > ${OUTPUT_FILE} 2> ${OUTPUT_FILE}; echo $OUTPUT_FILE)&
					sleep 2
					fi
					echo "$NETWORK"
					N=$(( $N+1 ))
				done
			done
		done
	done
done

echo "Total $N experiments..."
	