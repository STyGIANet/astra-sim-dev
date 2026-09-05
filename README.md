# stygianet-astra-sim

This repository is a fork from the original [astra-sim](https://astra-sim.github.io/). We've replaced the ns3 network backend [astra-network-ns3](https://github.com/astra-sim/astra-network-ns3/tree/astra-sim) with our version of ns3 [astra-ns3-datacenter](https://github.com/STyGIANet/astra-ns3-datacenter) which is in turn an extension from the original backend and our prior work [ns3-datacenter](https://github.com/inet-tub/ns3-datacenter). The ns-3 backend now support optical circuit switched networks.
### Note before we start:
All topologies were generated using the scripts from `synthesis` folder and stored in:
```bash
Harvest/astra-sim/acad/reconfigurable-topologies
```

This allows the experiments to avoid the additional time required to synthesize the topologies.

If you are interested in synthesizing new topologies, refer to the `synthesis` folder. We recommend generating topologies in the `Harvest/synthesis` folder and moving them into the `reconfigurable-topologies` folder as needed, following the naming convention used in the `reconfigurable-topologies` folder

## Building Harvest

### Update dependencies
Please make the following edit to `extern/graph_frontend/chakra/.pyproject.toml`: 

Remove `"protobuf==5.*"`, and replace with `"protobuf",`
```bash
dependencies = [
    "protobuf",
    "graphviz",
    "networkx",
    "pydot",
    "HolisticTraceAnalysis @ git+https://github.com/facebookresearch/HolisticTraceAnalysis.git@d731cc2e2249976c97129d409a83bd53d93051f6"
]
```
### Install Chakra

```bash
./utils/install_chakra.sh
```

### Build ns-3 backend
```bash
cd /app/astra-sim
./acad/scripts/build-optical-interconnect.sh
```

All set!

## Running Harvest Experiments

Experiment scripts are located in:

```bash
cd acad/scripts
```

### Reproducing Figure 5

First, we generate the configuration files needed to run the simulator for Figure 5:

```bash
./generate-optical-configs.sh
```

Next, we run the simulations. The command follows this structure:

```bash
./run-fig5-optical-workloads.sh EXP N_CORES
```

`EXP` should always be set to `1`. `N_CORES` specifies the number of parallel experiments (threads) your system can run. On Ubuntu, you can check the available CPU cores and threads using:

```bash
lscpu
```

For example, on a system with 18 available threads:

```bash
./run-fig5-optical-workloads.sh 1 18
```

With 18 parallel experiments, it may take approximately 5–9 hours for the experiments to finish. A folder called `results` will be created inside `astra-sim/acad' containing the simulation results.

Once the simulations are complete, run the following script to generate a CSV file containing the results:

```bash
./results-fig5.sh
```

This will create a folder called `astra-sim/acad/results/harvest/fig5` and the csv files containing the results.

Now, we can generate the final heatmaps using:
```bash
./run-fig5-heatmaps.sh
```
The folder `astra-sim/acad/results/harvest/fig5` will contain the heatmaps that were used in Figure 5.
| Paper figure | Generated file |
| --- | --- |
| Figure 5(a) | `results/harvest/fig5/64-halvingDoubling-800-500-500-static-harvest12,8.png` |
| Figure 5(b) | `results/harvest/fig5/64-swing-800-500-500-static-harvest12,8.png` |
| Figure 5(c) | `results/harvest/fig5/64-direct1-800-500-500-static-harvest12,8.png` |
| Figure 5(d) | `results/harvest/fig5/64-direct1-800-500-500-best-harvest12,8.png` |
| Figure 5(e) | `results/harvest/fig5/64-halvingDoubling-800-500-500-bvn-harvest12,8.png` |
| Figure 5(f) | `results/harvest/fig5/64-swing-800-500-500-bvn-harvest12,8.png` |
| Figure 5(g) | `results/harvest/fig5/64-direct1-800-500-500-bvn-harvest12,8.png` |
| Figure 5(h) | `results/harvest/fig5/64-halvingDoubling-800-500-500-best-harvest12,8.png` |

---
### Reproducing Figure 9(b)

First, we generate the configuration files needed to run the simulator for Figure 9(b):

```bash
./generate-optical-configs.sh
./generate-optical-ring-configs.sh
```

Next, we run the simulations. There are two separate scripts to generate Fig 9(b). rd is for the recursive doubling experiments and ring is for the ring experiments:

```bash
./run-fig9-rd-optical-workloads.sh EXP N_CORES
./run-fig9-ring-optical-workloads.sh EXP N_CORES
```
For example, on a system with 18 available threads, we would first run:

```bash
./run-fig9-rd-optical-workloads.sh 1 18
```
Wait for it to complete and then run:
```bash
./run-fig9-ring-optical-workloads.sh 1 18
```
A folder called `results` will be created inside `astra-sim/acad' containing the simulation results.

Once the simulations are complete, run the following scripts to generate CSV files containing the results:

```bash
./results-fig9-rd.sh
./results-fig9-ring.sh
```

This will create a folder called `astra-sim/acad/results/harvest/fig9` and the csv files containing the results.

Now, we can generate the final heatmaps using:
```bash
python generate-fig9-heatmap.py
```
The folder `astra-sim/acad/results/harvest/fig9` will contain the heatmaps that were used in Figure 9(b).

When alpha= 500 ns and prop delay = 50 ns
| Paper figure | Generated file |
| --- | --- |
| Figure 9(b) | `results/harvest/fig9/64-nodes-500-50-best-harvest.png` |
| Figure 13(a) | `results/harvest/fig9/64-nodes-500-50-ring-harvest.png` |
| Figure 13(b) | `results/harvest/fig9/64-nodes-500-50-harvest-ring.png` |
| Figure 13(c) | `results/harvest/fig9/64-nodes-500-50-best-harvest.png` |

When alpha= 500 ns and prop delay = 500 ns
| Paper figure | Generated file |
| --- | --- |
| Figure 16(a) | `results/harvest/fig9/64-nodes-500-500-ring-harvest.png` |
| Figure 16(b) | `results/harvest/fig9/64-nodes-500-500-harvest-ring.png` |
| Figure 16(c) | `results/harvest/fig9/64-nodes-500-500-best-harvest.png` |

When alpha= 10000 ns and prop delay = 500 ns
| Paper figure | Generated file |
| --- | --- |
| Figure 17(a) | `results/harvest/fig9/64-nodes-10000-500-ring-harvest.png` |
| Figure 17(b) | `results/harvest/fig9/64-nodes-10000-500-harvest-ring.png` |
| Figure 17(c) | `results/harvest/fig9/64-nodes-10000-500-best-harvest.png` |

Done!
---