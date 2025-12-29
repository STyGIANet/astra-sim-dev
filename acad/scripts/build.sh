#!/bin/bash
set -e

# Increase the number of file descriptors
ulimit -n 65535
export CXXFLAGS=-w

# Absolue path to this script
SCRIPT_DIR=$(dirname "$(realpath $0)")
# Absolute paths to useful directories
ASTRA_SIM_DIR="${SCRIPT_DIR:?}"/../../astra-sim
NS3_DIR="${SCRIPT_DIR:?}"/../../extern/network_backend/ns-3
# Inputs - change as necessary.
WORKLOAD=$(realpath "${SCRIPT_DIR:?}"/..)/et-workloads/AllGather-8-1000000-ring # use chakra
SYSTEM=$(realpath "${SCRIPT_DIR:?}"/../system-configs/system-halvingDoubling-none.json)
MEMORY=$(realpath "${SCRIPT_DIR:?}"/../base-configs/remote_memory.json)
LOGICAL_TOPOLOGY=$(realpath "${SCRIPT_DIR:?}"/../logical-topo-configs/logical-topo-8.json)
# Note that ONLY this file is relative to NS3_DIR/simulation
NETWORK=$(realpath "${SCRIPT_DIR:?}"/../network-configs/config-ring-8-ECMP-none-halvingDoubling-1000000.txt)
# Functions
function setup {
    protoc et_def.proto\
        --proto_path ${SCRIPT_DIR}/../../extern/graph_frontend/chakra/schema/protobuf/\
        --cpp_out ${SCRIPT_DIR}/../../extern/graph_frontend/chakra/schema/protobuf/
}
function compile {
    cd "${NS3_DIR}"
    ./ns3 configure --enable-mpi --build-profile=optimized
    ./ns3 build AstraSimNetwork -j $(nproc)
    cd "${SCRIPT_DIR:?}"
}
function run {
    "${NS3_DIR}"/build/scratch/ns3.42-AstraSimNetwork-optimized \
        --workload-configuration=${WORKLOAD} \
        --system-configuration=${SYSTEM} \
        --network-configuration=${NETWORK} \
        --remote-memory-configuration=${MEMORY} \
        --logical-topology-configuration=${LOGICAL_TOPOLOGY} \
        --comm-group-configuration=\"empty\"
    cd "${SCRIPT_DIR:?}"
}
function cleanup {
    cd "${NS3_DIR}"
    ./ns3 distclean
    cd "${SCRIPT_DIR:?}"
}
function cleanup_result {
    echo '0'
}
function debug {
    cd "${NS3_DIR}"
    ./ns3 configure --enable-mpi --build-profile debug
    ./ns3 build AstraSimNetwork -j 12 -v
    cd ${ASTRA_SIM_DIR}/..
    gdb --args "${NS3_DIR}/build/scratch/ns3.42-AstraSimNetwork-debug" \
        --workload-configuration=${WORKLOAD} \
        --system-configuration=${SYSTEM} \
        --network-configuration=${NETWORK} \
        --remote-memory-configuration=${MEMORY} \
        --logical-topology-configuration=${LOGICAL_TOPOLOGY} \
        --comm-group-configuration=\"empty\"
}
function special_debug {
    cd "${NS3_DIR}/build/scratch"
    valgrind --leak-check=yes "${NS3_DIR}/build/scratch/ns3.42-AstraSimNetwork-default" \
        --workload-configuration=${WORKLOAD} \
        --system-configuration=${SYSTEM} \
        --network-configuration=${NETWORK} \
        --remote-memory-configuration=${MEMORY} \
        --logical-topology-configuration=${LOGICAL_TOPOLOGY} \
        --comm-group-configuration=\"empty\"
}
# Main Script
case "$1" in
-l|--clean)
    cleanup;;
-lr|--clean-result)
    cleanup
    cleanup_result;;
-d|--debug)
    setup
    debug;;
-c|--compile|"")
    setup
    compile;;
-r|--run)
    run;;
-cr|--compilerun)
    setup
    compile
    cd ${SCRIPT_DIR}/../../
    run;;
-h|--help|*)
    printf "Prints help message";;
esac
