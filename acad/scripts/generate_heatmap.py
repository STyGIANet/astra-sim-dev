import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
import sys
import os

def size_to_bytes(size_str):
    """Sorts message sizes (128B, 1KB, etc.) logically by byte value."""
    units = {"B": 1, "KB": 1024, "MB": 1024**2, "GB": 1024**3}
    number = "".join(filter(str.isdigit, str(size_str)))
    unit = "".join(filter(str.isalpha, str(size_str))).upper()
    return int(number) * units.get(unit, 1)

def main():
    if len(sys.argv) < 2:
        print("Usage: python generate_heatmap.py <filename.csv>")
        sys.exit(1)

    file_path = sys.argv[1]
    if not os.path.exists(file_path):
        print(f"Error: File '{file_path}' not found.")
        sys.exit(1)

    # 1. Load data
    df = pd.read_csv(file_path)

    # 2. Sort MSG_NAME logically
    unique_sizes = sorted(df['MSG_NAME'].unique(), key=size_to_bytes)
    df['MSG_NAME'] = pd.Categorical(df['MSG_NAME'], categories=unique_sizes, ordered=True)

    # 3. Extract the 'static' baseline for each message size
    # Since static always has delay 0, we group by size to get the constant baseline
    static_baselines = (
        df[df['SYSTEM'].str.lower() == 'static']
        .groupby('MSG_NAME', observed=False)['COMPLETION_TIME']
        .first()
        .to_dict()
    )

    # 4. Pivot harvest and bvn data
    # We filter out static from the main pivot so it doesn't create empty delay columns
    pivot_df = df[df['SYSTEM'].str.lower() != 'static'].pivot_table(
        index=['MSG_NAME', 'RECONFIG_DELAY'],
        columns='SYSTEM',
        values='COMPLETION_TIME',
        observed=False
    ).reset_index()
    # 5. Map the static baseline and calculate ratios
    harvest = pivot_df['harvest'].astype(float)
    bvn = pivot_df['bvn'].astype(float)
    static_val = pivot_df['MSG_NAME'].map(static_baselines).astype(float)
    
    # Calculate ratios (using series to ensure correct alignment)
    pivot_df['bvn/harvest'] = bvn / harvest
    pivot_df['static/harvest'] = static_val / harvest

    # 6. Create Heatmap Matrices
    h_bvn = pivot_df.pivot(index='MSG_NAME', columns='RECONFIG_DELAY', values='bvn/harvest')
    h_static = pivot_df.pivot(index='MSG_NAME', columns='RECONFIG_DELAY', values='static/harvest')

    # 7. Visualization
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(20, 8))

    # Heatmap 1: BVN / Harvest
    sns.heatmap(h_bvn, annot=True, fmt=".2f", cmap="RdYlGn_r", ax=ax1, center=1.0)
    ax1.set_title(f"Performance Ratio: BVN / Harvest\n(Values > 1.0 mean Harvest is faster)", fontsize=14)
    ax1.invert_yaxis()

    # Heatmap 2: Static / Harvest
    # Using a diverging map to highlight where Harvest outperforms or underperforms Static
    sns.heatmap(h_static, annot=True, fmt=".2f", cmap="coolwarm", ax=ax2, center=1.0)
    ax2.set_title(f"Performance Ratio: Static / Harvest\n(Values > 1.0 mean Harvest is faster)", fontsize=14)
    ax2.invert_yaxis()

    plt.tight_layout()
    
    # Save result
    output_png = os.path.splitext(file_path)[0] + "_heatmap.png"
    plt.savefig(output_png, dpi=300)
    print(f"Heatmap successfully saved to: {output_png}")
    plt.show()

if __name__ == "__main__":
    main()