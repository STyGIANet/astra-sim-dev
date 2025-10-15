#!/usr/bin/env python3

from __future__ import annotations
import math
import numpy as np
import argparse
from typing import List, Tuple, Optional
import time

def propCost(a: int, b: int, delta: float) -> float:
    if b < a or delta == 0.0:
        return 0.0
    return delta * ((2 ** (b - a +1)) - 1)

def tranCost(a: int, b: int, m: float, beta: float) -> float:
    if b < a or beta == 0.0:
        return 0.0
    return beta*(m / (2 ** a)) * ((b - a) + 1)

def completionTime(a: int, b: int, m: float, beta: float, delta: float, n: float) -> float:
    if b<a or beta == 0.0:
        return 0.0

    if a==b:
        return delta*1 + beta * (m/n)
    else:
        propcost = 0
        trancost = 0
        for step in range(a, b+1):
            rho = step
            propcost += delta*rho
            trancost += beta*(m/n)*rho
        totalCost = propcost + trancost
        return totalCost


def computeSchedule(s: int, k: int, m: int = 1, beta: float = 1.0, delta: float = 1.0) -> Tuple[float, List[int]]:
    if s < 1:
        return 0.0, []
    k = max(0, min(k, s))
    INF = float("inf")
    DP = [[INF] * (k + 1) for _ in range(0, s + 2)] # s + 1 - 1 + 1 rows
    nxt = [[None] * (k + 1) for _ in range(0, s + 2)]
    graphList = [[None] * (k + 1) for _ in range(0, s + 2)]

    for a in range(1, s+1):
        # comm = beta*(m / (2 ** a)) * ((s - a) + 1)
        comm = completionTime(a, s, m, beta,delta,s+1)
        prop = 0
        # print(beta, m, a, s)
        # print(f"comm {comm}, prop {prop}")
        DP[a][0] = comm + prop
    
    for a in range(0, k + 1):
        DP[ s + 1 ][ a ] = 0.0

    for t in range(1, k + 1):
        for a in range(1, s+1):
            # coeff = beta*m / (2 ** (a))
            best = INF
            argb: Optional[int] = None
            for b in range(a, s+1):
            # for b in reversed(range(a,s+1)):
                comm = completionTime(a, b, m, beta,delta,s+1)
                prop = 0
                val = comm + prop + DP[b+1][t - 1]
                if val < best:
                    best, argb = val, b + 1
            DP[a][t] = best
            nxt[a][t] = argb

    reconflist: List[int] = []
    a, t = 1, k
    while t > 0:
        b = nxt[a][t]
        if b is None:
            break
        reconflist.append(b)
        a, t = b, t - 1

    reconflist = [r for r in reconflist if r <= s]
    # print("DP Table:")
    # print(DP)
    # print("nxt Table:")
    # print(nxt)
    return DP[1][k], reconflist

def main():
    parser = argparse.ArgumentParser(description="DP for recursive doubling reconfiguration schedule.")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("-n", type=int, help="Number of nodes.")
    parser.add_argument("-m", type=float, default=1.0, help="Message size in bytes.")
    parser.add_argument("--delta", type=str, default="0.0", help="Propagation delay in ns for step i: delta*2^(i-1).")
    parser.add_argument("--bw", type=str, default="1.0", help="beta = 1/(bw*Gbps)")
    parser.add_argument("--reconf", type=str, default="0.0", help="Reconfiguration delay in ns.")
    args = parser.parse_args()


    delta_str = args.delta.lower().replace("ms","")
    try:
        tempdelta = float(delta_str)
    except ValueError:
        print(f"Error: Invalid format for delta. Only ms supported. Expected a number or a string like '0.0005ms' or '0.0005', but got '{args.bw}'.")
        return

    delta = tempdelta*1e-3
    bw_str = args.bw.lower().replace("gbps","")
    try:
        bw = float(bw_str)
    except ValueError:
        print(f"Error: Invalid format for bandwidth. Only gbps supported. Expected a number or a string like '400Gbps' or '400', but got '{args.bw}'.")
        return

    beta = 1/(bw*1e9)
    m = args.m*8


    reconf_str = args.reconf.lower().replace("ns","")
    try:
        tempreconf = float(reconf_str)
    except ValueError:
        print(f"Error: Invalid format for reconf. Only ms supported. Expected a number or a string like '0.5ns' or '0.5', but got '{args.bw}'.")
        return
    reconf = tempreconf*1e-9

    if args.n <= 1:
        print("Use at least 2 nodes.")
        return
    s = args.n-1
    if s < 1:
        print("Use at least 2 nodes, and n as a power of 2.")
        return

    # startNs = time.perf_counter_ns()
    # total_cost, reconflist = computeSchedule(s, args.k, m, delta, beta)
    # endNs = time.perf_counter_ns()

    # print(f"s = {s}, k = {args.k}, m = {args.m}, delta = {args.delta}")
    # print(f"Minimum total cost: {total_cost}")
    # print(f"Optimal reconfig steps r_i: {reconflist}")
    # print(f"ComputeTime: {endNs - startNs} ns")
    finalTotalCost = np.inf
    finalReconfList = list()
    for k in range(0, s+1):
        total_cost, reconflist = computeSchedule(s, k, m, beta, delta)
        total_cost = total_cost+k*reconf
        if finalTotalCost > total_cost:
            finalTotalCost = total_cost
            finalReconfList = reconflist

    currState = 1
    content = []
    reverseContent = []
    # Note: steps are indexed from 1.
    for step in range(1,s+1):
        rho = step
        # print(rho,step,s, args.n-1)
        if step in finalReconfList:
            currState = step
            rho = step
            print(rho,step)
            for i in range(args.n):
                content.append(f"{step-1} {i} {(((i+rho)%args.n))}")
                print(f"{step-1} {i} {(((i+rho)%args.n))}")
                reverseContent.append(f"{2*s-step} {i} {(((i+rho)%args.n))}")
        else:
            for i in range(args.n):
                content.append(f"{step-1} {i} {(i+1)%args.n}")
                print(f"{step-1} {i} {(i+1)%args.n}")
                reverseContent.append(f"{2*s-step} {i} {(i+1)%args.n}")


    # # Reduction phase
    # for step in range(s, 2*s):
    #     # logical_step goes from s down to 1
    #     logical_step = 2*s - step
        
    #     # Find the correct currState for this logical_step
    #     currState = 1
    #     found = 0
    #     for reconf_step in finalReconfList:
    #         if reconf_step <= logical_step:
    #             currState = reconf_step
    #             found = 1
    #         else:
    #             found = 0
    #             break

    #     if found==0:
    #         for i in range(args.n):
    #             # print(step, i, (i+2**(currState-1))%args.n)
    #             content.append(f"{step-1} {i} {(i+1)%args.n}")
    #     else:
    #         rho = np.sum([(-2)**i for i in range (0,currState)])
    #         for i in range(args.n):
    #             # steps indexing from 0 in the print
    #             # print(step-1, i, (i+2**(currState-1))%args.n)
    #             if i%2:
    #                 content.append(f"{step-1} {i} {(((i+rho)%args.n)+args.n)%args.n}")
    #             else:
    #                 content.append(f"{step-1} {i} {(((i-rho)%args.n)+args.n)%args.n}")

    # print(finalTotalCost)


    file_name = "./../topo-reconfigs/"+"optical-ring-"+str(args.n)+"-"+str(int(args.m))+"-"+delta_str+"ms-"+str(int(bw))+"Gbps-"+reconf_str+"ns"+"-direct1"+".txt"

    with open(file_name, "w") as f:
        f.write(f"Reconfiguration List: {finalReconfList}\n")
        f.write("Total reconfig cost: "+str(len(finalReconfList)*reconf*1e9)+" ns\n")
        f.write("\n".join(content))
        f.write("\n".join(reverseContent))
if __name__ == "__main__":
    main()