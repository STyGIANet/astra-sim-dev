#!/bin/bash

# find the absolute path to this script
source config.sh

COLL_DIR=$SCRIPT_DIR/collectives
if [[ ! -d ${RESULTS_DIR}/mix ]];then
	mkdir -p ${RESULTS_DIR}/mix
fi
if [[ ! -d ${RESULTS_DIR}/fct ]];then
	mkdir -p ${RESULTS_DIR}/fct
fi
if [[ ! -d ${RESULTS_DIR}/qlen ]];then
	mkdir -p ${RESULTS_DIR}/qlen
fi
if [[ ! -d ${RESULTS_DIR}/pfc ]];then
	mkdir -p ${RESULTS_DIR}/pfc
fi

NUM_PARALLEL=$1

#########################
# For reference use
# NODES=(8) 
# MSG_SIZES=(1024 16384 262144 \
#  4194304 67108864 268435456 536870912 1073741824)

# MSG_NAMES=(1KB 16KB 256KB 4MB \
# 64MB 256MB 512MB 1GB)
# RECONFIG_DELAY=("0ns" "10ns" "100ns" "1000ns" "10000ns" "100000ns" "1000000ns") # Put unit for the reconfigs (ns)!!
# ALPHARS=(0 10 100 1000 10000 100000 1000000)
# BANDWIDTH=("800Gbps") # Put unit for the bandwidth (Gbps)!!
# BANDWIDTH_VALS=(800)
# ## These are pairs:
# ALPHA_DELAYS(500) #units in ns!!!
# PDELAYS=("0.0005ms") # Put unit for the delays (ms)!!
# PROP_DELAY_NAMES=(500)
# # alpha=10, delta=10000
# # alpha=10000, delta=10
# # alpha=100, delta=100
# # alpha=10000, delta=10000
# ALGS=("halvingDoubling" "swing" "direct1")
# ALGS_TOPO=(all-reduce-rd all-reduce-swing all-to-all)
# PORTS=(1)
# RELAXATION=0
# LOGGING=0

NODES=(64)
MSG_SIZES=(1024 16384 262144 4194304 67108864 268435456 536870912 1073741824)

MSG_NAMES=(1KB 16KB 256KB 4MB 64MB 256MB 512MB 1GB)
RECONFIG_DELAYS=(0 10 100 1000 10000 100000 1000000) # in ns!!
BANDWIDTHS=(800) # Put unit for the bandwidth (Gbps)!!
## These are pairs:
ALPHA_DELAYS=(1000 10 10000 10000) #units in ns!!!
PDELAYS=(1000 10000 10 10000)
ALGS=(halvingDoubling swing)
ALGS_TOPO=(all-reduce-rd-nd all-reduce-swing-nd)
PORT=1
RELAXATION=0
LOGGING=0
RD=0

APP_LOADBALANCE_ALGS=(none)
ROUTING_ALGS=(OPTICAL)

# Hmm, it is probably better to generate these config files in-place in the respective scripts where needed.

# First, generate txt workload files
cd $TXT_WORKLOAD_DIR
for NUM_NODES in "${NODES[@]}"; do
	for IDX in ${!MSG_NAMES[@]};do
	# for MSG_SIZE in ${MSG_SIZES[@]};do
		MESSAGE_SIZE=${MSG_SIZES[$IDX]}
		MESSAGE_NAME=${MSG_NAMES[$IDX]}
		echo "Creating workload files"
		echo "MICRO" > AllReduce-$NUM_NODES-$MESSAGE_NAME-optical.txt
		echo "1" >> AllReduce-$NUM_NODES-$MESSAGE_NAME-optical.txt
		echo "conv1 -1 5 NONE 0 5 NONE 0 5  ALLREDUCE $MESSAGE_SIZE 5" >> AllReduce-$NUM_NODES-$MESSAGE_NAME-optical.txt
		echo "MICRO" > AlltoAll-$NUM_NODES-$MESSAGE_NAME-optical.txt
		echo "1" >> AlltoAll-$NUM_NODES-$MESSAGE_NAME-optical.txt
		echo "conv1 -1 5 NONE 0 5 NONE 0 5  ALLTOALL $MESSAGE_SIZE 5" >> AlltoAll-$NUM_NODES-$MESSAGE_NAME-optical.txt

	done
	for TXT_WORKLOAD in ${TXT_WORKLOADS[@]};do
		cp "$BASE_CONFIG_DIR"/"$TXT_WORKLOAD".txt "$TXT_WORKLOAD_DIR"/$TXT_WORKLOAD-$NUM_NODES-optical.txt
	done
done

# Next, generate et workload files
cd $SCRIPT_DIR
for NUM_NODES in "${NODES[@]}"; do
	for MSG_NAME in ${MSG_NAMES[@]};do
		echo "Generating chakra et files"
		./chakra-text-to-et.sh AllReduce-$NUM_NODES-$MSG_NAME-optical $NUM_NODES 1
		./chakra-text-to-et.sh AlltoAll-$NUM_NODES-$MSG_NAME-optical $NUM_NODES 1
	done
done

cd $MEMORY_DIR
cp $BASE_CONFIG_DIR/remote_memory.json remote_memory.json

echo "0" > $PROJECT_DIR/acad/trace.txt

# Generate logical topology files
cd $LOGICAL_TOPO_DIR
for NUM_NODES in "${NODES[@]}"; do
	echo "Generating logical topology files for $NUM_NODES nodes"
	echo "{" > logical-topo-$NUM_NODES.json
	echo "    \"logical-dims\": [\"$NUM_NODES\"]" >> logical-topo-$NUM_NODES.json
	echo "}" >> logical-topo-$NUM_NODES.json
done

#########################################################################
# Generate sys config files
cd $SYSTEM_DIR

for APP_LOADBALANCE_ALG in ${APP_LOADBALANCE_ALGS[@]}; do
    for ALG in ${ALGS[@]}; do
		for ALPHA in ${ALPHA_DELAYS[@]}; do
			cp $BASE_CONFIG_DIR/system.json system-$ALG-$APP_LOADBALANCE_ALG-$ALPHA.json
			perl -0777 -i -pe "s/\"all-reduce-implementation\":\s*\[\s*\"ring\"\s*\]/\"all-reduce-implementation\": [\"$ALG\"]/g" system-$ALG-$APP_LOADBALANCE_ALG-$ALPHA.json
			perl -0777 -i -pe "s/\"all-gather-implementation\":\s*\[\s*\"ring\"\s*\]/\"all-gather-implementation\": [\"$ALG\"]/g" system-$ALG-$APP_LOADBALANCE_ALG-$ALPHA.json
			perl -0777 -i -pe "s/\"all-to-all-implementation\":\s*\[\s*\"ring\"\s*\]/\"all-to-all-implementation\": [\"direct\"]/g" system-$ALG-$APP_LOADBALANCE_ALG-$ALPHA.json
			perl -0777 -i -pe "s/\"reduce-scatter-implementation\":\s*\[\s*\"ring\"\s*\]/\"reduce-scatter-implementation\": [\"$ALG\"]/g" system-$ALG-$APP_LOADBALANCE_ALG-$ALPHA.json
			sed -i "s|\"endpoint-delay\": 0|\"endpoint-delay\": $ALPHA|g" system-$ALG-$APP_LOADBALANCE_ALG-$ALPHA.json

			
			if [[ $APP_LOADBALANCE_ALG == "mp-rdma-2" ]]; then
				sed -i "s|\"app-load-balance\": \"none\"|\"app-load-balance\": \"mp-rdma\"|g" system-$ALG-$APP_LOADBALANCE_ALG-$ALPHA.json
				sed -i "s|\"mp-rdma-qp\": 2|\"mp-rdma-qp\": 2|g" system-$ALG-$APP_LOADBALANCE_ALG-$ALPHA.json
			elif [[ $APP_LOADBALANCE_ALG == "mp-rdma-4" ]]; then
				sed -i "s|\"app-load-balance\": \"none\"|\"app-load-balance\": \"mp-rdma\"|g" system-$ALG-$APP_LOADBALANCE_ALG-$ALPHA.json
				sed -i "s|\"mp-rdma-qp\": 2|\"mp-rdma-qp\": 4|g" system-$ALG-$APP_LOADBALANCE_ALG-$ALPHA.json
			elif [[ $APP_LOADBALANCE_ALG == "mp-rdma-8" ]]; then
				sed -i "s|\"app-load-balance\": \"none\"|\"app-load-balance\": \"mp-rdma\"|g" system-$ALG-$APP_LOADBALANCE_ALG-$ALPHA.json
				sed -i "s|\"mp-rdma-qp\": 2|\"mp-rdma-qp\": 8|g" system-$ALG-$APP_LOADBALANCE_ALG-$ALPHA.json
			else
				sed -i "s|\"app-load-balance\": \"none\"|\"app-load-balance\": \"$APP_LOADBALANCE_ALG\"|g" system-$ALG-$APP_LOADBALANCE_ALG-$ALPHA.json
			fi

			if [[ "$ALG" == direct* ]]; then
				echo $ALG
				perl -0777 -i -pe "s/\"all-to-all-implementation\":\s*\[\s*\"direct\"\s*\]/\"all-to-all-implementation\": [\"$ALG\"]/g" system-$ALG-$APP_LOADBALANCE_ALG-$ALPHA.json
			fi
		done
    done
done

#########################################################################
# Generate network topology files
cd $SCRIPT_DIR
for NUM_NODES in "${NODES[@]}"; do
	for DELAY in "${PDELAYS[@]}"; do
		for BW in "${BANDWIDTHS[@]}"; do
			N_PER_TOR=$NUM_NODES
			N_TORS=$((NUM_NODES / N_PER_TOR))
			N_TORS=$((N_TORS+1)) # for the optical pcie
			N_SPINES=0
			python generate-photonic-interconnect.py -l ${DELAY} -nicbw ${BW} -g ${NUM_NODES} -tors ${N_TORS} -spines ${N_SPINES} -topo ring
		done
	done
done


########################################################################
# Generate network config files
cd $NETWORK_DIR
for IDX in ${!MSG_NAMES[@]};do
	MSG_NAME=${MSG_NAMES[$IDX]}
for APP_LOADBALANCE_ALG in ${APP_LOADBALANCE_ALGS[@]}; do
for ALG in ${ALGS[@]}; do
for NUM_NODES in ${NODES[@]}; do
	N_PER_TOR=$NUM_NODES
	N_TORS=$((NUM_NODES / N_PER_TOR))
	N_TORS=$((N_TORS+1))
	N_SPINES=0
	for ROUTING in ${ROUTING_ALGS[@]}; do
	for ALPHA_DELTA_ID in ${!ALPHA_DELAYS[@]};do
		ALPHA=${ALPHA_DELAYS[$ALPHA_DELTA_ID]}
		PDELAY=${PDELAYS[$ALPHA_DELTA_ID]}
	for RECONF in ${RECONFIG_DELAYS[@]}; do
	for BW in ${BANDWIDTHS[@]}; do
		echo "Generating network configs"
		cp $BASE_CONFIG_DIR/config-optical-base.txt config-optical-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt
		sed -i "s|TOPOLOGY_FILE .*|TOPOLOGY_FILE acad/network-topologies/optical-${N_TORS}-${NUM_NODES}-${PDELAY}-${BW}.txt|g" config-optical-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt
		sed -i "s|TRACE_OUTPUT_FILE .*|TRACE_OUTPUT_FILE ${RESULTS_DIR}/mix/mix-optical-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.tr|g" config-optical-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt
		sed -i "s|FCT_OUTPUT_FILE .*|FCT_OUTPUT_FILE ${RESULTS_DIR}/fct/fct-optical-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt|g" config-optical-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt
		sed -i "s|PFC_OUTPUT_FILE .*|PFC_OUTPUT_FILE ${RESULTS_DIR}/pfc/pfc-optical-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt|g" config-optical-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt
		sed -i "s|QLEN_MON_FILE .*|QLEN_MON_FILE ${RESULTS_DIR}/qlen/qlen-optical-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt|g" config-optical-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt

		sed -i "s|SOURCE_ROUTING .*|SOURCE_ROUTING 0|g" config-optical-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt
		sed -i "s|REPS .*|REPS 0|g" config-optical-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt
		sed -i "s|REPSv4 .*|REPSv4 0|g" config-optical-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt
		sed -i "s|END_HOST_SPRAY .*|END_HOST_SPRAY 0|g" config-optical-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt
		sed -i "s|OPTICAL .*|OPTICAL 0|g" config-optical-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt

		sed -i "s|${ROUTING} .*|${ROUTING} 1|g" config-optical-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt

		if [[ $ALG == "ring" ]];then
			sed -i "s|STPRIO .*|STPRIO 1|g" config-optical-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt
		else
			sed -i "s|STPRIO .*|STPRIO 0|g" config-optical-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt
		fi
	done
	done
	done
	done
done
done
done
done

#Generate network configs for static and bvn files
cd $NETWORK_DIR
for IDX in ${!MSG_NAMES[@]};do
	MSG_NAME=${MSG_NAMES[$IDX]}
for APP_LOADBALANCE_ALG in ${APP_LOADBALANCE_ALGS[@]}; do
for ALG in ${ALGS[@]}; do
for NUM_NODES in ${NODES[@]}; do
	N_PER_TOR=$NUM_NODES
	N_TORS=$((NUM_NODES / N_PER_TOR))
	N_TORS=$((N_TORS+1))
	N_SPINES=0
	for ROUTING in ${ROUTING_ALGS[@]}; do
	for ALPHA_DELTA_ID in ${!ALPHA_DELAYS[@]};do
		ALPHA=${ALPHA_DELAYS[$ALPHA_DELTA_ID]}
		PDELAY=${PDELAYS[$ALPHA_DELTA_ID]}
	# for ALPHA in ${ALPHA_DELAYS[@]}; do
	# for PDELAY in ${PDELAYS[@]}; do
	for BW in ${BANDWIDTHS[@]}; do
		echo "Generating network configs"
		cp $BASE_CONFIG_DIR/config-optical-base.txt config-static-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}.txt
		sed -i "s|TOPOLOGY_FILE .*|TOPOLOGY_FILE acad/network-topologies/optical-${N_TORS}-${NUM_NODES}-${PDELAY}-${BW}.txt|g" config-static-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}.txt
		sed -i "s|TRACE_OUTPUT_FILE .*|TRACE_OUTPUT_FILE ${RESULTS_DIR}/mix/mix-static-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}.tr|g" config-static-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}.txt
		sed -i "s|FCT_OUTPUT_FILE .*|FCT_OUTPUT_FILE ${RESULTS_DIR}/fct/fct-static-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}.txt|g" config-static-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}.txt
		sed -i "s|PFC_OUTPUT_FILE .*|PFC_OUTPUT_FILE ${RESULTS_DIR}/pfc/pfc-static-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}.txt|g" config-static-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}.txt
		sed -i "s|QLEN_MON_FILE .*|QLEN_MON_FILE ${RESULTS_DIR}/qlen/qlen-static-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}.txt|g" config-static-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}.txt

		sed -i "s|SOURCE_ROUTING .*|SOURCE_ROUTING 0|g" config-static-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}.txt
		sed -i "s|REPS .*|REPS 0|g" config-static-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}.txt
		sed -i "s|REPSv4 .*|REPSv4 0|g" config-static-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}.txt
		sed -i "s|END_HOST_SPRAY .*|END_HOST_SPRAY 0|g" config-static-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}.txt
		sed -i "s|OPTICAL .*|OPTICAL 0|g" config-static-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}.txt

		sed -i "s|${ROUTING} .*|${ROUTING} 1|g" config-static-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}.txt

		if [[ $ALG == "ring" ]];then
			sed -i "s|STPRIO .*|STPRIO 1|g" config-static-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}.txt
		else
			sed -i "s|STPRIO .*|STPRIO 0|g" config-static-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}.txt
		fi


		# for RECONF in ${RECONFIG_DELAYS[@]}; do
		RECONF="0"
			echo "Generating network configs"
			cp $BASE_CONFIG_DIR/config-optical-base.txt config-bvn-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt
			sed -i "s|TOPOLOGY_FILE .*|TOPOLOGY_FILE acad/network-topologies/optical-${N_TORS}-${NUM_NODES}-${PDELAY}-${BW}.txt|g" config-bvn-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt
			sed -i "s|TRACE_OUTPUT_FILE .*|TRACE_OUTPUT_FILE ${RESULTS_DIR}/mix/mix-bvn-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.tr|g" config-bvn-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt
			sed -i "s|FCT_OUTPUT_FILE .*|FCT_OUTPUT_FILE ${RESULTS_DIR}/fct/fct-bvn-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt|g" config-bvn-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt
			sed -i "s|PFC_OUTPUT_FILE .*|PFC_OUTPUT_FILE ${RESULTS_DIR}/pfc/pfc-bvn-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt|g" config-bvn-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt
			sed -i "s|QLEN_MON_FILE .*|QLEN_MON_FILE ${RESULTS_DIR}/qlen/qlen-bvn-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt|g" config-bvn-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt

			sed -i "s|SOURCE_ROUTING .*|SOURCE_ROUTING 0|g" config-bvn-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt
			sed -i "s|REPS .*|REPS 0|g" config-bvn-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt
			sed -i "s|REPSv4 .*|REPSv4 0|g" config-bvn-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt
			sed -i "s|END_HOST_SPRAY .*|END_HOST_SPRAY 0|g" config-bvn-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt
			sed -i "s|OPTICAL .*|OPTICAL 0|g" config-bvn-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt

			sed -i "s|${ROUTING} .*|${ROUTING} 1|g" config-bvn-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt

			if [[ $ALG == "ring" ]];then
				sed -i "s|STPRIO .*|STPRIO 1|g" config-bvn-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt
			else
				sed -i "s|STPRIO .*|STPRIO 0|g" config-bvn-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${PDELAY}-${BW}-${RECONF}.txt
			fi
		# done
	done
	done
	done
done
done
done
done







##################################################################
# Generate non static topologies
COLLECTIVE_PORT=1
cd $SCRIPT_DIR
NUM_EXPS=0
for N in ${NODES[@]};do
	for BW in ${BANDWIDTHS[@]};do
		for ALPHA_DELTA_ID in ${!ALPHA_DELAYS[@]};do
			ALPHA=${ALPHA_DELAYS[$ALPHA_DELTA_ID]}
			DELTA=${PDELAYS[$ALPHA_DELTA_ID]}
			for ALPHA_R in ${RECONFIG_DELAYS[@]};do
				for ALG_ID in ${!ALGS[@]};do
					ALG_IN_ASTRA=${ALGS[$ALG_ID]}
					ALG_IN_HARVEST=${ALGS_TOPO[$ALG_ID]}
					if [[ "$ALG_IN_HARVEST" == "all-reduce-swing-nd" ]]; then
						PORT=2
					else
						PORT=1
					fi
					for IDX in ${!MSG_SIZES[@]};do
						MESSAGE_SIZE=${MSG_SIZES[$IDX]}
						MESSAGE_NAME=${MSG_NAMES[$IDX]}
						COLLECTIVE_FILE=$COLL_DIR/collective-$ALG_IN_HARVEST-$N-$COLLECTIVE_PORT-$MESSAGE_NAME.json
						OUTFILE=$OPTICAL_ROUTING_DIR/harvest-$ALG_IN_ASTRA-$N-$PORT-$MESSAGE_NAME-$BW-$ALPHA-$DELTA-$ALPHA_R-$RELAXATION.json
						NUM_EXPS=$(( $NUM_EXPS + 1 ))
						echo "Starting synthesis for $OUTFILE"
						while [[ $(ps aux | grep '/bin/bash ./synthesize-schedule' | wc -l) -gt $NUM_PARALLEL ]];do
							sleep 2
							echo "waiting at $NUM_EXPS..."
						done
						echo "Running: synthesize-schedule $COLLECTIVE_FILE $PORT $BW $ALPHA $DELTA $ALPHA_R $LOGGING $RELAXATION $RD $OUTFILE"
						time (
							./synthesize-schedule $COLLECTIVE_FILE $PORT $BW $ALPHA $DELTA $ALPHA_R $LOGGING $RELAXATION $RD $OUTFILE
							echo "################################"
							echo "Finished synthesis for $COLLECTIVE_FILE $PORT $BW $ALPHA $DELTA $ALPHA_R $LOGGING $RELAXATION"
							echo "$OUTFILE"
							echo "############################"
						) &
						sleep 0.5
					done
				done
			done
		done
	done
done

#####################################################################
# Generate static and bvn topo file
cd $SCRIPT_DIR
COLLECTIVE_PORT=1
DUMMY_MSG_SIZE=256MB
DUMMY_BW=800
DUMMY_ALPHA=1000
DUMMY_DELTA=1000
HIGH_RECONFIG_DELAY_FOR_NO_RECONFIG=100000000 # in ns
for N in ${NODES[@]};do
	for ALG_ID in ${!ALGS[@]};do
		ALG_IN_ASTRA=${ALGS[$ALG_ID]}
		ALG_IN_HARVEST=${ALGS_TOPO[$ALG_ID]}

		if [[ "$ALG_IN_HARVEST" == "all-reduce-swing-nd" ]]; then
			PORT=2
		else
			PORT=1
		fi

		STATIC_OUTFILE=$OPTICAL_ROUTING_DIR/static-$ALG_IN_ASTRA-$N-$PORT.json
		COLLECTIVE_FILE=$COLL_DIR/collective-$ALG_IN_HARVEST-$N-$COLLECTIVE_PORT-$DUMMY_MSG_SIZE.json

		if [[ ! -f "$COLLECTIVE_FILE" ]]; then
			echo "MISSING: $COLLECTIVE_FILE."
		fi
		time (./synthesize-schedule $COLLECTIVE_FILE $PORT $DUMMY_BW $DUMMY_ALPHA $DUMMY_DELTA $HIGH_RECONFIG_DELAY_FOR_NO_RECONFIG $LOGGING $RELAXATION $RD $STATIC_OUTFILE)

		### ---- STATIC file check ----
		num_reconfigs=$(grep -oP '"num_of_reconfigs"\s*:\s*\K[0-9]+' "$STATIC_OUTFILE")
		if [[ "$num_reconfigs" -ne 0 ]]; then
			echo "ERROR: num_of_reconfigs != 0 in $STATIC_OUTFILE."
			echo "You need to run the synthesis with a higher reconfig delay"
			echo "and correctly set HIGH_RECONFIG_DELAY_FOR_NO_RECONFIG in this script as well"
		fi

		BVN_OUTFILE=$OPTICAL_ROUTING_DIR/bvn-$ALG_IN_ASTRA-$N-$PORT-0.json
		BVN_INFILE=$OPTICAL_ROUTING_DIR/harvest-$ALG_IN_ASTRA-$N-$PORT-$DUMMY_MSG_SIZE-$DUMMY_BW-$DUMMY_ALPHA-$DUMMY_DELTA-0-$RELAXATION.json # Need the 0 ns one
		### ---- BVN file check ----
		if [[ ! -f "$BVN_INFILE" ]]; then
			echo "MISSING: $BVN_INFILE."
			echo "Please generate topology file for 0 ns reconfig with msg size: $DUMMY_MSG_SIZE"
		else
			cp -f "$BVN_INFILE" "$BVN_OUTFILE"
		fi
	done
done