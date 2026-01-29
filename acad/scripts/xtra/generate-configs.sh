#!/bin/bash

# find the absolute path to this script
source config.sh

NODES=(256)
MSG_SIZES=(1000000 2000000 4000000 8000000 16000000 32000000 64000000 128000000 256000000)
TXT_WORKLOADS=("Gpt_117M")
ALLREDUCE_ALGS=("direct" "halvingDoubling" "ring" "doubleBinaryTree")
APP_LOADBALANCE_ALGS=("ethereal" "mp-rdma-2" "mp-rdma-4" "mp-rdma-8" "none")
ROUTING_ALGS=("SOURCE_ROUTING" "REPS" "REPSv4" "END_HOST_SPRAY" "ECMP")

K=8
NODES_FT=512
## Hmm, it is probably better to generate these config files in-place in the respective scripts where needed.

# First, generate txt workload files
cd $TXT_WORKLOAD_DIR
for NUM_NODES in "${NODES[@]}"; do
	for MSG_SIZE in ${MSG_SIZES[@]};do
		echo "MICRO" > AllReduce-$NUM_NODES-$MSG_SIZE-leaf-spine.txt
		echo "1" >> AllReduce-$NUM_NODES-$MSG_SIZE-leaf-spine.txt
		echo "conv1 -1 5 NONE 0 5 NONE 0 5  ALLREDUCE $MSG_SIZE 5" >> AllReduce-$NUM_NODES-$MSG_SIZE-leaf-spine.txt
	done
	for TXT_WORKLOAD in ${TXT_WORKLOADS[@]};do
		cp "$BASE_CONFIG_DIR"/"$TXT_WORKLOAD".txt "$TXT_WORKLOAD_DIR"/$TXT_WORKLOAD-$NUM_NODES-leaf-spine.txt
	done
done
for MSG_SIZE in ${MSG_SIZES[@]};do
	echo "MICRO" > AllReduce-$K-$MSG_SIZE-fat-tree.txt
	echo "1" >> AllReduce-$K-$MSG_SIZE-fat-tree.txt
	echo "conv1 -1 5 NONE 0 5 NONE 0 5  ALLREDUCE $MSG_SIZE 5" >> AllReduce-$K-$MSG_SIZE-fat-tree.txt
done
for TXT_WORKLOAD in ${TXT_WORKLOADS[@]};do
	cp "$BASE_CONFIG_DIR"/"$TXT_WORKLOAD".txt "$TXT_WORKLOAD_DIR"/$TXT_WORKLOAD-$K-fat-tree.txt
done

# Next, generate et workload files
cd $SCRIPT_DIR
for NUM_NODES in "${NODES[@]}"; do
	for MSG_SIZE in ${MSG_SIZES[@]};do
		./chakra-text-to-et.sh AllReduce-$NUM_NODES-$MSG_SIZE-leaf-spine $NUM_NODES 1
	done
	for TXT_WORKLOAD in ${TXT_WORKLOADS[@]};do
		./chakra-text-to-et.sh $TXT_WORKLOAD-$NUM_NODES-leaf-spine $NUM_NODES 1
	done
done
for MSG_SIZE in ${MSG_SIZES[@]};do
	./chakra-text-to-et.sh AllReduce-$K-$MSG_SIZE-fat-tree $NODES_FT 1
done
for TXT_WORKLOAD in ${TXT_WORKLOADS[@]};do
	./chakra-text-to-et.sh $TXT_WORKLOAD-$K-fat-tree $NODES_FT 1
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
    for ALLREDUCE_ALG in ${ALLREDUCE_ALGS[@]}; do
        cp $BASE_CONFIG_DIR/system.json system-$ALLREDUCE_ALG-$APP_LOADBALANCE_ALG.json
        perl -0777 -i -pe "s/\"all-reduce-implementation\":\s*\[\s*\"ring\"\s*\]/\"all-reduce-implementation\": [\"$ALLREDUCE_ALG\"]/g" system-$ALLREDUCE_ALG-$APP_LOADBALANCE_ALG.json
		perl -0777 -i -pe "s/\"all-gather-implementation\":\s*\[\s*\"ring\"\s*\]/\"all-gather-implementation\": [\"$ALLREDUCE_ALG\"]/g" system-$ALLREDUCE_ALG-$APP_LOADBALANCE_ALG.json
		perl -0777 -i -pe "s/\"all-to-all-implementation\":\s*\[\s*\"ring\"\s*\]/\"all-to-all-implementation\": [\"direct\"]/g" system-$ALLREDUCE_ALG-$APP_LOADBALANCE_ALG.json
		perl -0777 -i -pe "s/\"reduce-scatter-implementation\":\s*\[\s*\"ring\"\s*\]/\"reduce-scatter-implementation\": [\"$ALLREDUCE_ALG\"]/g" system-$ALLREDUCE_ALG-$APP_LOADBALANCE_ALG.json
        
        if [[ $APP_LOADBALANCE_ALG == "mp-rdma-2" ]]; then
            sed -i "s|\"app-load-balance\": \"none\"|\"app-load-balance\": \"mp-rdma\"|g" system-$ALLREDUCE_ALG-$APP_LOADBALANCE_ALG.json
            sed -i "s|\"mp-rdma-qp\": 2|\"mp-rdma-qp\": 2|g" system-$ALLREDUCE_ALG-$APP_LOADBALANCE_ALG.json
        elif [[ $APP_LOADBALANCE_ALG == "mp-rdma-4" ]]; then
            sed -i "s|\"app-load-balance\": \"none\"|\"app-load-balance\": \"mp-rdma\"|g" system-$ALLREDUCE_ALG-$APP_LOADBALANCE_ALG.json
            sed -i "s|\"mp-rdma-qp\": 2|\"mp-rdma-qp\": 4|g" system-$ALLREDUCE_ALG-$APP_LOADBALANCE_ALG.json
        elif [[ $APP_LOADBALANCE_ALG == "mp-rdma-8" ]]; then
            sed -i "s|\"app-load-balance\": \"none\"|\"app-load-balance\": \"mp-rdma\"|g" system-$ALLREDUCE_ALG-$APP_LOADBALANCE_ALG.json
            sed -i "s|\"mp-rdma-qp\": 2|\"mp-rdma-qp\": 8|g" system-$ALLREDUCE_ALG-$APP_LOADBALANCE_ALG.json
        else
            sed -i "s|\"app-load-balance\": \"none\"|\"app-load-balance\": \"$APP_LOADBALANCE_ALG\"|g" system-$ALLREDUCE_ALG-$APP_LOADBALANCE_ALG.json
        fi
    done
done

#########################################################################
# Generate network topology files
cd $SCRIPT_DIR
N_PER_TOR=16 # Tomahawk 3, 32-port switch, 64MB Shared buffer

# Leaf-spine topologies
for NUM_NODES in "${NODES[@]}"; do
    N_TORS=$((NUM_NODES / N_PER_TOR))
    python generate-topology.py -l 0.0005ms -nicbw 400Gbps -t1bw 400Gbps -g $NUM_NODES -tors ${N_TORS} -spines ${N_TORS} -topo leafspine
done

# k-ary fat-tree k=8. Total 512 nodes, oversub 4:1 (in terms of the number of links)
python generate-topology.py -l 0.0005ms -nicbw 400Gbps -t1bw 1600Gbps -t2bw 1600Gbps -topo fattree -k $K -os 4

#########################################################################
# Generate network config files
# Some unnecessary files may be generated but it's fine
WINDOWS=(16 32 64 128 256)
cd $NETWORK_DIR
for MSG_SIZE in ${MSG_SIZES[@]};do
	for APP_LOADBALANCE_ALG in ${APP_LOADBALANCE_ALGS[@]}; do
	    for ALLREDUCE_ALG in ${ALLREDUCE_ALGS[@]}; do
			for NUM_NODES in ${NODES[@]}; do
			    N_TORS=$((NUM_NODES / N_PER_TOR))
			    for ROUTING in ${ROUTING_ALGS[@]}; do
			        cp $BASE_CONFIG_DIR/config.txt config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt
			        sed -i "s|TOPOLOGY_FILE .*|TOPOLOGY_FILE acad/network-topologies/leaf-spine-${N_TORS}-${N_TORS}-${NUM_NODES}.txt|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt
			        sed -i "s|TRACE_OUTPUT_FILE .*|TRACE_OUTPUT_FILE acad/results/mix-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.tr|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt
			        sed -i "s|FCT_OUTPUT_FILE .*|FCT_OUTPUT_FILE acad/results/fct-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt
			        sed -i "s|PFC_OUTPUT_FILE .*|PFC_OUTPUT_FILE acad/results/pfc-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt
			        sed -i "s|QLEN_MON_FILE .*|QLEN_MON_FILE acad/results/qlen-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt

			        sed -i "s|SOURCE_ROUTING .*|SOURCE_ROUTING 0|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt
			        sed -i "s|REPS .*|REPS 0|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt
			        sed -i "s|REPSv4 .*|REPSv4 0|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt
			        sed -i "s|END_HOST_SPRAY .*|END_HOST_SPRAY 0|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt

			        sed -i "s|${ROUTING} .*|${ROUTING} 1|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt

			        if [[ $ALLREDUCE_ALG == "ring" ]];then
			        	sed -i "s|STPRIO .*|STPRIO 1|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt
			        else
			        	sed -i "s|STPRIO .*|STPRIO 0|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt
			        fi
			        for WINDOW in ${WINDOWS[@]};do
			        	cp $BASE_CONFIG_DIR/config.txt config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${WINDOW}.txt
				        sed -i "s|TOPOLOGY_FILE .*|TOPOLOGY_FILE acad/network-topologies/leaf-spine-${N_TORS}-${N_TORS}-${NUM_NODES}.txt|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${WINDOW}.txt
				        sed -i "s|TRACE_OUTPUT_FILE .*|TRACE_OUTPUT_FILE acad/results/mix-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${WINDOW}.tr|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${WINDOW}.txt
				        sed -i "s|FCT_OUTPUT_FILE .*|FCT_OUTPUT_FILE acad/results/fct-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${WINDOW}.txt|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${WINDOW}.txt
				        sed -i "s|PFC_OUTPUT_FILE .*|PFC_OUTPUT_FILE acad/results/pfc-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${WINDOW}.txt|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${WINDOW}.txt
				        sed -i "s|QLEN_MON_FILE .*|QLEN_MON_FILE acad/results/qlen-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${WINDOW}.txt|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${WINDOW}.txt

				        sed -i "s|SOURCE_ROUTING .*|SOURCE_ROUTING 0|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${WINDOW}.txt
				        sed -i "s|REPS .*|REPS 0|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${WINDOW}.txt
				        sed -i "s|REPSv4 .*|REPSv4 0|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${WINDOW}.txt
				        sed -i "s|END_HOST_SPRAY .*|END_HOST_SPRAY 0|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${WINDOW}.txt

				        sed -i "s|${ROUTING} .*|${ROUTING} 1|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${WINDOW}.txt

				        if [[ $ALLREDUCE_ALG == "ring" ]];then
				        	sed -i "s|STPRIO .*|STPRIO 1|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${WINDOW}.txt
				        else
				        	sed -i "s|STPRIO .*|STPRIO 0|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${WINDOW}.txt
				        fi
				    done
			    done
			done
		done
	done
done
for TXT_WORKLOAD in ${TXT_WORKLOADS[@]};do
	for APP_LOADBALANCE_ALG in ${APP_LOADBALANCE_ALGS[@]}; do
	    for ALLREDUCE_ALG in ${ALLREDUCE_ALGS[@]}; do
			for NUM_NODES in ${NODES[@]}; do
			    N_TORS=$((NUM_NODES / N_PER_TOR))
			    for ROUTING in ${ROUTING_ALGS[@]}; do
			        cp $BASE_CONFIG_DIR/config.txt config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt
			        sed -i "s|TOPOLOGY_FILE .*|TOPOLOGY_FILE acad/network-topologies/leaf-spine-${N_TORS}-${N_TORS}-${NUM_NODES}.txt|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt
			        sed -i "s|TRACE_OUTPUT_FILE .*|TRACE_OUTPUT_FILE acad/results/mix-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.tr|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt
			        sed -i "s|FCT_OUTPUT_FILE .*|FCT_OUTPUT_FILE acad/results/fct-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt
			        sed -i "s|PFC_OUTPUT_FILE .*|PFC_OUTPUT_FILE acad/results/pfc-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt
			        sed -i "s|QLEN_MON_FILE .*|QLEN_MON_FILE acad/results/qlen-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt

			        sed -i "s|SOURCE_ROUTING .*|SOURCE_ROUTING 0|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt
			        sed -i "s|REPS .*|REPS 0|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt
			        sed -i "s|REPSv4 .*|REPSv4 0|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt
			        sed -i "s|END_HOST_SPRAY .*|END_HOST_SPRAY 0|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt

			        sed -i "s|${ROUTING} .*|${ROUTING} 1|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt

			        if [[ $ALLREDUCE_ALG == "ring" ]];then
			        	sed -i "s|STPRIO .*|STPRIO 1|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt
			        else
			        	sed -i "s|STPRIO .*|STPRIO 0|g" config-leaf-spine-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt
			        fi
			    done
			done
		done
	done
done

for MSG_SIZE in ${MSG_SIZES[@]};do
	for APP_LOADBALANCE_ALG in ${APP_LOADBALANCE_ALGS[@]}; do
	    for ALLREDUCE_ALG in ${ALLREDUCE_ALGS[@]}; do
			for ROUTING in ${ROUTING_ALGS[@]}; do
			    cp $BASE_CONFIG_DIR/config.txt config-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt
			    sed -i "s|TOPOLOGY_FILE .*|TOPOLOGY_FILE acad/network-topologies/fat-tree-$K.txt|g" config-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt
			    sed -i "s|TRACE_OUTPUT_FILE .*|TRACE_OUTPUT_FILE acad/results/mix-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.tr|g" config-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt
			    sed -i "s|FCT_OUTPUT_FILE .*|FCT_OUTPUT_FILE acad/results/fct-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt|g" config-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt
			    sed -i "s|PFC_OUTPUT_FILE .*|PFC_OUTPUT_FILE acad/results/pfc-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt|g" config-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt
			    sed -i "s|QLEN_MON_FILE .*|QLEN_MON_FILE acad/results/qlen-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt|g" config-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt

			    sed -i "s|SOURCE_ROUTING .*|SOURCE_ROUTING 0|g" config-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt
			    sed -i "s|REPS .*|REPS 0|g" config-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt
			    sed -i "s|REPSv4 .*|REPSv4 0|g" config-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt
			    sed -i "s|END_HOST_SPRAY .*|END_HOST_SPRAY 0|g" config-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt

			    sed -i "s|${ROUTING} .*|${ROUTING} 1|g" config-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt

			    if [[ $ALLREDUCE_ALG == "ring" ]];then
		        	sed -i "s|STPRIO .*|STPRIO 1|g" config-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt
		        else
		        	sed -i "s|STPRIO .*|STPRIO 0|g" config-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}.txt
		        fi
			done
		done
	done
done

for TXT_WORKLOAD in ${TXT_WORKLOADS[@]};do
	for APP_LOADBALANCE_ALG in ${APP_LOADBALANCE_ALGS[@]}; do
	    for ALLREDUCE_ALG in ${ALLREDUCE_ALGS[@]}; do
			for ROUTING in ${ROUTING_ALGS[@]}; do
			    cp $BASE_CONFIG_DIR/config.txt config-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt
			    sed -i "s|TOPOLOGY_FILE .*|TOPOLOGY_FILE acad/network-topologies/fat-tree-$K.txt|g" config-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt
			    sed -i "s|TRACE_OUTPUT_FILE .*|TRACE_OUTPUT_FILE acad/results/mix-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.tr|g" config-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt
			    sed -i "s|FCT_OUTPUT_FILE .*|FCT_OUTPUT_FILE acad/results/fct-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt|g" config-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt
			    sed -i "s|PFC_OUTPUT_FILE .*|PFC_OUTPUT_FILE acad/results/pfc-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt|g" config-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt
			    sed -i "s|QLEN_MON_FILE .*|QLEN_MON_FILE acad/results/qlen-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt|g" config-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt

			    sed -i "s|SOURCE_ROUTING .*|SOURCE_ROUTING 0|g" config-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt
			    sed -i "s|REPS .*|REPS 0|g" config-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt
			    sed -i "s|REPSv4 .*|REPSv4 0|g" config-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt
			    sed -i "s|END_HOST_SPRAY .*|END_HOST_SPRAY 0|g" config-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt

			    sed -i "s|${ROUTING} .*|${ROUTING} 1|g" config-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt

			    if [[ $ALLREDUCE_ALG == "ring" ]];then
		        	sed -i "s|STPRIO .*|STPRIO 1|g" config-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt
		        else
		        	sed -i "s|STPRIO .*|STPRIO 0|g" config-fat-tree-$K-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt
		        fi
			done
		done
	done
done



cd $SCRIPT_DIR