import json
import math
from pathlib import Path

def recursive_doubling_cost(alpha, delta, bandwidth_gbps, m_bits, p):
    beta = 1 / bandwidth_gbps
    steps = math.ceil(math.log2(p))

    total_time = 0
    for i in range(steps):
        total_time += alpha + delta + beta * m_bits / (2 ** (i + 1))
    return total_time


def load_cost(json_file):
    with open(json_file, "r") as f:
        data = json.load(f)
    return data["cost"]


# ---- Parameters (must match bash script) ----
P = 64
BW_GBPS = 800.0
ALPHA = 1000
DELTA = 1000

MESSAGE_SIZES = [1048576, 2097152, 4194304, 8388608, 16777216, 33554432, 67108864, 134217728, 268435456]  # bytes

print("MSG(bytes) | Synth Cost | Model Cost | Abs Diff | Rel Err (%)")
print("-" * 65)

for msg_bytes in MESSAGE_SIZES:
    json_file = Path(f"rd-64-{msg_bytes}-800-1000-1000-0.json")

    if not json_file.exists():
        print(f"{msg_bytes:>10} | MISSING FILE")
        continue

    msg_bits = msg_bytes * 8

    synth_cost = load_cost(json_file)
    model_cost = recursive_doubling_cost(
        ALPHA, DELTA, BW_GBPS, msg_bits, P
    )

    abs_diff = synth_cost - model_cost
    rel_err = abs_diff / model_cost * 100

    print(
        f"{msg_bytes:>10} | "
        f"{synth_cost:11.3f} | "
        f"{model_cost:11.3f} | "
        f"{abs_diff:8.3f} | "
        f"{rel_err:9.2f}"
    )
