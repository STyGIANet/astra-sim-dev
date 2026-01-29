#!/bin/bash

source config.sh

COLL_DIR=$SCRIPT_DIR/../collectives
TOPO_DIR=$SCRIPT_DIR/../64-reconfigs

#########################
# Same parameters as generation
NODES=(64)
MSG_SIZES=(128 1024 16384 262144 \
 4194304 67108864 268435456 536870912 1073741824)

MSG_NAMES=(128B 1KB 16KB 256KB 4MB \
64MB 256MB 512MB 1GB)

RECONFIG_DELAY=("0ns" "10ns" "100ns" "1000ns" "10000ns" "100000ns" "1000000ns")
ALPHARS=(0 10 100 1000 10000 100000 1000000)
BANDWIDTH_VALS=(800)

ALPHA_DELAY=(1000 10 10000 10000)
PROPAGATION_DELAY=("0.001ms" "0.01ms" "0.00001ms" "0.01ms")
PROP_DELAY_NAMES=(1000 10000 10 10000)

ALGS=("direct1")
ALGS_TOPO=(all-to-all)

PORTS=(1)
RELAXATION=0

#########################

TOTAL=0
FOUND=0
MISSING=0

echo "🔍 Checking generated topology files..."
echo

for N in ${NODES[@]}; do
  for BW in ${BANDWIDTH_VALS[@]}; do
    for ALPHA_DELTA_ID in ${!ALPHA_DELAY[@]}; do
      ALPHA=${ALPHA_DELAY[$ALPHA_DELTA_ID]}
      DELTA=${PROPAGATION_DELAY[$ALPHA_DELTA_ID]}
      DELTA_NAME=${PROP_DELAY_NAMES[$ALPHA_DELTA_ID]}
      for ALPHA_R in ${ALPHARS[@]}; do
        for P in ${PORTS[@]}; do
          for ALG_ID in ${!ALGS[@]}; do
            ALG_IN_ASTRA=${ALGS[$ALG_ID]}
            ALG_IN_HARVEST=${ALGS_TOPO[$ALG_ID]}
            for IDX in ${!MSG_SIZES[@]}; do
              MESSAGE_NAME=${MSG_NAMES[$IDX]}
              OUTFILE=$TOPO_DIR/topology-$ALG_IN_ASTRA-$N-$P-$MESSAGE_NAME-$BW-$ALPHA-$DELTA-$ALPHA_R-$RELAXATION.json

              TOTAL=$((TOTAL + 1))

              if [[ -f "$OUTFILE" ]]; then
                FOUND=$((FOUND + 1))
                # Uncomment if you want verbose success output
                # echo "✅ FOUND   $OUTFILE"
              else
                MISSING=$((MISSING + 1))
                echo "❌ MISSING $OUTFILE"
              fi
            done
          done
        done
      done
    done
  done
done

echo
echo "================ Summary ================"
echo "Expected files : $TOTAL"
echo "Found          : $FOUND"
echo "Missing        : $MISSING"
echo "========================================"
