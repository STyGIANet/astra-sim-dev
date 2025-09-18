# This file generates leaf-spine (2-tier), FatTree (3-tier) topologies.
# NVSwitches and multi-GPU servers are NOT considered here.
import argparse

def gen_leaf_spine(args):
    numTors = args.tor_num
    numSpines = args.spine_num
    numGpus = args.gpus
    numSwitches = numTors + numSpines
    numNodes = numGpus + numSwitches
    numLinks = numGpus + numTors * numSpines

    # Sorry :D
    assert(numGpus % numTors  == 0)

    file_name = "./../network-topologies/"+"leaf-spine-"+str(numTors)+"-"+str(numSpines)+"-"+str(numGpus)+".txt"

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
            f.write(str(i) + " " + str(numGpus + int(i / (numGpus/numTors))) + " " + str(args.nic_bandwidth) + " " + str(args.latency) + " " + str(args.error_rate))
            f.write('\n')
            f.write(str(i) + " " + str(numGpus + int(i / (numGpus/numTors))) + " " + str(args.nic_bandwidth) + " " + str(args.latency) + " " + str(args.error_rate))
            f.write('\n')

        # ToR <--> Spine links
        for i in range(numGpus, numGpus + numTors):
            for j in range(numGpus+numTors, numNodes):
                f.write(str(i) + " " + str(j) + " " + str(args.tier1_bandwidth) + " " + str(args.latency) + " " + str(args.error_rate))
                f.write('\n')
        
        # PCIe
        for i in range(numGpus):
            f.write(str(i) + " " + str((i+1)%numGpus) + " " + str(args.nic_bandwidth) + " " + str("0.000001ms") + " " + str(args.error_rate))
            f.write('\n')

def gen_fat_tree(args):
    k = args.k_ary
    oversub = args.oversubscription
    numPods = int(k)
    numGpus = int(oversub*k*k*k/4)
    numTors = int(k*k/2)
    numSpines = int(k*k/2)
    numCores = int(k*k/4)
    numLinks = int((k*k*k/4)*3 + (oversub - 1)*(k*k*k/4))
    nPerTor = int(oversub*k/2)
    numNodes = numGpus + numTors + numSpines + numCores
    numSwitches = numNodes - numGpus
    print("fatree", " k:",k, " numGpus:",numGpus, " numTors:",numTors, " numSpines:",numSpines, " numCores:",numCores, " numLinks:",numLinks, " numNodes:",numNodes, " numSwitches:",numSwitches)

    file_name = "./../network-topologies/"+"fat-tree-"+str(k)+".txt"

    with open(file_name, 'w') as f:
        print(file_name)
        first_line = str(numNodes) + " " + str(numSwitches) + " " + str(numLinks) + " " + str(int(k/2)) + " " + str(numCores) + " " + str(int(k/2)) + " " + str(numTors)
        f.write(first_line)
        f.write('\n')

        # write the switch nodes
        for i in range(numGpus, numNodes):
            f.write(str(i) + " ")
        f.write('\n')

        # write the links
        # each gpu is connected to a ToR switch
        for i in range(numGpus):
            f.write(str(i) + " " + str(numGpus + int(i / nPerTor)) + " " + str(args.nic_bandwidth) + " " + str(args.latency) + " " + str(args.error_rate))
            f.write('\n')

        # ToR <--> Spine/Agg links
        for i in range(numGpus, numGpus + numTors):
            pod = int((i - numGpus) / (k/2))
            for j in range(numGpus+numTors + int((k/2)*pod), numGpus+numTors + int((k/2)*(pod+1))):
                f.write(str(i) + " " + str(j) + " " + str(args.tier1_bandwidth) + " " + str(args.latency) + " " + str(args.error_rate))
                f.write('\n')

        for i in range(numGpus + numTors, numGpus + numTors + numSpines):
            indexInPod = (i - numGpus - numTors) % (k/2)
            for j in range(int(k/2)):
                f.write(str(i) + " " + str(numGpus + numTors + numSpines + int(indexInPod*int(k/2) + j)) + " " + str(args.tier2_bandwidth) + " " + str(args.latency) + " " + str(args.error_rate))
                f.write('\n')

def main():
    parser = argparse.ArgumentParser(description='Python script to generate CLOS topologies')
    parser.add_argument('-l','--latency',type=str,default='0.0005ms',help='link propagation delay,default 0.0005ms')
    parser.add_argument('-nicbw','--nic_bandwidth',type=str,default='100Gbps',help='nic to tor bandwidth,default 100Gbps')
    parser.add_argument('-t1bw','--tier1_bandwidth',type=str,default='100Gbps',help='tor to agg/spine bandwidth,default 100Gbps')
    parser.add_argument('-t2bw','--tier2_bandwidth',type=str,default='100Gbps',help='agg/spine to core,default 100Gbps')
    parser.add_argument('-er','--error_rate',type=str,default='0',help='error_rate,default 0')
    parser.add_argument('-g','--gpus',type=int,default=1024,help='number of gpus,default 1024')
    parser.add_argument('-tors','--tor_num',type=int,default=64,help='number of tor switches,default 64')
    parser.add_argument('-spines','--spine_num',type=int,default=64,help='number of spine switches,default 64')
    parser.add_argument('-topo','--topology',type=str,default='leafspine',help='topology type,default leaf-spine,other options: fattree')
    parser.add_argument('-k','--k_ary',type=int,default=4,help='k-ary fat-tree or leaf-spine,default 4')
    parser.add_argument('-os','--oversubscription',type=int,default=1,help='oversubscription,default 1')
    args = parser.parse_args()
    if (str(args.topology) == 'leafspine'):
        gen_leaf_spine(args)
    elif (str(args.topology) == 'fattree'):
        gen_fat_tree(args)
    else:
        print("Unsupported topology type")

if __name__ =='__main__':
    main()
    







