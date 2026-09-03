#!/bin/bash

source config.sh

if [ ! -d "$RESULTS_DIR/harvest" ]; then
  mkdir "$RESULTS_DIR/harvest"
fi

NODES=(64)
MSG_NAMES=(16KB 64KB 256KB 1MB 4MB 16MB \
64MB 256MB 1GB 2GB 4GB)
ALPHA_DELAYS=(500 10000 500) #units in ns!!!
PDELAYS=(500 500 50)
RECONFIG_DELAYS=(10 100 1000 10000 100000 1000000 10000000) # in ns!!
BANDWIDTHS=(800) # Put unit for the bandwidth (Gbps)!!
ALGS=(halvingDoubling)

cd "${SCRIPT_DIR}"

ROUTING="ECMP"
APP_LOADBALANCE_ALG="none"
BVN_TOPO="bvn"
STATIC_TOPO="static"
HARVEST_TOPO="optical"
TYPE="OPTICAL"
WORKLOAD=""
PORTS=(1)
RELAXATION=0
P=1

for N in ${NODES[@]};do
    for ALG in ${ALGS[@]};do
        if [[ "$ALG" == "halvingDoubling" || "$ALG" == "swing" ]]; then
            WORKLOAD="AllReduce"
        elif [[ "$ALG" == direct* ]]; then
            WORKLOAD="AlltoAll"
        else
            echo "Unknown workload $ALG"
            exit 1
        fi
        if [[ ${ALG} == "swing" ]]; then
            P=2
        else
            P=1
        fi
        for BW in ${BANDWIDTHS[@]};do
            for ALPHA_DELTA_ID in ${!ALPHA_DELAYS[@]};do
                ALPHA=${ALPHA_DELAYS[$ALPHA_DELTA_ID]}
                DELTA=${PDELAYS[$ALPHA_DELTA_ID]}

                OUT_FILE="$N-$ALG-$BW-$ALPHA-$DELTA.csv"
                echo "SYSTEM,MSG_NAME,RECONFIG_DELAY,RECONFIG_COUNT,TOTAL_RECONF_COST,COMPLETION_TIME" > ${RESULTS_DIR}/harvest/${OUT_FILE}
                for ALPHA_R in ${RECONFIG_DELAYS[@]};do

                    for IDX in ${!MSG_NAMES[@]};do
                        MSG_NAME=${MSG_NAMES[$IDX]}

                        TOPO_FILE=$OPTICAL_ROUTING_DIR/harvest-$ALG-$N-$P-$MSG_NAME-$BW-$ALPHA-$DELTA-$ALPHA_R-$RELAXATION.json
                        FCT_FILE=${RESULTS_DIR}/fct/fct-${HARVEST_TOPO}-${N}-${TYPE}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${DELTA}-${BW}-${ALPHA_R}.txt

                        SIM_TIME=$(cat $FCT_FILE | tail -n1 | awk '{print $9}')
                        RECONF_COUNT=$(grep -oP '"num_of_reconfigs"\s*:\s*\K[0-9]+' "$TOPO_FILE")

                        TOTAL_RECONF_COST=$(awk "BEGIN {print $RECONF_COUNT * $ALPHA_R}")
                        COMPLETION_TIME=$(awk "BEGIN {print $SIM_TIME+$TOTAL_RECONF_COST}")

                        echo "harvest,${MSG_NAME},$ALPHA_R,$RECONF_COUNT,$TOTAL_RECONF_COST,$COMPLETION_TIME" >> ${RESULTS_DIR}/harvest/${OUT_FILE}
                    
                        # Give bvns

                        OUT_FILE="$N-$ALG-$BW-$ALPHA-$DELTA.csv"
                        TOPO_FILE=$OPTICAL_ROUTING_DIR/bvn-$ALG-$N-$P-0.json
                        FCT_FILE=${RESULTS_DIR}/fct/fct-${BVN_TOPO}-${N}-${TYPE}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${DELTA}-${BW}-0.txt

                        SIM_TIME=$(cat $FCT_FILE | tail -n1 | awk '{print $9}')
                        RECONF_COUNT=$(grep -oP '"num_of_reconfigs"\s*:\s*\K[0-9]+' "$TOPO_FILE")

                        TOTAL_RECONF_COST=$(awk "BEGIN {print $RECONF_COUNT * $ALPHA_R}")
                        COMPLETION_TIME=$(awk "BEGIN {print $SIM_TIME+$TOTAL_RECONF_COST}")

                        echo "bvn,${MSG_NAME},$ALPHA_R,$RECONF_COUNT,$TOTAL_RECONF_COST,$COMPLETION_TIME" >> ${RESULTS_DIR}/harvest/${OUT_FILE}
                        #static
                        OUT_FILE="$N-$ALG-$BW-$ALPHA-$DELTA.csv"
                        TOPO_FILE=$OPTICAL_ROUTING_DIR/static-$ALG-$N-$P.json
                        FCT_FILE=${RESULTS_DIR}/fct/fct-${STATIC_TOPO}-${N}-${TYPE}-${APP_LOADBALANCE_ALG}-${ALG}-${MSG_NAME}-${ALPHA}-${DELTA}-${BW}.txt

                        SIM_TIME=$(cat $FCT_FILE | tail -n1 | awk '{print $9}')
                        RECONF_COUNT=$(grep -oP '"num_of_reconfigs"\s*:\s*\K[0-9]+' "$TOPO_FILE")

                        TOTAL_RECONF_COST=$(awk "BEGIN {print $RECONF_COUNT * $ALPHA_R}")
                        COMPLETION_TIME=$(awk "BEGIN {print $SIM_TIME+$TOTAL_RECONF_COST}")

                        echo "static,${MSG_NAME},$ALPHA_R,$RECONF_COUNT,$TOTAL_RECONF_COST,$COMPLETION_TIME" >> ${RESULTS_DIR}/harvest/${OUT_FILE}                    
                    done

                done
			done
		done
	done
done


