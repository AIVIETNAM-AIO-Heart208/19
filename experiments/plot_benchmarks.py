"""Validate a completed run and plot its recorded summaries (no mining)."""
import argparse
import csv
import hashlib
import json
import platform
from pathlib import Path
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
    if not metadata["complete"]:
        raise ValueError("Run is incomplete")
    for name, expected in metadata["artifacts"].items():
        if digest(directory / name) != expected:
            raise ValueError(f"Modified artifact: {name}")
    with (directory / "summary.csv").open(newline="", encoding="utf-8") as stream:
        rows = list(csv.DictReader(stream))
    for dataset in {r["dataset"] for r in rows}:
        groups = {m: [r for r in rows if r["dataset"] == dataset and r["miner"] == m]
                  for m in ("julia", "spmf")}
        expected = metadata["config"]["minsup"][dataset]
        for group in groups.values():
            if [r["minsup"] for r in group] != expected:
                raise ValueError("Missing or reordered grid")
            counts = [int(r["itemsets"]) for r in group]
            if counts != sorted(counts):
                raise ValueError("Nonmonotonic pattern count")
            for row in group:
                required = 1 if metadata["pilot"] else metadata["config"]["repeats"]
                if row["validation"] != "exact_match" or int(row["repeats"]) != required:
                    raise ValueError("Unvalidated or incomplete group")
        if [r["itemsets"] for r in groups["julia"]] != [r["itemsets"] for r in groups["spmf"]]:
            raise ValueError("Counts disagree")
    return rows


def plot(directory):
    rows = read_run(directory)
    output = ROOT / "results" / "figures" / directory.name
    output.mkdir(parents=True, exist_ok=True)
    plt.rcParams.update({"font.size": 10, "svg.fonttype": "none"})
    for dataset in dict.fromkeys(r["dataset"] for r in rows):
        for metric in ("runtime", "itemsets"):
            fig, axis = plt.subplots(figsize=(6.4, 4.0), layout="constrained")
            for miner, label, marker in (("julia", "Bản bitset (Julia)", "o"),
                                         ("spmf", "SPMF", "x")):
                group = [r for r in rows if r["dataset"] == dataset and r["miner"] == miner]
                x = [float(r["minsup"].removesuffix("%")) for r in group]
                if metric == "runtime":
                    y = [float(r["median_seconds"]) for r in group]
                    errors = [[float(r["median_seconds"]) - float(r["q1_seconds"]) for r in group],
                              [float(r["q3_seconds"]) - float(r["median_seconds"]) for r in group]]
                    axis.errorbar(x, y, yerr=errors, marker=marker, capsize=3, label=label)
                else:
                    axis.plot(x, [int(r["itemsets"]) for r in group], marker=marker,
                              linestyle="--" if miner == "spmf" else "-", label=label)
            axis.invert_xaxis()
            axis.set_xticks(x, [vi_number(value) for value in x], rotation=35, ha="right", fontsize=9)
            axis.yaxis.set_major_formatter(FuncFormatter(vi_number))
            axis.set_xlabel("minsup (%), từ cao xuống thấp")
            axis.set_ylabel("Thời gian toàn trình (giây)" if metric == "runtime" else "Số itemset phổ biến")
            axis.set_title(f"{dataset.upper()} — " + ("thời gian toàn trình" if metric == "runtime" else "số itemset phổ biến"))
            axis.grid(alpha=0.25)
            axis.legend()
            for extension in ("png", "svg", "pdf"):
                fig.savefig(output / f"{dataset}_{metric}.{extension}", dpi=180)
            plt.close(fig)
    environment = {
        "python": platform.python_version(),
        "matplotlib": matplotlib.__version__,
        "script_sha256": digest(Path(__file__)),
        "summary_sha256": digest(directory / "summary.csv"),
    }
    (output / "environment.json").write_text(json.dumps(environment, indent=2) + "\n", encoding="utf-8")
    print(output)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run_directory", type=Path)
    plot(parser.parse_args().run_directory.resolve())
