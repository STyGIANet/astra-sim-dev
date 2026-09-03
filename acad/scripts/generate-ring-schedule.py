import json
import os
import argparse

def generate_ring_schedule_allreduce(num_nodes=64):
    """
    Generates a Ring-based All-Reduce communication schedule.
    """
    steps = []
    # Ring All-Reduce typically takes 2 * (N - 1) steps 
    num_steps = 2 * (num_nodes - 1)
    
    for step_idx in range(1, num_steps + 1):
        topology = []
        for src in range(num_nodes):
            dst = (src + 1) % num_nodes
            # Formatted as [source, destination, weight/link_count]
            topology.append([src, dst, 1])
            
        steps.append({
            "step": step_idx,
            "topology": topology
        })
        
    data = {
        "num_of_reconfigs": 0,
        "collective": "all-reduce-ring-nd",
        "steps": steps
    }
    return data

if __name__ == "__main__":
    # Setup command-line argument parsing
    parser = argparse.ArgumentParser(description="Generate MPI Collective Communication patterns.")
    
    # Arguments
    parser.add_argument("num_nodes", type=int, help="Number of nodes in the topology (integer)")
    parser.add_argument("filename", type=str, help="The output JSON file path (e.g., harvest.json)")

    args = parser.parse_args()

    # Generate the schedule configuration using the CLI inputs
    schedule_data = generate_ring_schedule_allreduce(
        num_nodes=args.num_nodes
    )
    
    # Save to the specified file
    with open(args.filename, "w") as f:
        json.dump(schedule_data, f, indent=2)
        
    print(f"Success: Pattern with {args.num_nodes} nodes saved to '{args.filename}'")