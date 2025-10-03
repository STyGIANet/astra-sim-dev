#!/bin/bash

# find the absolute path to this script
source config.sh

NODES=(64)
MSG_SIZES=(64 1000 160000 256000 4000000 64000000 1000000000)
PROPAGATION_DELAY=("0.0005ms") # Put unit for the delays (ms)!!
RECONFIG_DELAY=("0ns") # Put unit for the reconfigs (ns)!!
BANDWIDTH=("800Gbps") # Put unit for the bandwidth (Gbps)!!

# NODES=(8 16 32 64)
# MSG_SIZES=(160000 32000000 64000000)
# PROPAGATION_DELAY=("0.0005ms") # Put unit for the delays (ms)!!
# RECONFIG_DELAY=("0ns") # Put unit for the reconfigs (ns)!!
# BANDWIDTH=("800Gbps") # Put unit for the bandwidth (Gbps)!!
ALLREDUCE_ALGS=("halvingDoubling")
ALGS=("optical")
# Recompile ns3
FILE="oroborus-msgsize-results.txt" # change this
cd ${SCRIPT_DIR}
# ./build.sh -l
# ./build.sh -c
##############################################################################
# Allreduce across various message sizes and load balancing algorithms for oroborus
# echo "NUM_NODES,PDELAY,BW,RDELAY,ALG,ALLREDUCE_ALG,MSG_SIZE,RECONFIG_COST,CCT/Time(ms)" > ${RESULTS_DIR}/${FILE}
N=0
for NUM_NODES in ${NODES[@]}; do
    for MSG_SIZE in ${MSG_SIZES[@]};do
    
        for ALG in ${ALGS[@]};do
            TOPO="ring"
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
         ################ Optical ######################
            elif [[ $ALG == "optical" ]]; then
                ROUTING="OPTICAL"
                APP_LOADBALANCE_ALG="none"
                TOPO="optical-ring"
                for ALLREDUCE_ALG in ${ALLREDUCE_ALGS[@]};do
                for PDELAY in ${PROPAGATION_DELAY[@]};do
                for BW in ${BANDWIDTH[@]};do
                for RECONF in ${RECONFIG_DELAY[@]};do

                    RECONF_FILE=${OPTICAL_ROUTING_DIR}/${ALG}-ring-${NUM_NODES}-${MSG_SIZE}-${PDELAY}-${BW}-${RECONF}.txt

                    FCT_FILE=${RESULTS_DIR}/fct-${TOPO}-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${PDELAY}-${BW}-${RECONF}.txt

                    CCT=$(cat $FCT_FILE | tail -n1 | awk '{print $9}')
                    RECONF_COST=$(sed -n '2p' "$RECONF_FILE" | awk '{print int(2*$4)}')
                    # if [[ "$RECONF" -eq 0 ]]; then
                    #     RECONF_COST=$(echo "l($NUM_NODES)/l(2) * 2" | bc -l)
                    # fi


                echo "$NUM_NODES,$RECONF,$ALG-$ALLREDUCE_ALG,$MSG_SIZE,$RECONF_COST,$CCT" >> ${RESULTS_DIR}/${FILE}
                done
                done
                done
                done
                
            fi

        ###############################################
            if [[ $ALG != "optical" ]]; then
            for ALLREDUCE_ALG in ${ALLREDUCE_ALGS[@]};do
            for PDELAY in ${PROPAGATION_DELAY[@]};do
            for BW in ${BANDWIDTH[@]};do
            for RECONF in ${RECONFIG_DELAY[@]};do

                FCT_FILE=${RESULTS_DIR}/fct-${TOPO}-${NUM_NODES}-${ROUTING}-${APP_LOADBALANCE_ALG}-${ALLREDUCE_ALG}-${MSG_SIZE}-${PDELAY}-${BW}.txt
                
                CCT=$(cat $FCT_FILE | tail -n1 | awk '{print $9}')

                echo "$NUM_NODES,$RECONF,$ALG-$ALLREDUCE_ALG,$MSG_SIZE,0,$CCT" >> ${RESULTS_DIR}/${FILE}
            done
            done
            done
            done
            fi
        done
    done
done
echo  "Results written to ${RESULTS_DIR}/${FILE}"