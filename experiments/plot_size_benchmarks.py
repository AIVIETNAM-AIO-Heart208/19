"""Plot verified API timing runs; no mining or input generation."""
import csv
import hashlib
import json
import math
from pathlib import Path
import statistics
import sys
import tomllib

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter

ROOT = Path(__file__).resolve().parents[1]


def vi_number(value, _position=None):
    """Số theo kiểu báo cáo: dấu chấm ngăn hàng nghìn, dấu phẩy thập phân."""
    if float(value).is_integer():
        return f"{int(value):,}".replace(",", ".")
    return f"{value:.6g}".replace(".", ",")


def digest(path):
    return hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def read_run(directory):
    metadata = tomllib.loads((directory / "environment.toml").read_text(encoding="utf-8"))
    if not metadata["complete"] or metadata["pilot"]:
        raise ValueError("Need completed official run")
    for file in ("raw.csv", "summary.csv"):
        expected = metadata["artifacts"][file]
        if digest(directory / file) != expected:
            raise ValueError("Artifact checksum mismatch")
    with (directory / "summary.csv").open(newline="", encoding="utf-8") as stream:
        rows = list(csv.DictReader(stream))
    if metadata["kind"] not in ("scalability", "transaction_length"):
        raise ValueError("Unknown experiment kind")
    config = metadata["config"]
    levels = config["percentages"] if metadata["kind"] == "scalability" else config["lengths"]
    expected_ids = list(range(1, len(levels) + 1))
    if ([int(r["case_id"]) for r in rows] != expected_ids
            or [int(r["level"]) for r in rows] != levels
            or [c["case_id"] for c in metadata["cases"]] != expected_ids):
        raise ValueError("Incomplete validated grid")
    with (directory / "raw.csv").open(newline="", encoding="utf-8") as stream:
        raw = list(csv.DictReader(stream))
    repeats = config["repeats"]
    if repeats < 5 or len(raw) != len(rows) * repeats:
        raise ValueError("Incomplete raw samples")
    for row, case in zip(rows, metadata["cases"]):
        if (row["validation"] != "exact_match" or case["status"] != "exact_match"
                or row["scope"] != "warmed_api" or int(row["repeats"]) != repeats
                or row["input_sha256"] != case["sha256"]):
            raise ValueError("Unvalidated case")
        samples = [r for r in raw if r["case_id"] == row["case_id"]]
        if sorted(int(r["repeat"]) for r in samples) != list(range(1, repeats + 1)):
            raise ValueError("Missing or duplicate repeats")
        if any(r["validation"] != "exact_match" or r["scope"] != "warmed_api"
               or r["itemsets"] != row["itemsets"] for r in samples):
            raise ValueError("Invalid raw sample")
        times = [float(r["seconds"]) for r in samples]
        if any(not math.isfinite(t) or t < 0 for t in times):
            raise ValueError("Invalid timing")
        q1, _, q3 = statistics.quantiles(times, n=4, method="inclusive")
        for key, expected in (("median_seconds", statistics.median(times)),
                              ("q1_seconds", q1), ("q3_seconds", q3), ("iqr_seconds", q3-q1)):
            if not math.isclose(float(row[key]), expected, rel_tol=1e-12, abs_tol=1e-12):
                raise ValueError("Summary disagrees with raw samples")
    return metadata, rows


def plot_title(metadata):
    if metadata["kind"] == "scalability":
        return f"Khả năng mở rộng trên {metadata['config']['dataset'].capitalize()}"
    return "Độ dài giao dịch trên CSDL tổng hợp"


def plot(directory):
    metadata, rows = read_run(directory)
    output = ROOT / "results/figures" / directory.name
    output.mkdir(parents=True, exist_ok=True)
    scalability = metadata["kind"] == "scalability"
    x = [float(r["n"] if scalability else r["mean_length"]) for r in rows]
    for metric in ("runtime", "itemsets"):
        fig, axis = plt.subplots(figsize=(6.4,4), layout="constrained")
        if metric == "runtime":
            y = [float(r["median_seconds"]) for r in rows]
            errors = [[float(r["median_seconds"])-float(r["q1_seconds"]) for r in rows],
                      [float(r["q3_seconds"])-float(r["median_seconds"]) for r in rows]]
            axis.errorbar(x,y,yerr=errors,marker="o",capsize=3,label="Bản bitset (trung vị, Q1–Q3)")
            axis.set_ylabel("Thời gian gọi hàm khai thác, sau một lượt làm nóng (giây)")
        else:
            axis.plot(x,[int(r["itemsets"]) for r in rows],marker="o",label="Khớp hoàn toàn với SPMF")
            axis.set_ylabel("Số itemset phổ biến")
        axis.set_xlabel("Số giao dịch" if scalability else "Độ dài giao dịch trung bình (item)")
        axis.set_xticks(x)
        axis.xaxis.set_major_formatter(FuncFormatter(vi_number))
        axis.yaxis.set_major_formatter(FuncFormatter(vi_number))
        axis.set_title(plot_title(metadata))
        axis.grid(alpha=.25); axis.legend(fontsize=8)
        for extension in ("png","svg","pdf"):
            fig.savefig(output/f"{metric}.{extension}",dpi=180)
        plt.close(fig)
    environment = {
        "matplotlib": matplotlib.__version__,
        "script_sha256": digest(Path(__file__)),
        "summary_sha256": digest(directory / "summary.csv"),
    }
    (output / "environment.json").write_text(json.dumps(environment, indent=2), encoding="utf-8")
    print(output)


if __name__ == "__main__":
    plot(Path(sys.argv[1]).resolve())
