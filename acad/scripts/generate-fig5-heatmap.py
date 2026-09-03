import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
import matplotlib
import sys
import os
import matplotlib.colors as mcolors
from matplotlib.colors import LogNorm
from matplotlib.ticker import LogLocator, LogFormatter, FuncFormatter

def size_to_bytes(size_str):
    """Sorts message sizes (128B, 1KB, etc.) logically by byte value."""
    units = {"B": 1, "KB": 1024, "MB": 1024**2, "GB": 1024**3}
    number = "".join(filter(str.isdigit, str(size_str)))
    unit = "".join(filter(str.isalpha, str(size_str))).upper()
    return int(number) * units.get(unit, 1)

# CHANGE 1: Added function to parse algorithm parameters from filename
def parse_filename(filename):
    """
    Parse filename like '64-direct1-800-10-10000.csv' to extract:
    - algo_name: direct1
    - alpha: 10
    - delta: 10000
    Returns a formatted string for plot titles.
    """
    basename = os.path.basename(filename)
    parts = basename.replace('.csv', '').split('-')
    
    if len(parts) >= 5:
        algo_name = parts[1]  # direct1
        if algo_name == 'direct1':
            algo_name = 'AlltoAll'
        elif algo_name == 'halvingDoubling':
            algo_name = "Recursive Doubling"
        elif algo_name == 'swing':
            algo_name = "Swing"
        alpha = parts[3]      # 10
        delta = parts[4]      # 10000
        return f"{algo_name} (α={alpha}ns, δ={delta}ns)"
    else:
        return "Unknown Algorithm"

def main():
    matplotlib.rcParams.update({'font.size': 40})
    if len(sys.argv) < 2:
        print("Usage: python generate-fig5-heatmap.py <filename.csv>")
        sys.exit(1)

    file_path = sys.argv[1]
    if not os.path.exists(file_path):
        print(f"Error: File '{file_path}' not found.")
        sys.exit(1)

    # CHANGE 2: Extract algorithm info from filename for plot titles
    algo_info = parse_filename(file_path)
    print(f"Algorithm: {algo_info}")

    # 1. Load data
    df = pd.read_csv(file_path)

    # 2. Sort MSG_NAME logically
    unique_sizes = sorted(df['MSG_NAME'].unique(), key=size_to_bytes)
    df['MSG_NAME'] = pd.Categorical(df['MSG_NAME'], categories=unique_sizes, ordered=True)

    # 3. Extract the 'static' baseline
    static_baselines = (
        df[df['SYSTEM'].str.lower() == 'static']
        .groupby('MSG_NAME', observed=False)['COMPLETION_TIME']
        .first()
        .to_dict()
    )

    # 4. Pivot harvest and bvn data
    pivot_df = df[df['SYSTEM'].str.lower() != 'static'].pivot_table(
        index=['MSG_NAME', 'RECONFIG_DELAY'],
        columns='SYSTEM',
        values='COMPLETION_TIME',
        observed=False
    ).reset_index()

    # 5. Calculate ratios
    harvest = pivot_df['harvest'].astype(float)
    bvn = pivot_df['bvn'].astype(float)
    static_val = pivot_df['MSG_NAME'].map(static_baselines).astype(float)
    
    pivot_df['bvn/harvest'] = bvn / harvest
    pivot_df['static/harvest'] = static_val / harvest
    # NEW: Calculate max / Harvest
    pivot_df['best/harvest'] = pivot_df[['bvn', 'MSG_NAME']].apply(
        lambda row: min(row['bvn'], static_baselines[row['MSG_NAME']]), axis=1
    ).astype(float) / harvest

    # 6. Create Heatmap Matrices
    h_bvn = pivot_df.pivot(index='MSG_NAME', columns='RECONFIG_DELAY', values='bvn/harvest')
    h_static = pivot_df.pivot(index='MSG_NAME', columns='RECONFIG_DELAY', values='static/harvest')
    h_best = pivot_df.pivot(index='MSG_NAME', columns='RECONFIG_DELAY', values='best/harvest')

    custom_labels = ["10ns", "100ns", "1µs", "10µs", "100µs", "1ms", "10ms"]
    base_name = os.path.splitext(file_path)[0]

    

    cmap = mcolors.LinearSegmentedColormap.from_list(
        "CustomRatioMap",
        [
            (0.0, "#FFFFFF"),     # Low values -> White
            (0.01, "#B8B8B8"),    # Just above 0 -> Light Gray
            (1.0, "#000000"),     # High values -> Black
        ],
        N=10000
    )

    formatter = FuncFormatter(lambda y, pos: f'{y:.0f}')

    # --- Heatmap 1: BVN / Harvest ---
    plt.figure(figsize=(12, 8))

    vmax_bvn = max(h_bvn.max().max(), 1.001)
    norm_bvn = LogNorm(vmin=1.0, vmax=vmax_bvn)

    ax1 = sns.heatmap(
        h_bvn, annot=False, fmt=".2f",
        linewidths=.5, linecolor='lightgray', norm=norm_bvn,
        cmap=cmap, cbar_kws={'label': 'BvN / Harvest'}
    )


    vmax_static = max(h_static.max().max(), 1.001)
    # norm_static = LogNorm(vmin=1.0, vmax=vmax_static)

    # Set log-scale ticks at nice positions
    cbar = ax1.collections[0].colorbar
    # cbar.ax.yaxis.set_major_locator(LogLocator(base=10.0))
    cbar.ax.yaxis.set_major_formatter(LogFormatter(base=10.0))
    cbar.ax.tick_params(labelsize=36)
    cbar.set_label('BvN / Harvest', fontsize=32)
    ax1.set_xlabel("Reconfiguration Delay")
    ax1.set_xticklabels(custom_labels)
    ax1.set_xlabel('Reconfiguration Delay', fontsize=32)
    ax1.set_ylabel('Message Size', fontsize=32)
    ax1.tick_params(axis='both', which='major', labelsize=36, labelrotation=30)
    
    # CHANGE 3: Add title with algorithm info to BvN/Harvest plot
    # plt.title(f'{algo_info}', fontsize=32, pad=20)
    
    plt.tight_layout()
    plt.savefig(f"{base_name}-bvn-harvest12,8.png", dpi=300)

    # --- Heatmap 2: Static / Harvest ---
    plt.figure(figsize=(12, 8))
    ax2 = sns.heatmap(
        h_static, annot=False, fmt=".2f",
        linewidths=.5, linecolor='lightgray',
        cmap=cmap, center=None, cbar_kws={'label': 'Static / Harvest'}
    )
    
    cbar = ax2.collections[0].colorbar
    # cbar.ax.yaxis.set_major_locator(LogLocator(base=10.0, numticks=10))
    # cbar.ax.yaxis.set_major_formatter(LogFormatter(base=10.0))
    cbar.ax.tick_params(labelsize=36)
    cbar.set_label('Static / Harvest', fontsize=32)
    ax2.set_xlabel("Reconfiguration Delay")
    ax2.set_xticklabels(custom_labels)
    ax2.set_xlabel('Reconfiguration Delay', fontsize=32)
    ax2.set_ylabel('Message Size', fontsize=32)
    ax2.tick_params(axis='both', which='major', labelsize=36, labelrotation=30)
    
    # CHANGE 4: Add title with algorithm info to Static/Harvest plot
    # plt.title(f'{algo_info}', fontsize=32, pad=20)
    
    plt.tight_layout()
    plt.savefig(f"{base_name}-static-harvest12,8.png", dpi=300)

    # --- Heatmap 3: max / Harvest ---
    plt.figure(figsize=(12, 8))

    # vmax_best = max(h_best.max().max(), 1.001)
    # norm_best = LogNorm(vmin=1.0, vmax=vmax_best)

    ax3 = sns.heatmap(
        h_best, annot=False, fmt=".2f",
        linewidths=.5, linecolor='lightgray', vmin=1.0,
        cmap=cmap, cbar_kws={'label': 'Best / Harvest'}
    )

    # Set log-scale ticks at nice positions
    cbar = ax3.collections[0].colorbar
    cbar.ax.yaxis.set_major_formatter(LogFormatter(base=10.0))
    cbar.ax.tick_params(labelsize=36)
    cbar.set_label('Best / Harvest', fontsize=32)
    ax3.set_xlabel("Reconfiguration Delay")
    ax3.set_xticklabels(custom_labels)
    ax3.set_xlabel('Reconfiguration Delay', fontsize=32)
    ax3.set_ylabel('Message Size', fontsize=32)
    ax3.tick_params(axis='both', which='major', labelsize=36, labelrotation=30)
    
    # plt.title(f'{algo_info}', fontsize=32, pad=20)
    matplotlib.rcParams.update({'font.size': 40})
    
    plt.tight_layout()
    plt.savefig(f"{base_name}-best-harvest12,8.png", dpi=300)

    plt.show()

if __name__ == "__main__":
    main()