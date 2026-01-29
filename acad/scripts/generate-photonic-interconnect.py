# This file generates leaf-spine (2-tier), FatTree (3-tier) topologies.
# NVSwitches and multi-GPU servers are NOT considered here.
import argparse

def gen_optical_topology(args):
    numTors = args.tor_num
    numSpines = args.spine_num
    numGpus = args.gpus
    numSwitches = numTors + numSpines
    numNodes = numGpus + numSwitches
    numLinks = numGpus + numTors * numSpines
    # latency_val = int(args.latency) / 10**6
    latency_ms = f"{float(args.latency) / 1_000_000:.10f}".rstrip('0').rstrip('.') + "ms"
    bw_gbps = f"{args.nic_bandwidth}Gbps"

    # Sorry :D
    assert(numGpus % numTors  == 0)

    file_name = "./../network-topologies/"+"optical-"+str(numTors)+"-"+str(numGpus)+"-"+str(args.latency)+"-"+str(args.nic_bandwidth)+".txt"

    with open(file_name, 'w') as f:
        print(file_name)
        first_line = str(numNodes) + " " + str(numSwitches) + " " + str(numLinks*2+numGpus) + " " + str(2*numSpines) + " " + str(0) + " " + str(numTors) + " " + str(numTors)
        f.write(first_line)
        f.write('\n')

        # write the switch nodes
        for i in range(numGpus, numNodes):
            f.write(str(i) + " ")
        f.write('\n')

        # write the links
        # each gpu is connected to a ToR switch
        for i in range(numGpus):
            f.write(str(i) + " " + str(numGpus) + " " + str(bw_gbps) + " " + latency_ms + " " + str(args.error_rate))
            f.write('\n')
            f.write(str(i) + " " + str(numGpus) + " " + str(bw_gbps) + " " + latency_ms + " " + str(args.error_rate))
            f.write('\n')
       
        # PCIe
        for i in range(numGpus):
            f.write(str(i) + " " + str(numGpus+1) + " " + str(bw_gbps) + " " + str("0.000001ms") + " " + str(args.error_rate))
            f.write('\n')


def main():
    parser = argparse.ArgumentParser(description='Python script to generate CLOS topologies')
    parser.add_argument('-l','--latency',type=str,default='500',help='link propagation delay,default 0.0005ms')
    parser.add_argument('-nicbw','--nic_bandwidth',type=str,default='100',help='nic to tor bandwidth,default 100Gbps')
    parser.add_argument('-er','--error_rate',type=str,default='0',help='error_rate,default 0')
    parser.add_argument('-g','--gpus',type=int,default=1024,help='number of gpus,default 1024')
    parser.add_argument('-tors','--tor_num',type=int,default=64,help='number of tor switches,default 64')
    parser.add_argument('-spines','--spine_num',type=int,default=64,help='number of spine switches,default 64')
    parser.add_argument('-topo','--topology',type=str,default='leafspine',help='topology type,default leaf-spine,other options: fattree')
    parser.add_argument('-k','--k_ary',type=int,default=4,help='k-ary fat-tree or leaf-spine,default 4')
    parser.add_argument('-os','--oversubscription',type=int,default=1,help='oversubscription,default 1')
    args = parser.parse_args()
    if (str(args.topology) == 'ring'):
        gen_optical_topology(args)
    else:
        print("Unsupported topology type")

if __name__ =='__main__':
    main()
    







