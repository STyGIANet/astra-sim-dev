#!/bin/bash

EXP=$1
N_CORES=$2
# find the absolute path to this script
source config.sh

#########################
# For reference use
# NODES=(8 16 32 64) 
# MSG_SIZES=(1024 16384 262144 \
#  4194304 67108864 268435456 536870912 1073741824)

# MSG_NAMES=(1KB 16KB 256KB 4MB \
# 64MB 256MB 512MB 1GB)
# RECONFIG_DELAYS=(0 10 100 1000 10000 100000 1000000 10000000)
# BANDWIDTHS=(800 1600 3200) # in Gbps
# ## # Delays are paired by index (i.e., ALPHA_DELAYS[i] with PDELAYS[i]),
# rather than iterating over every possible combination.
# ALPHA_DELAYS=(500 10000 500) # in ns
# PDELAYS=(500 500 10000) # in ns
# ALGS=(halvingDoubling swing direct1)
# ALGS_TOPO=(all-reduce-rd-nd all-reduce-swing-nd all-to-all-nd)
# PORT=1
# DONT CHANGE BELOW
# RELAXATION=0
# LOGGING=0
# RD = 0

NODES=(64)
MSG_SIZES=(1024 16384 262144 4194304 16777216 \
67108864 268435456 1073741824)

MSG_NAMES=(1KB 16KB 256KB 4MB 16MB \
64MB 256MB 1GB)
RECONFIG_DELAYS=(10 100 1000 10000 100000 1000000 10000000) # in ns!!
BANDWIDTHS=(800) # in Gbps
ALPHA_DELAYS=(500) # in ns
PDELAYS=(500) # in ns
ALGS=(halvingDoubling swing direct1)
PORT=1
RELAXATION=0
LOGGING=0
RD=0

APP_LOADBALANCE_ALGS=(none)
ROUTING_ALGS=(OPTICAL)
RUN_BVN=1
RUN_STATIC=1
RUN_HARVEST=1

# Recompile ns3
cd ${SCRIPT_DIR}
echo ${SCRIPT_DIR}
# ./build-optical-interconnect.sh -l
# ./build-optical-interconnect.sh -c
##############################################################################
N=0 # Experiment count
## This run is for Harvest
if [ "$RUN_HARVEST" -eq 1 ]; then
for NODE in ${NODES[@]};do
	for MSG_NAME in ${MSG_NAMES[@]};do
		for MODEL in ${ROUTING_ALGS[@]};do

			if [[ ${MODEL,,} == "ethereal" ]];then
				ROUTING="SOURCE_ROUTING"
				APP_LOADBALANCE_ALG="ethereal"
			elif [[ ${MODEL,,} == "mp-rdma-2" ]];then
				ROUTING="ECMP"
				APP_LOADBALANCE_ALG="mp-rdma-2"
			elif [[ ${MODEL,,} == "mp-rdma-4" ]];then
				ROUTING="ECMP"
				APP_LOADBALANCE_ALG="mp-rdma-4"
			elif [[ ${MODEL,,} == "mp-rdma-8" ]];then
				ROUTING="ECMP"
				APP_LOADBALANCE_ALG="mp-rdma-8"
			elif [[ ${MODEL,,} == "reps" ]];then
				ROUTING="REPS"
				APP_LOADBALANCE_ALG="none"
			elif [[ ${MODEL,,} == "spray" ]];then
				ROUTING="END_HOST_SPRAY"
				APP_LOADBALANCE_ALG="none"
			elif [[ ${MODEL,,} == "optical" ]]; then
				ROUTING="OPTICAL"
				APP_LOADBALANCE_ALG="none"
			elif [[ ${MODEL,,} == "none" ]]; then
				ROUTING="ECMP"
				APP_LOADBALANCE_ALG="none"
			fi

			for ALG in ${ALGS[@]};do
				if [[ $ALG =~ ^direct.* ]]; then
					MYWORKLOAD="AlltoAll"
				else
					MYWORKLOAD="AllReduce"
				fi

				if [[ ${ALG} == "swing" ]]; then
					PORT=2
				else
					PORT=1
				fi
				for ALPHA_DELTA_ID in ${!ALPHA_DELAYS[@]};do
					ALPHA=${ALPHA_DELAYS[$ALPHA_DELTA_ID]}
					PDELAY=${PDELAYS[$ALPHA_DELTA_ID]}
				for BW in ${BANDWIDTHS[@]};do
				for RECONF in ${RECONFIG_DELAYS[@]};do

					while [[ $(( $(ps aux | grep AstraSimNetwork-optimized | wc -l) )) -gt $N_CORES ]];do
						sleep 30;
						echo "running $N experiment(s)..."
					done 						


					WORKLOAD=${ET_WORKLOAD_DIR}/$MYWORKLOAD-$NODE-$MSG_NAME-optical
					SYSTEM=${SYSTEM_DIR}/system-$ALG-$APP_LOADBALANCE_ALG-$ALPHA.json
					NETWORK=${NETWORK_DIR}/config-optical-${NODE}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt
					MEMORY=${MEMORY_DIR}/remote_memory.json
					LOGICAL_TOPOLOGY=${LOGICAL_TOPO_DIR}/logical-topo-$NODE.json
					OUTPUT_FILE=${RESULTS_DIR}/$MYWORKLOAD-$NODE-$MSG_NAME-harvest-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.out
					OPTICAL_ROUTING=${OPTICAL_ROUTING_DIR}/harvest-$ALG-$NODE-$PORT-${MSG_NAME}-$BW-$ALPHA-$PDELAY-${RECONF}-$RELAXATION.json
					cd ${PROJECT_DIR}
					if [[ $EXP == 1 ]];then
						(time "${NS3_DIR}"/build/scratch/ns3.42-AstraSimNetwork-optimized \
								--workload-configuration=${WORKLOAD} \
								--system-configuration=${SYSTEM} \
								--network-configuration=${NETWORK} \
								--remote-memory-configuration=${MEMORY} \
								--logical-topology-configuration=${LOGICAL_TOPOLOGY} \
								--optical-routing-configuration=${OPTICAL_ROUTING} \
								--comm-group-configuration=\"empty\"  > ${OUTPUT_FILE} 2>&1; echo $OUTPUT_FILE)&
					sleep 3
					echo ${OUTPUT_FILE}
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

fi


# This is for static
if [ "$RUN_STATIC" -eq 1 ]; then
for NODE in ${NODES[@]};do
	for MSG_NAME in ${MSG_NAMES[@]};do
		
		for MODEL in ${ROUTING_ALGS[@]};do

			if [[ ${MODEL,,} == "ethereal" ]];then
				ROUTING="SOURCE_ROUTING"
				APP_LOADBALANCE_ALG="ethereal"
			elif [[ ${MODEL,,} == "mp-rdma-2" ]];then
				ROUTING="ECMP"
				APP_LOADBALANCE_ALG="mp-rdma-2"
			elif [[ ${MODEL,,} == "mp-rdma-4" ]];then
				ROUTING="ECMP"
				APP_LOADBALANCE_ALG="mp-rdma-4"
			elif [[ ${MODEL,,} == "mp-rdma-8" ]];then
				ROUTING="ECMP"
				APP_LOADBALANCE_ALG="mp-rdma-8"
			elif [[ ${MODEL,,} == "reps" ]];then
				ROUTING="REPS"
				APP_LOADBALANCE_ALG="none"
			elif [[ ${MODEL,,} == "spray" ]];then
				ROUTING="END_HOST_SPRAY"
				APP_LOADBALANCE_ALG="none"
			elif [[ ${MODEL,,} == "optical" ]]; then
				ROUTING="OPTICAL"
				APP_LOADBALANCE_ALG="none"
			elif [[ ${MODEL,,} == "none" ]]; then
				ROUTING="ECMP"
				APP_LOADBALANCE_ALG="none"
			fi

			for ALG in ${ALGS[@]};do
				if [[ $ALG =~ ^direct.* ]]; then
					MYWORKLOAD="AlltoAll"
				else
					MYWORKLOAD="AllReduce"
				fi

				if [[ ${ALG} == "swing" ]]; then
					PORT=2
				else
					PORT=1
				fi
				for ALPHA_DELTA_ID in ${!ALPHA_DELAYS[@]};do
					ALPHA=${ALPHA_DELAYS[$ALPHA_DELTA_ID]}
					PDELAY=${PDELAYS[$ALPHA_DELTA_ID]}
				for BW in ${BANDWIDTHS[@]};do

					while [[ $(( $(ps aux | grep AstraSimNetwork-optimized | wc -l) )) -gt $N_CORES ]];do
						sleep 30;
						echo "running $N experiment(s)..."
					done 						


					WORKLOAD=${ET_WORKLOAD_DIR}/$MYWORKLOAD-$NODE-$MSG_NAME-optical
					SYSTEM=${SYSTEM_DIR}/system-$ALG-$APP_LOADBALANCE_ALG-$ALPHA.json
					NETWORK=${NETWORK_DIR}/config-static-${NODE}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}.txt # reconf is 0 just so we dont run it more than we need to
					MEMORY=${MEMORY_DIR}/remote_memory.json
					LOGICAL_TOPOLOGY=${LOGICAL_TOPO_DIR}/logical-topo-$NODE.json
					OUTPUT_FILE=${RESULTS_DIR}/$MYWORKLOAD-$NODE-$MSG_NAME-static-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${ALPHA}-${PDELAY}-${BW}.out
					OPTICAL_ROUTING=${OPTICAL_ROUTING_DIR}/static-$ALG-$NODE-$PORT.json
					cd ${PROJECT_DIR}
					if [[ $EXP == 1 ]];then
						(time "${NS3_DIR}"/build/scratch/ns3.42-AstraSimNetwork-optimized \
								--workload-configuration=${WORKLOAD} \
								--system-configuration=${SYSTEM} \
								--network-configuration=${NETWORK} \
								--remote-memory-configuration=${MEMORY} \
								--logical-topology-configuration=${LOGICAL_TOPOLOGY} \
								--optical-routing-configuration=${OPTICAL_ROUTING} \
								--comm-group-configuration=\"empty\"  > ${OUTPUT_FILE} 2> ${OUTPUT_FILE}; echo $OUTPUT_FILE)&
					sleep 3
					echo ${OUTPUT_FILE}
					fi
					echo "$NETWORK"
					N=$(( $N+1 ))
				done
				done
			done
		done
	done
done
fi

# This is for bvn
if [ "$RUN_BVN" -eq 1 ]; then
for NODE in ${NODES[@]};do
	NUM_NODES=$NODE
	for MSG_NAME in ${MSG_NAMES[@]};do
		
		for MODEL in ${ROUTING_ALGS[@]};do

			if [[ ${MODEL,,} == "ethereal" ]];then
				ROUTING="SOURCE_ROUTING"
				APP_LOADBALANCE_ALG="ethereal"
			elif [[ ${MODEL,,} == "mp-rdma-2" ]];then
				ROUTING="ECMP"
				APP_LOADBALANCE_ALG="mp-rdma-2"
			elif [[ ${MODEL,,} == "mp-rdma-4" ]];then
				ROUTING="ECMP"
				APP_LOADBALANCE_ALG="mp-rdma-4"
			elif [[ ${MODEL,,} == "mp-rdma-8" ]];then
				ROUTING="ECMP"
				APP_LOADBALANCE_ALG="mp-rdma-8"
			elif [[ ${MODEL,,} == "reps" ]];then
				ROUTING="REPS"
				APP_LOADBALANCE_ALG="none"
			elif [[ ${MODEL,,} == "spray" ]];then
				ROUTING="END_HOST_SPRAY"
				APP_LOADBALANCE_ALG="none"
			elif [[ ${MODEL,,} == "optical" ]]; then
				ROUTING="OPTICAL"
				APP_LOADBALANCE_ALG="none"
			elif [[ ${MODEL,,} == "none" ]]; then
				ROUTING="ECMP"
				APP_LOADBALANCE_ALG="none"
			fi

			for ALG in ${ALGS[@]};do
				if [[ $ALG =~ ^direct.* ]]; then
					MYWORKLOAD="AlltoAll"
				else
					MYWORKLOAD="AllReduce"
				fi

				if [[ ${ALG} == "swing" ]]; then
					PORT=2
				else
					PORT=1
				fi
				for ALPHA_DELTA_ID in ${!ALPHA_DELAYS[@]};do
					ALPHA=${ALPHA_DELAYS[$ALPHA_DELTA_ID]}
					PDELAY=${PDELAYS[$ALPHA_DELTA_ID]}
				for BW in ${BANDWIDTHS[@]};do
				RECONF=0

					while [[ $(( $(ps aux | grep AstraSimNetwork-optimized | wc -l) )) -gt $N_CORES ]];do
						sleep 30;
						echo "running $N experiment(s)..."
					done 						


					WORKLOAD=${ET_WORKLOAD_DIR}/$MYWORKLOAD-$NODE-$MSG_NAME-optical
					SYSTEM=${SYSTEM_DIR}/system-$ALG-$APP_LOADBALANCE_ALG-$ALPHA.json
					NETWORK=${NETWORK_DIR}/config-bvn-${NODE}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt
					MEMORY=${MEMORY_DIR}/remote_memory.json
					LOGICAL_TOPOLOGY=${LOGICAL_TOPO_DIR}/logical-topo-$NODE.json
					OUTPUT_FILE=${RESULTS_DIR}/$MYWORKLOAD-$NODE-$MSG_NAME-bvn-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.out
					OPTICAL_ROUTING=${OPTICAL_ROUTING_DIR}/bvn-$ALG-$NODE-$PORT-$RECONF.json
					cd ${PROJECT_DIR}
					if [[ $EXP == 1 ]];then
						(time "${NS3_DIR}"/build/scratch/ns3.42-AstraSimNetwork-optimized \
								--workload-configuration=${WORKLOAD} \
								--system-configuration=${SYSTEM} \
								--network-configuration=${NETWORK} \
								--remote-memory-configuration=${MEMORY} \
								--logical-topology-configuration=${LOGICAL_TOPOLOGY} \
								--optical-routing-configuration=${OPTICAL_ROUTING} \
								--comm-group-configuration=\"empty\"  > ${OUTPUT_FILE} 2> ${OUTPUT_FILE}; echo $OUTPUT_FILE)&
					sleep 3
					echo ${OUTPUT_FILE}
					fi
					echo "$NETWORK"
					N=$(( $N+1 ))
				done
				done
			done
		done
	done
done
fi	
echo "Total $N experiments..."

