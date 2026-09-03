#!/bin/bash

source config.sh

HEATMAP_DIR=${RESULTS_DIR}/harvest/fig5

NODES=(64)
BANDWIDTHS=(800) 
ALPHA_DELAYS=(500)
PDELAYS=(500)
ALGS=(halvingDoubling swing direct1)

for NODE in ${NODES[@]}; do
    for ALG in ${ALGS[@]}; do
        for ALPHA_DELTA_ID in ${!ALPHA_DELAYS[@]}; do
            ALPHA=${ALPHA_DELAYS[$ALPHA_DELTA_ID]}
            PDELAY=${PDELAYS[$ALPHA_DELTA_ID]}
            
            # Logic: If algorithm is direct1, skip unless ALPHA and PDELAY are both 500
            if [[ "$ALG" == "direct1" ]]; then
                if [[ "$ALPHA" -ne 500 || "$PDELAY" -ne 500 ]]; then
                    continue
                fi
            fi

            for BW in ${BANDWIDTHS[@]}; do
                FILE=${HEATMAP_DIR}/${NODE}-${ALG}-${BW}-${ALPHA}-${PDELAY}.csv
                
                if [[ -f "$FILE" ]]; then
                    python ${SCRIPT_DIR}/generate-fig5-heatmap.py "$FILE"
                else
                    echo "Warning: $FILE not found, skipping."
                fi
            done
        done
    done
done