import pandas as pd
import matplotlib.pyplot as plt

files = {
    "mσ = 1": "csv_tj_01_bi_circle_shrink_bounds_ms1.csv",
    "mσ = 2": "csv_tj_01_bi_circle_shrink_bounds_ms2.csv",
    "mσ = 4": "csv_tj_01_bi_circle_shrink_bounds_ms4.csv",
}

plt.figure(figsize=(8, 6))

for label, file in files.items():
    df = pd.read_csv(file)
    time = df["time"]
    area = df["phi1_integral"]
    plt.plot(time, area, linewidth=2, label=label)

plt.xlabel("Time")
plt.ylabel("phi1_integral (area indicator)")
plt.title("Circular grain shrinkage: mσ scaling comparison")
plt.legend()
plt.grid(True)
plt.tight_layout()
plt.savefig("tj01_msigma_scan_area_vs_time.png", dpi=300)
plt.show()