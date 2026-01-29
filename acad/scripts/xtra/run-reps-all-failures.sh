#!/bin/bash

EXP=$1
N_CORES=$2
# find the absolute path to this script
source config.sh

NODES=(256)
MSG_SIZES=(1000000 2000000 4000000 8000000 16000000 32000000 64000000 128000000 256000000)
TXT_WORKLOADS=("Gpt_117M")
ALLREDUCE_ALGS=("direct" "halvingDoubling")
APP_LOADBALANCE_ALGS=("ethereal" "mp-rdma-2" "mp-rdma-4" "mp-rdma-8" "none")
ROUTING_ALGS=("SOURCE_ROUTING" "REPS" "REPSv4" "END_HOST_SPRAY" "ECMP")

ALGS=("repsv4")
REPSV4=1

# Recompile ns3
# cd ${SCRIPT_DIR}
# ./build.sh -l
# ./build.sh -c
##############################################################################
# leaf-spine topology with 256 nodes
# Allreduce across various message sizes and load balancing algorithms
# N=0
NUM_NODES=256
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
		elif [[ $ALG == "repsv4" ]];then
			ROUTING="REPSv4"
			APP_LOADBALANCE_ALG="none"
			REPSV4=1
		elif [[ $ALG == "spray" ]];then
			ROUTING="END_HOST_SPRAY"
			APP_LOADBALANCE_ALG="none"
		elif [[ $ALG == "none" ]]; then
			ROUTING="ECMP"
			APP_LOADBALANCE_ALG="none"
		fi

		for ALLREDUCE_ALG in ${ALLREDUCE_ALGS[@]};do

			while [[ $(( $(ps aux | grep AstraSimNetwork-optimized | wc -l) )) -gt $N_CORES ]];do
				sleep 30;
				echo "running $N experiment(s)..."
			done

			WORKLOAD=${ET_WORKLOAD_DIR}/AllReduce-$NUM_NODES-$MSG_SIZE-leaf-spine
			SYSTEM=${SYSTEM_DIR}/system-$ALLREDUCE_ALG-$APP_LOADBALANCE_ALG.json
			NETWORK=${NETWORK_DIR}/config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt
			MEMORY=${MEMORY_DIR}/remote_memory.json
			LOGICAL_TOPOLOGY=${LOGICAL_TOPO_DIR}/logical-topo-$NUM_NODES.json
			OUTPUT_FILE=${RESULTS_DIR}/AllReduce-$NUM_NODES-$MSG_SIZE-leaf-spine-$ALG-$ALLREDUCE_ALG.out

			cd ${PROJECT_DIR}
			if [[ $EXP == 1 ]];then
				(time "${NS3_DIR}"/build/scratch/ns3.42-AstraSimNetwork-optimized \
				        --workload-configuration=${WORKLOAD} \
				        --system-configuration=${SYSTEM} \
				        --network-configuration=${NETWORK} \
				        --remote-memory-configuration=${MEMORY} \
				        --logical-topology-configuration=${LOGICAL_TOPOLOGY} \
				        --linkFailure=1 \
				        --comm-group-configuration=\"empty\" > ${OUTPUT_FILE} 2> ${OUTPUT_FILE}; echo $OUTPUT_FILE)&
			sleep 2
			fi
			echo "$NETWORK"
			N=$(( $N+1 ))
		done
	done
done


##############################################################################
# fat-tree topology with 512 nodes, k=8 uplinks per switch
# Allreduce across various message sizes and load balancing algorithms
# N=0
NUM_NODES=512
K=8
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
		elif [[ $ALG == "repsv4" ]];then
			ROUTING="REPSv4"
			APP_LOADBALANCE_ALG="none"
			REPSV4=1
		elif [[ $ALG == "spray" ]];then
			ROUTING="END_HOST_SPRAY"
			APP_LOADBALANCE_ALG="none"
		elif [[ $ALG == "none" ]]; then
			ROUTING="ECMP"
			APP_LOADBALANCE_ALG="none"
		fi

		for ALLREDUCE_ALG in ${ALLREDUCE_ALGS[@]};do

			while [[ $(( $(ps aux | grep AstraSimNetwork-optimized | wc -l) )) -gt $N_CORES ]];do
				sleep 30;
				echo "running $N experiment(s)..."
			done

			WORKLOAD=${ET_WORKLOAD_DIR}/AllReduce-$K-$MSG_SIZE-fat-tree
			SYSTEM=${SYSTEM_DIR}/system-$ALLREDUCE_ALG-$APP_LOADBALANCE_ALG.json
			NETWORK=${NETWORK_DIR}/config-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt
			MEMORY=${MEMORY_DIR}/remote_memory.json
			LOGICAL_TOPOLOGY=${LOGICAL_TOPO_DIR}/logical-topo-$NUM_NODES.json
			OUTPUT_FILE=${RESULTS_DIR}/AllReduce-$NUM_NODES-$MSG_SIZE-fat-tree-$ALG-$ALLREDUCE_ALG.out

			cd ${PROJECT_DIR}
			if [[ $EXP == 1 ]];then
				(time "${NS3_DIR}"/build/scratch/ns3.42-AstraSimNetwork-optimized \
				        --workload-configuration=${WORKLOAD} \
				        --system-configuration=${SYSTEM} \
				        --network-configuration=${NETWORK} \
				        --remote-memory-configuration=${MEMORY} \
				        --logical-topology-configuration=${LOGICAL_TOPOLOGY} \
				        --linkFailure=1 \
				        --comm-group-configuration=\"empty\" > ${OUTPUT_FILE} 2> ${OUTPUT_FILE}; echo $OUTPUT_FILE)&
			sleep 2
			fi
			echo "$NETWORK"
			N=$(( $N+1 ))
		done
	done
done

echo "Total $N experiments..."