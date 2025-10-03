#!/bin/bash

EXP=$1
N_CORES=$2
# find the absolute path to this script
source config.sh

NODES=(64)
MSG_SIZES=(128000000 256000000 512000000)
PROPAGATION_DELAY=("0.0005ms") # Put unit for the delays (ms)!!
RECONFIG_DELAY=("0ns") # Put unit for the reconfigs (ns)!!
BANDWIDTH=("800Gbps") # Put unit for the bandwidth (Gbps)!!
# TXT_WORKLOADS=("DLRM_HybridParallel" "Resnet50_DataParallel" "MLP_HybridParallel_Data_Model")
ALLREDUCE_ALGS=("halvingDoubling")
APP_LOADBALANCE_ALGS=("none")
ROUTING_ALGS=("ECMP")


ALGS=("none")

# Recompile ns3
cd ${SCRIPT_DIR}
# ./build.sh -l
./build.sh -c
##############################################################################
# leaf-spine topology with 256 nodes
# Allreduce across various message sizes and load balancing algorithms
N=0
for NUM_NODES in ${NODES[@]};do
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
		elif [[ $ALG == "none" ]]; then
			ROUTING="ECMP"
			APP_LOADBALANCE_ALG="none"
		fi

		for ALLREDUCE_ALG in ${ALLREDUCE_ALGS[@]};do
            for PDELAY in ${PROPAGATION_DELAY[@]};do
            for BW in ${BANDWIDTH[@]};do

                while [[ $(( $(ps aux | grep AstraSimNetwork-optimized | wc -l) )) -gt $N_CORES ]];do
                    sleep 30;
                    echo "running $N experiment(s)..."
                done

                WORKLOAD=${ET_WORKLOAD_DIR}/AllReduce-$NUM_NODES-$MSG_SIZE-leaf-spine
                SYSTEM=${SYSTEM_DIR}/system-$ALLREDUCE_ALG-$APP_LOADBALANCE_ALG.json
                NETWORK=${NETWORK_DIR}/config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${PDELAY}-${BW}.txt
                MEMORY=${MEMORY_DIR}/remote_memory.json
                LOGICAL_TOPOLOGY=${LOGICAL_TOPO_DIR}/logical-topo-$NUM_NODES.json
                OUTPUT_FILE=${RESULTS_DIR}/AllReduce-$NUM_NODES-$MSG_SIZE-ring-$ALG-$ALLREDUCE_ALG-${PDELAY}-${BW}.out

                cd ${PROJECT_DIR}
                if [[ $EXP == 1 ]];then
                    (time "${NS3_DIR}"/build/scratch/ns3.42-AstraSimNetwork-optimized \
                            --workload-configuration=${WORKLOAD} \
                            --system-configuration=${SYSTEM} \
                            --network-configuration=${NETWORK} \
                            --remote-memory-configuration=${MEMORY} \
                            --logical-topology-configuration=${LOGICAL_TOPOLOGY} \
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

echo "Total $N experiments..."