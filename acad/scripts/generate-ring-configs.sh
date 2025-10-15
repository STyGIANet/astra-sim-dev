#!/bin/bash

# find the absolute path to this script
source config.sh

NODES=(8 16 32 64)
MSG_SIZES=(128 1000 16000 256000 4000000 64000000 256000000 1000000000)
PROPAGATION_DELAY=("0.0005ms") # Put unit for the delays (ms)!!
RECONFIG_DELAY=("0ns" "10ns" "100ns" "1000ns" "10000ns" "100000ns" "1000000ns") # Put unit for the reconfigs (ns)!!
BANDWIDTH=("400Gbps" "800Gbps" "1200Gbps" "3200Gbps") # Put unit for the bandwidth (Gbps)!!
ALPHA_DELAY=(0 10 100 1000) #units in ns!!!

ALLREDUCE_ALGS=("halvingDoubling" "direct1" "swing")
APP_LOADBALANCE_ALGS=("none")
ROUTING_ALGS=("ECMP")

K=8
NODES_FT=512
## Hmm, it is probably better to generate these config files in-place in the respective scripts where needed.

# First, generate txt workload files
# leaf spine and ring will have same txt workload files so reusing them
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
    for ALLREDUCE_ALG in ${ALLREDUCE_ALGS[@]}; do
	for ALPHA in ${ALPHA_DELAY[@]}; do
        cp $BASE_CONFIG_DIR/system.json system-$ALLREDUCE_ALG-$APP_LOADBALANCE_ALG-$ALPHA.json
        perl -0777 -i -pe "s/\"all-reduce-implementation\":\s*\[\s*\"ring\"\s*\]/\"all-reduce-implementation\": [\"$ALLREDUCE_ALG\"]/g" system-$ALLREDUCE_ALG-$APP_LOADBALANCE_ALG-$ALPHA.json
		perl -0777 -i -pe "s/\"all-gather-implementation\":\s*\[\s*\"ring\"\s*\]/\"all-gather-implementation\": [\"$ALLREDUCE_ALG\"]/g" system-$ALLREDUCE_ALG-$APP_LOADBALANCE_ALG-$ALPHA.json
		perl -0777 -i -pe "s/\"all-to-all-implementation\":\s*\[\s*\"ring\"\s*\]/\"all-to-all-implementation\": [\"direct\"]/g" system-$ALLREDUCE_ALG-$APP_LOADBALANCE_ALG-$ALPHA.json
		perl -0777 -i -pe "s/\"reduce-scatter-implementation\":\s*\[\s*\"ring\"\s*\]/\"reduce-scatter-implementation\": [\"$ALLREDUCE_ALG\"]/g" system-$ALLREDUCE_ALG-$APP_LOADBALANCE_ALG-$ALPHA.json
		sed -i "s|\"endpoint-delay\": 0|\"endpoint-delay\": $ALPHA|g" system-$ALLREDUCE_ALG-$APP_LOADBALANCE_ALG-$ALPHA.json


        if [[ $APP_LOADBALANCE_ALG == "mp-rdma-2" ]]; then
            sed -i "s|\"app-load-balance\": \"none\"|\"app-load-balance\": \"mp-rdma\"|g" system-$ALLREDUCE_ALG-$APP_LOADBALANCE_ALG-$ALPHA.json
            sed -i "s|\"mp-rdma-qp\": 2|\"mp-rdma-qp\": 2|g" system-$ALLREDUCE_ALG-$APP_LOADBALANCE_ALG-$ALPHA.json
        elif [[ $APP_LOADBALANCE_ALG == "mp-rdma-4" ]]; then
            sed -i "s|\"app-load-balance\": \"none\"|\"app-load-balance\": \"mp-rdma\"|g" system-$ALLREDUCE_ALG-$APP_LOADBALANCE_ALG-$ALPHA.json
            sed -i "s|\"mp-rdma-qp\": 2|\"mp-rdma-qp\": 4|g" system-$ALLREDUCE_ALG-$APP_LOADBALANCE_ALG-$ALPHA.json
        elif [[ $APP_LOADBALANCE_ALG == "mp-rdma-8" ]]; then
            sed -i "s|\"app-load-balance\": \"none\"|\"app-load-balance\": \"mp-rdma\"|g" system-$ALLREDUCE_ALG-$APP_LOADBALANCE_ALG-$ALPHA.json
            sed -i "s|\"mp-rdma-qp\": 2|\"mp-rdma-qp\": 8|g" system-$ALLREDUCE_ALG-$APP_LOADBALANCE_ALG-$ALPHA.json
        else
            sed -i "s|\"app-load-balance\": \"none\"|\"app-load-balance\": \"$APP_LOADBALANCE_ALG\"|g" system-$ALLREDUCE_ALG-$APP_LOADBALANCE_ALG-$ALPHA.json
        fi
	done
    done
done

#########################################################################
# Generate network topology files
cd $SCRIPT_DIR
# N_PER_TOR=8 # Tomahawk 3, 32-port switch, 64MB Shared buffer

# Leaf-spine topologies
for NUM_NODES in "${NODES[@]}"; do
	for DELAY in "${PROPAGATION_DELAY[@]}"; do
		for BW in "${BANDWIDTH[@]}"; do
            python generate-ring-interconnect.py -l ${DELAY} -nicbw ${BW} -g $NUM_NODES -tors $NUM_NODES -spines 0 -topo ring
        done
    done
done

#########################################################################
# Generate network config files
# Some unnecessary files may be generated but it's fine
WINDOWS=()
cd $NETWORK_DIR
for MSG_SIZE in ${MSG_SIZES[@]};do
	for APP_LOADBALANCE_ALG in ${APP_LOADBALANCE_ALGS[@]}; do
	    for ALLREDUCE_ALG in ${ALLREDUCE_ALGS[@]}; do
			for NUM_NODES in ${NODES[@]}; do
			    N_TORS=$((NUM_NODES / 1))
			    for ROUTING in ${ROUTING_ALGS[@]}; do
					for ALPHA in ${ALPHA_DELAY[@]}; do
                	for PDELAY in ${PROPAGATION_DELAY[@]}; do
	                for BW in ${BANDWIDTH[@]}; do
			        cp $BASE_CONFIG_DIR/config.txt config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}.txt
			        sed -i "s|TOPOLOGY_FILE .*|TOPOLOGY_FILE acad/network-topologies/ring-${N_TORS}-${NUM_NODES}-${PDELAY}-${BW}.txt|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}.txt
			        sed -i "s|TRACE_OUTPUT_FILE .*|TRACE_OUTPUT_FILE acad/results/mix-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}.tr|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}.txt
			        sed -i "s|FCT_OUTPUT_FILE .*|FCT_OUTPUT_FILE acad/results/fct-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}.txt|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}.txt
			        sed -i "s|PFC_OUTPUT_FILE .*|PFC_OUTPUT_FILE acad/results/pfc-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}.txt|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}.txt
			        sed -i "s|QLEN_MON_FILE .*|QLEN_MON_FILE acad/results/qlen-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}.txt|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}.txt

			        sed -i "s|SOURCE_ROUTING .*|SOURCE_ROUTING 0|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}.txt
			        sed -i "s|REPS .*|REPS 0|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}.txt
			        sed -i "s|REPSv4 .*|REPSv4 0|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}.txt
			        sed -i "s|END_HOST_SPRAY .*|END_HOST_SPRAY 0|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}.txt

			        sed -i "s|${ROUTING} .*|${ROUTING} 1|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}.txt

			        if [[ $ALLREDUCE_ALG == "ring" ]];then
			        	sed -i "s|STPRIO .*|STPRIO 1|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}.txt
			        else
			        	sed -i "s|STPRIO .*|STPRIO 0|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}.txt
			        fi
			        for WINDOW in ${WINDOWS[@]};do
			        	cp $BASE_CONFIG_DIR/config.txt config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}-${WINDOW}.txt
				        sed -i "s|TOPOLOGY_FILE .*|TOPOLOGY_FILE acad/network-topologies/ring-${N_TORS}-${NUM_NODES}-${PDELAY}-${BW}.txt|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}-${WINDOW}.txt
				        sed -i "s|TRACE_OUTPUT_FILE .*|TRACE_OUTPUT_FILE acad/results/mix-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${WINDOW}.tr|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}-${WINDOW}.txt
				        sed -i "s|FCT_OUTPUT_FILE .*|FCT_OUTPUT_FILE acad/results/fct-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}-${WINDOW}.txt|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}-${WINDOW}.txt
				        sed -i "s|PFC_OUTPUT_FILE .*|PFC_OUTPUT_FILE acad/results/pfc-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}-${WINDOW}.txt|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}-${WINDOW}.txt
				        sed -i "s|QLEN_MON_FILE .*|QLEN_MON_FILE acad/results/qlen-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}-${WINDOW}.txt|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}-${WINDOW}.txt

				        sed -i "s|SOURCE_ROUTING .*|SOURCE_ROUTING 0|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}-${WINDOW}.txt
				        sed -i "s|REPS .*|REPS 0|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}-${WINDOW}.txt
				        sed -i "s|REPSv4 .*|REPSv4 0|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}-${WINDOW}.txt
				        sed -i "s|END_HOST_SPRAY .*|END_HOST_SPRAY 0|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}-${WINDOW}.txt

				        sed -i "s|${ROUTING} .*|${ROUTING} 1|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}-${WINDOW}.txt

				        if [[ $ALLREDUCE_ALG == "ring" ]];then
				        	sed -i "s|STPRIO .*|STPRIO 1|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}-${WINDOW}.txt
				        else
				        	sed -i "s|STPRIO .*|STPRIO 0|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}-${WINDOW}.txt
				        fi
				    done
                    done
					done
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
			    N_TORS=$((NUM_NODES / 1))
			    for ROUTING in ${ROUTING_ALGS[@]}; do
			        cp $BASE_CONFIG_DIR/config.txt config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt
			        sed -i "s|TOPOLOGY_FILE .*|TOPOLOGY_FILE acad/network-topologies/ring-${N_TORS}-${N_TORS}-${NUM_NODES}.txt|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt
			        sed -i "s|TRACE_OUTPUT_FILE .*|TRACE_OUTPUT_FILE acad/results/mix-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.tr|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt
			        sed -i "s|FCT_OUTPUT_FILE .*|FCT_OUTPUT_FILE acad/results/fct-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt
			        sed -i "s|PFC_OUTPUT_FILE .*|PFC_OUTPUT_FILE acad/results/pfc-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt
			        sed -i "s|QLEN_MON_FILE .*|QLEN_MON_FILE acad/results/qlen-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt

			        sed -i "s|SOURCE_ROUTING .*|SOURCE_ROUTING 0|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt
			        sed -i "s|REPS .*|REPS 0|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt
			        sed -i "s|REPSv4 .*|REPSv4 0|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt
			        sed -i "s|END_HOST_SPRAY .*|END_HOST_SPRAY 0|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt

			        sed -i "s|${ROUTING} .*|${ROUTING} 1|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt

			        if [[ $ALLREDUCE_ALG == "ring" ]];then
			        	sed -i "s|STPRIO .*|STPRIO 1|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt
			        else
			        	sed -i "s|STPRIO .*|STPRIO 0|g" config-ring-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${TXT_WORKLOAD}.txt
			        fi
			    done
			done
		done
	done
done



cd $SCRIPT_DIR