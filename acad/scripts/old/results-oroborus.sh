#!/bin/bash

# find the absolute path to this script
# Assuming config.sh defines SCRIPT_DIR, RESULTS_DIR, OPTICAL_ROUTING_DIR etc.
source config.sh

TOPO_DIR=$SCRIPT_DIR/../64-reconfigs

# ===== Configuration Variables (You can change these) =====
NODES=(64) 
MSG_SIZES=(128 1000 16000 256000 4000000 64000000 256000000 512000000 1000000000)
PROPAGATION_DELAY=("0.0005ms") # Put unit for the delays (ms)!!
RECONFIG_DELAY=("0ns" "10ns" "100ns" "1000ns" "10000ns" "100000ns" "1000000ns") # Put unit for the reconfigs (ns)!!
BANDWIDTH=("800Gbps") # Put unit for the bandwidth (Gbps)!!
ALPHA_DELAY=(1000) #units in ns!!!
ALLREDUCE_ALGS=("swing")
ALGS=("optical")
# Recompile ns3 (Assuming this is an external step)
# make clean && make
FILE="oroborus-results.txt" # change this
cd "${SCRIPT_DIR}" # Use quotes for safety
# echo "NUM_NODES,ALPHA,PDELAY,BW,RDELAY,TYPE-ALLREDUCE_ALG,MSG_SIZE,RECONFIG_COST,CCT/Time(ns)" > "${RESULTS_DIR}/oroborus/${FILE}" # Use quotes for safety
##############################################################################
# Allreduce across various message sizes and load balancing algorithms for oroborus
for ALG in "${ALGS[@]}"; do
    ROUTING="ECMP"
    APP_LOADBALANCE_ALG="none"
    BVN_TOPO="bvn-topo"
    STATIC_TOPO="static-topo"
    HARVEST_TOPO="optical-ring"
    TYPE="OPTICAL"


    # if [[ "$ALG" == "none" ]]; then
    #     ROUTING="ECMP"
    #     APP_LOADBALANCE_ALG="none"
    #     TOPO="ring"
    #     TYPE="static"
    # elif [[ "$ALG" == "optical" ]]; then
    #     ROUTING="OPTICAL"
    #     APP_LOADBALANCE_ALG="none"
    #     TOPO="optical-ring"
    #     TYPE="oroborus" # Added missing initial setting for TYPE
    # fi
    # # Check if TYPE was set, if not, something is wrong
    # if [[ -z "$TYPE" ]]; then
    #     echo "Error: TYPE not set for ALG: $ALG. Skipping..."
    #     continue
    # fi
    for ALLREDUCE_ALG in "${ALLREDUCE_ALGS[@]}"; do
        # if [[ "$ALLREDUCE_ALG" == "swing" && "$ALG" == "optical" ]]; then
        #     continue 
        # fi
    # FILE="oroborus-${TYPE}-${ALLREDUCE_ALG}-results.txt" # change this
    # echo "NUM_NODES,ALPHA,PDELAY,BW,RDELAY,TYPE-ALLREDUCE_ALG,MSG_SIZE,RECONFIG_COST,CCT/Time(ns)" > "${RESULTS_DIR}/oroborus/${FILE}" # Use quotes for safety
    for NUM_NODES in "${NODES[@]}"; do
    # echo "hello"
        for MSG_SIZE in "${MSG_SIZES[@]}"; do
    
                    # echo "hello"
                
                # echo "hello"
                for PDELAY in "${PROPAGATION_DELAY[@]}"; do
                for BW in "${BANDWIDTH[@]}"; do
                for ALPHA in "${ALPHA_DELAY[@]}"; do
                for RECONF in "${RECONFIG_DELAY[@]}"; do
                    RECONF_FILE="${OPTICAL_ROUTING_DIR}/${TOPO}-${NUM_NODES}-${MSG_SIZE}-${PDELAY}-${BW}-${RECONF}-${ALLREDUCE_ALG}.txt"
                    FCT_FILE=""
                    if [[ "$TYPE" == "static" ]]; then
                        FCT_FILE="${RESULTS_DIR}/fct-${TOPO}-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}.txt"
                    else
                        FCT_FILE="${RESULTS_DIR}/fct-${TOPO}-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}-${RECONF}.txt"
                    fi
                    # Initialize CCT and RECONF_COST to handle missing files gracefully
                    CCT=""
                    RECONF_COST="N/A" # Default to N/A for cases where it's not applicable or calculable

                    # Get CCT (Completion Time)
                    if [[ -f "$FCT_FILE" ]]; then
                        CCT=$(tail -n1 "$FCT_FILE" | awk '{print $9}')
                    else
                        echo "Warning: FCT File not found: ${FCT_FILE}. Skipping result line."
                        continue # Skip this combination if FCT is missing
                    fi
                    # echo "hello"
                    # Calculate RECONF_COST
                    if [[ "$TYPE" == "static" ]]; then
                        RECONF_COST="0" # Static configuration has 0 reconfig cost
                    elif [[ -f "$RECONF_FILE" ]]; then
                        RECONF_COST=$(sed -n '2p' "$RECONF_FILE" | awk '{printf "%d", 2*$4}') 
                    else
                        echo "Warning: File not found for dynamic type: ${RECONF_FILE}. Skipping result line."
                        continue # Skip this combination if the config file is missing
                    fi                  
                    # echo "Hello"
                    # Append results to the output file
                    echo "$NUM_NODES,${ALPHA}ns,$PDELAY,$BW,$RECONF,$TYPE-$ALLREDUCE_ALG,$MSG_SIZE,$RECONF_COST,$CCT" >> "${RESULTS_DIR}/oroborus/${FILE}"
                done
                done
                done
                done
            done
        done
    done
done

get_log2_int() {
    local N=$1
    local L=0
    # Loop while N is greater than 1, counting how many times it can be divided by 2
    while (( N > 1 )); do
        (( N /= 2 )) # N = N / 2 (integer division)
        (( L++ ))    # Increment logarithm counter
    done
    echo $L
}

# BVN RESULTS
for ALG in ${ALGS[@]}; do
    ROUTING=""
    APP_LOADBALANCE_ALG=""
    TOPO=""
    TYPE=""

    if [[ "$ALG" == "none" ]]; then
        continue;
    elif [[ "$ALG" == "optical" ]]; then
        ROUTING="OPTICAL"
        APP_LOADBALANCE_ALG="none"
        TOPO="optical-ring"
        TYPE="bvn"
        # TYPE will be set based on RECONF later
    fi

    for ALLREDUCE_ALG in ${ALLREDUCE_ALGS[@]};do
        # if [[ "$ALLREDUCE_ALG" == "swing" && "$ALG" == "optical" ]]; then
        #     continue # Skip 'swing' when using 'optical'
        # fi
    # FILE="oroborus-${TYPE}-${ALLREDUCE_ALG}-results.txt" # change this
    # echo "NUM_NODES,ALPHA,PDELAY,BW,RDELAY,TYPE-ALLREDUCE_ALG,MSG_SIZE,RECONFIG_COST,CCT/Time(ns)" > "${RESULTS_DIR}/oroborus/${FILE}" # Use quotes for safety
    for NUM_NODES in ${NODES[@]}; do
        for MSG_SIZE in ${MSG_SIZES[@]};do
    
                
                for PDELAY in ${PROPAGATION_DELAY[@]};do
                for BW in ${BANDWIDTH[@]};do
                for ALPHA in "${ALPHA_DELAY[@]}"; do
                for RECONF in ${RECONFIG_DELAY[@]};do
                    # BVN_FILE=${OPTICAL_ROUTING_DIR}/${TOPO}-${NUM_NODES}-${MSG_SIZE}-${PDELAY}-${BW}-0ns.txt
                    FCT_FILE=${RESULTS_DIR}/fct-${TOPO}-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${ALPHA}ns-${PDELAY}-${BW}-0ns.txt
                    
                    CCT=$(cat $FCT_FILE | tail -n1 | awk '{print $9}')

                    LOG2_NODES=$(get_log2_int $NUM_NODES)
                    RECONF_NUMERIC=${RECONF%ns} 

                    # Calculate the final RECONF_COST using pure integer arithmetic
                    if [[ "$ALLREDUCE_ALG" == "direct1" && "$ALG" == "optical" ]]; then
                        RECONF_COST=$(( (NUM_NODES - 2) * RECONF_NUMERIC))
                    else
                        RECONF_COST=$(( LOG2_NODES * RECONF_NUMERIC * 2))
                    fi
                                        
                    
                    echo "$NUM_NODES,${ALPHA}ns,$PDELAY,$BW,$RECONF,$TYPE-$ALLREDUCE_ALG,$MSG_SIZE,$RECONF_COST,$CCT" >> ${RESULTS_DIR}/oroborus/${FILE}
                done
                done
                done
                done
            done
        done
    done
done