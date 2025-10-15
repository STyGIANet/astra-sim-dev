#!/bin/bash

EXP=$1
N_CORES=$2
# find the absolute path to this script
source config.sh

NODES=(8 16 32 64)
MSG_SIZES=(128 1000 16000 256000 4000000 64000000 256000000 1000000000)
PROPAGATION_DELAY=("0.0005ms" "0.00025ms") # Put unit for the delays (ms)!!
RECONFIG_DELAY=("0ns" "10ns" "100ns" "1000ns" "10000ns" "100000ns" "1000000ns") # Put unit for the reconfigs (ns)!!
BANDWIDTH=("400Gbps" "800Gbps" "1200Gbps" "3200Gbps") # Put unit for the bandwidth (Gbps)!!
ALPHA_DELAY=(0 10 100 10000) #units in ns!!!

# NODES=(16)
# MSG_SIZES=(160000)
# PROPAGATION_DELAY=("0.0005ms") # Put unit for the delays (ms)!!
# RECONFIG_DELAY=("1000000ns") # Put unit for the reconfigs (ns)!!
# BANDWIDTH=("400Gbps") # Put unit for the bandwidth (Gbps)!!
# ALPHA_DELAY=(10) #units in ns!!!

ALLREDUCE_ALGS=("halvingDoubling" "direct1" "swing")
ALGS=("optical")
# Recompile ns3
cd ${SCRIPT_DIR}
echo ${SCRIPT_DIR}
# ./build-optical-interconnect.sh -l
# ./build-optical-interconnect.sh -c
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

				for ALPHA in ${ALPHA_DELAY[@]};do
				for PDELAY in ${PROPAGATION_DELAY[@]};do
				for BW in ${BANDWIDTH[@]};do
				for RECONF in ${RECONFIG_DELAY[@]};do

					while [[ $(( $(ps aux | grep AstraSimNetwork-optimized | wc -l) )) -gt $N_CORES ]];do
						sleep 30;
						echo "running $N experiment(s)..."
					done

					WORKLOAD=${ET_WORKLOAD_DIR}/AllReduce-$NUM_NODES-$MSG_SIZE-optical-ring
					SYSTEM=${SYSTEM_DIR}/system-$ALLREDUCE_ALG-$APP_LOADBALANCE_ALG-$ALPHA.json
					NETWORK=${NETWORK_DIR}/config-optical-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}-${RECONF}.txt
					MEMORY=${MEMORY_DIR}/remote_memory.json
					LOGICAL_TOPOLOGY=${LOGICAL_TOPO_DIR}/logical-topo-$NUM_NODES.json
					OUTPUT_FILE=${RESULTS_DIR}/AllReduce-$NUM_NODES-$MSG_SIZE-optical-ring-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${ALPHA}ns-${PDELAY}-${BW}-${RECONF}.out
					OPTICAL_ROUTING=${OPTICAL_ROUTING_DIR}/optical-ring-${NUM_NODES}-${MSG_SIZE}-${PDELAY}-${BW}-${RECONF}-${ALLREDUCE_ALG}.txt
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
		done
	done
done

echo "Total $N experiments..."
	