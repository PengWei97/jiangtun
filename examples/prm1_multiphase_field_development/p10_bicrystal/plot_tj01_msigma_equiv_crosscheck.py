import pandas as pd
import matplotlib.pyplot as plt

files = {
    "σ=2.0, m=1.0": "csv_tj_01_bi_circle_shrink_bounds_eqms_a.csv",
    "σ=1.0, m=2.0": "csv_tj_01_bi_circle_shrink_bounds_eqms_b.csv",
    "σ=4.0, m=0.5": "csv_tj_01_bi_circle_shrink_bounds_eqms_c.csv",
}

plt.figure(figsize=(8, 6))

for label, file in files.items():
    df = pd.read_csv(file)
    time = df["time"]
    area = df["phi1_integral"]
    plt.plot(time, area, linewidth=2, label=label)

plt.xlabel("Time")
plt.ylabel("phi1_integral (area indicator)")
plt.title("Equivalent mσ cross-check")
plt.legend()
plt.grid(True)
plt.tight_layout()
plt.savefig("tj01_msigma_equiv_crosscheck_area_vs_time.png", dpi=300)
plt.show()