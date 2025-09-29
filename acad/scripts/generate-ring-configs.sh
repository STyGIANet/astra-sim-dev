#!/bin/bash

# find the absolute path to this script
source config.sh

NODES=(8 16)
MSG_SIZES=(1000000 2000000 4000000 8000000 16000000 32000000 64000000 128000000 256000000)
ALLGATHER_ALGS=("direct" "halvingDoubling" "ring" "doubleBinaryTree")
APP_LOADBALANCE_ALGS=("none")
ROUTING_ALGS=("ECMP")

# First, generate txt workload files
cd $TXT_WORKLOAD_DIR
for NUM_NODES in "${NODES[@]}"; do
	for MSG_SIZE in ${MSG_SIZES[@]};do
		echo "MICRO" > AllGather-$NUM_NODES-$MSG_SIZE-ring.txt
		echo "1" >> AllGather-$NUM_NODES-$MSG_SIZE-ring.txt
		echo "conv1 -1 5 NONE 0 5 NONE 0 5  ALLGATHER $MSG_SIZE 5" >> AllGather-$NUM_NODES-$MSG_SIZE-ring.txt
	done
done
for NUM_NODES in "${NODES[@]}"; do
	for MSG_SIZE in ${MSG_SIZES[@]};do
		echo "MICRO" > ReduceScatter-$NUM_NODES-$MSG_SIZE-ring.txt
		echo "1" >> ReduceScatter-$NUM_NODES-$MSG_SIZE-ring.txt
		echo "conv1 -1 5 NONE 0 5 NONE 0 5  REDUCESCATTER $MSG_SIZE 5" >> ReduceScatter-$NUM_NODES-$MSG_SIZE-ring.txt
	done
done
for NUM_NODES in "${NODES[@]}"; do
	for MSG_SIZE in ${MSG_SIZES[@]};do
		echo "MICRO" > AllReduce-$NUM_NODES-$MSG_SIZE-ring.txt
		echo "1" >> AllReduce-$NUM_NODES-$MSG_SIZE-ring.txt
		echo "conv1 -1 5 NONE 0 5 NONE 0 5  ALLREDUCE $MSG_SIZE 5" >> AllReduce-$NUM_NODES-$MSG_SIZE-ring.txt
	done
done

# Next, generate et workload files
cd $SCRIPT_DIR
for NUM_NODES in "${NODES[@]}"; do
	for MSG_SIZE in ${MSG_SIZES[@]};do
		./chakra-text-to-et.sh AllGather-$NUM_NODES-$MSG_SIZE-ring $NUM_NODES 1
	done
done
for NUM_NODES in "${NODES[@]}"; do
	for MSG_SIZE in ${MSG_SIZES[@]};do
		./chakra-text-to-et.sh ReduceScatter-$NUM_NODES-$MSG_SIZE-ring $NUM_NODES 1
	done
done
for NUM_NODES in "${NODES[@]}"; do
	for MSG_SIZE in ${MSG_SIZES[@]};do
		./chakra-text-to-et.sh AllReduce-$NUM_NODES-$MSG_SIZE-ring $NUM_NODES 1
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

echo "Generating logical topology files for $NODES_FT nodes"
echo "{" > logical-topo-$NODES_FT.json
echo "    \"logical-dims\": [\"$NODES_FT\"]" >> logical-topo-$NODES_FT.json
echo "}" >> logical-topo-$NODES_FT.json

#########################################################################
# Generate sys config files
cd $SYSTEM_DIR

for APP_LOADBALANCE_ALG in ${APP_LOADBALANCE_ALGS[@]}; do
    for ALLGATHER_ALG in ${ALLGATHER_ALGS[@]}; do
        cp $BASE_CONFIG_DIR/system.json system-$ALLGATHER_ALG-$APP_LOADBALANCE_ALG.json
        perl -0777 -i -pe "s/\"all-reduce-implementation\":\s*\[\s*\"ring\"\s*\]/\"all-reduce-implementation\": [\"$ALLGATHER_ALG\"]/g" system-$ALLGATHER_ALG-$APP_LOADBALANCE_ALG.json
		perl -0777 -i -pe "s/\"all-gather-implementation\":\s*\[\s*\"ring\"\s*\]/\"all-gather-implementation\": [\"$ALLGATHER_ALG\"]/g" system-$ALLGATHER_ALG-$APP_LOADBALANCE_ALG.json
		perl -0777 -i -pe "s/\"all-to-all-implementation\":\s*\[\s*\"ring\"\s*\]/\"all-to-all-implementation\": [\"direct\"]/g" system-$ALLGATHER_ALG-$APP_LOADBALANCE_ALG.json
		perl -0777 -i -pe "s/\"reduce-scatter-implementation\":\s*\[\s*\"ring\"\s*\]/\"reduce-scatter-implementation\": [\"$ALLGATHER_ALG\"]/g" system-$ALLGATHER_ALG-$APP_LOADBALANCE_ALG.json
        
        sed -i "s|\"app-load-balance\": \"none\"|\"app-load-balance\": \"$APP_LOADBALANCE_ALG\"|g" system-$ALLGATHER_ALG-$APP_LOADBALANCE_ALG.json
    done
done

#########################################################################
# Generate network topology files
cd $SCRIPT_DIR

# Leaf-spine topologies
for NUM_NODES in "${NODES[@]}"; do
    N_TORS=1 # We don't need it in the current set of experiments
    python generate-topology.py -l 0.0005ms -nicbw 400Gbps -g $NUM_NODES -topo ring
done


#########################################################################
# Generate network config files
# Some unnecessary files may be generated but it's fine
cd $NETWORK_DIR
for MSG_SIZE in ${MSG_SIZES[@]};do
	for APP_LOADBALANCE_ALG in ${APP_LOADBALANCE_ALGS[@]}; do
	    for ALLGATHER_ALG in ${ALLGATHER_ALGS[@]}; do
			for NUM_NODES in ${NODES[@]}; do
			    for ROUTING in ${ROUTING_ALGS[@]}; do
			        cp $BASE_CONFIG_DIR/config.txt config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLGATHER_ALG}-${MSG_SIZE}.txt
			        sed -i "s|TOPOLOGY_FILE .*|TOPOLOGY_FILE acad/network-topologies/ring-${NUM_NODES}.txt|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLGATHER_ALG}-${MSG_SIZE}.txt
			        sed -i "s|TRACE_OUTPUT_FILE .*|TRACE_OUTPUT_FILE acad/results/mix-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLGATHER_ALG}-${MSG_SIZE}.tr|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLGATHER_ALG}-${MSG_SIZE}.txt
			        sed -i "s|FCT_OUTPUT_FILE .*|FCT_OUTPUT_FILE acad/results/fct-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLGATHER_ALG}-${MSG_SIZE}.txt|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLGATHER_ALG}-${MSG_SIZE}.txt
			        sed -i "s|PFC_OUTPUT_FILE .*|PFC_OUTPUT_FILE acad/results/pfc-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLGATHER_ALG}-${MSG_SIZE}.txt|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLGATHER_ALG}-${MSG_SIZE}.txt
			        sed -i "s|QLEN_MON_FILE .*|QLEN_MON_FILE acad/results/qlen-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLGATHER_ALG}-${MSG_SIZE}.txt|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLGATHER_ALG}-${MSG_SIZE}.txt

			        sed -i "s|SOURCE_ROUTING .*|SOURCE_ROUTING 0|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLGATHER_ALG}-${MSG_SIZE}.txt
			        sed -i "s|REPS .*|REPS 0|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLGATHER_ALG}-${MSG_SIZE}.txt
			        sed -i "s|REPSv4 .*|REPSv4 0|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLGATHER_ALG}-${MSG_SIZE}.txt
			        sed -i "s|END_HOST_SPRAY .*|END_HOST_SPRAY 0|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLGATHER_ALG}-${MSG_SIZE}.txt

			        sed -i "s|${ROUTING} .*|${ROUTING} 1|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLGATHER_ALG}-${MSG_SIZE}.txt

			        if [[ $ALLGATHER_ALG == "ring" ]];then
			        	sed -i "s|STPRIO .*|STPRIO 1|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLGATHER_ALG}-${MSG_SIZE}.txt
			        else
			        	sed -i "s|STPRIO .*|STPRIO 0|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLGATHER_ALG}-${MSG_SIZE}.txt
			        fi
			    done
			done
		done
	done
done

cd $SCRIPT_DIR