import os
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
from matplotlib.colors import LogNorm
from matplotlib.ticker import LogFormatter
from matplotlib.ticker import ScalarFormatter, FuncFormatter
from matplotlib.ticker import FixedLocator, NullLocator

configs = [
    (500, 50),
    (10000, 500),
    (500, 500),
]

systems = ['ring', 'static', 'harvest']

custom_labels = ["10ns", "100ns", "1µs", "10µs", "100µs", "1ms", "10ms"]

cmap = mcolors.LinearSegmentedColormap.from_list(
    "CustomRatioMap",
    [
        (0.0, "#FFFFFF"),
        (0.01, "#B8B8B8"),
        (1.0, "#000000"),
    ],
    N=10000
)


def parse_size(size_str):
    size_str = str(size_str).strip().upper()

    if size_str.endswith("KB"):
        return float(size_str[:-2]) * 1024
    elif size_str.endswith("MB"):
        return float(size_str[:-2]) * 1024**2
    elif size_str.endswith("GB"):
        return float(size_str[:-2]) * 1024**3

    return 0


for alpha, delay in configs:

    ring_file = f"../results/harvest/64-ring-800-{alpha}-{delay}.csv"
    hd_file = f"../results/harvest/64-halvingDoubling-800-{alpha}-{delay}.csv"

    if not os.path.exists(ring_file):
        print(f"Skipping missing file: {ring_file}")
        continue

    if not os.path.exists(hd_file):
        print(f"Skipping missing file: {hd_file}")
        continue

    print(f"Processing {alpha=} {delay=}")

    df_ring = pd.read_csv(ring_file)
    df_hd = pd.read_csv(hd_file)

    df = pd.concat([df_ring, df_hd], ignore_index=True)
    df = df[df["SYSTEM"].isin(systems)]

    df_agg = (
        df.groupby(["SYSTEM", "MSG_NAME", "RECONFIG_DELAY"])["COMPLETION_TIME"]
        .mean()
        .reset_index()
    )

    pivots = {}

    for sys in systems:
        sys_df = df_agg[df_agg["SYSTEM"] == sys]

        pivot = sys_df.pivot(
            index="MSG_NAME",
            columns="RECONFIG_DELAY",
            values="COMPLETION_TIME",
        )

        pivot = pivot.loc[sorted(pivot.index, key=parse_size)]
        pivots[sys] = pivot

    # --------------------------
    # Ratios
    # --------------------------
    h_ring = pivots["ring"] / pivots["harvest"]
    h_static = pivots["static"] / pivots["harvest"]
    h_harvest_ring = pivots["harvest"] / pivots["ring"]
    best_sr = pd.concat([pivots["ring"], pivots["static"]]).groupby(level=0).min() / pivots["harvest"]
    best_sr = best_sr.loc[sorted(best_sr.index, key=parse_size)]
    actual_labels = custom_labels[:len(h_ring.columns)]

    base_name = f"64-nodes-{alpha}-{delay}"

    # =========================================================
    # Ring / Harvest
    # =========================================================
    plt.figure(figsize=(10, 8))

    vmax_ring = max(h_ring.max().max(), 1.001)

    ax1 = sns.heatmap(
        h_ring,
        annot=False,
        fmt=".2f",
        linewidths=.5,
        linecolor='lightgray',
        norm=LogNorm(vmin=1.0, vmax=vmax_ring),
        cmap=cmap,
        cbar_kws={'label': 'Ring / Harvest w/RD'}
    )

    cbar = ax1.collections[0].colorbar

    # custom tick override ONLY for (500, 50)


    # cbar3.set_ticklabels([str(t) for t in ticks])
    if alpha == 500 and delay == 50:
        ticks = [1, 2, 4, 8]
        cbar.ax.yaxis.set_major_locator(FixedLocator(ticks))
        cbar.ax.yaxis.set_minor_locator(NullLocator())
        # cbar.set_ticks(ticks)
        cbar.set_ticklabels([str(t) for t in ticks])
    else:
        cbar.ax.yaxis.set_major_formatter(LogFormatter(base=10.0))

    cbar.ax.tick_params(labelsize=24)
    cbar.set_label('Ring / Harvest w/RD', fontsize=26)

    ax1.set_xticklabels(actual_labels)
    ax1.set_xlabel('Reconfiguration Delay', fontsize=26)
    ax1.set_ylabel('Message Size', fontsize=26)
    ax1.tick_params(axis='both', which='major', labelsize=28, labelrotation=30)

    plt.tight_layout()
    plt.savefig(f"../results/harvest/{base_name}-ring-harvest.png", dpi=300)
    plt.close()

    # =========================================================
    # Static / Harvest
    # =========================================================
    plt.figure(figsize=(10, 8))

    ax2 = sns.heatmap(
        h_static,
        annot=False,
        fmt=".2f",
        linewidths=.5,
        linecolor='lightgray',
        cmap=cmap,
        cbar_kws={'label': 'Static RD / Harvest w/RD'}
    )

    cbar2 = ax2.collections[0].colorbar
    cbar2.ax.tick_params(labelsize=24)
    cbar2.set_label('Static RD / Harvest w/RD', fontsize=26)

    ax2.set_xticklabels(actual_labels)
    ax2.set_xlabel('Reconfiguration Delay', fontsize=26)
    ax2.set_ylabel('Message Size', fontsize=26)
    ax2.tick_params(axis='both', which='major', labelsize=28, labelrotation=30)

    plt.tight_layout()
    plt.savefig(f"../results/harvest/{base_name}-static-harvest.png", dpi=300)
    plt.close()

    # =========================================================
    # Harvest / Ring (NEW)
    # =========================================================
    plt.figure(figsize=(10, 8))

    vmax_hr = max(h_harvest_ring.max().max(), 1.001)

    ax3 = sns.heatmap(
        h_harvest_ring,
        annot=False,
        fmt=".2f",
        linewidths=.5,
        linecolor='lightgray',
        norm=LogNorm(vmin=1.0, vmax=vmax_hr),
        cmap=cmap,
        cbar_kws={'label': 'Harvest w/RD / Ring'}
    )

    cbar3 = ax3.collections[0].colorbar

    if alpha == 10000 and delay == 500:
        ticks = [1, 2]
    else:
        ticks = [1, 2,3]

    cbar3.ax.yaxis.set_major_locator(FixedLocator(ticks))
    cbar3.ax.yaxis.set_minor_locator(NullLocator())
    cbar3.set_ticklabels([str(t) for t in ticks])
    cbar3.ax.tick_params(labelsize=24)
    cbar3.set_label('Harvest w/RD / Ring', fontsize=26)

    ax3.set_xticklabels(actual_labels)
    ax3.set_xlabel('Reconfiguration Delay', fontsize=26)
    ax3.set_ylabel('Message Size', fontsize=26)
    ax3.tick_params(axis='both', which='major', labelsize=28, labelrotation=30)

    plt.tight_layout()
    plt.savefig(f"../results/harvest/{base_name}-harvest-ring.png", dpi=300)
    plt.close()


    # --------------------------
    # Best(static, ring) / Harvest
    # --------------------------

    plt.figure(figsize=(10, 8))

    vmax_best = max(best_sr.max().max(), 1.001)

    ax4 = sns.heatmap(
        best_sr,
        annot=False,
        fmt=".2f",
        linewidths=.5,
        linecolor='lightgray',
        norm=LogNorm(vmin=1.0, vmax=vmax_best),
        cmap=cmap,
        cbar_kws={'label': 'Best / Harvest w/RD'}
    )

    cbar4 = ax4.collections[0].colorbar

    # SAME STYLE AS YOUR OTHER PLOTS
    ticks = [1, 2,4,6,8]

    cbar4.ax.yaxis.set_major_locator(FixedLocator(ticks))
    cbar4.ax.yaxis.set_minor_locator(NullLocator())
    cbar4.set_ticklabels([str(t) for t in ticks])
    # cbar4.ax.yaxis.set_major_formatter(LogFormatter(base=10.0))

    cbar4.ax.tick_params(labelsize=24)
    cbar4.set_label('Best / Harvest w/RD', fontsize=26)

    ax4.set_xticklabels(actual_labels)
    ax4.set_xlabel('Reconfiguration Delay', fontsize=26)
    ax4.set_ylabel('Message Size', fontsize=26)
    ax4.tick_params(axis='both', which='major', labelsize=28, labelrotation=30)

    plt.tight_layout()
    plt.savefig(f"../results/harvest/{base_name}-best-harvest.png", dpi=300)
    plt.close()