"""Validate a completed memory_real run and plot its recorded summary (no mining)."""
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

ROOT = Path(__file__).resolve().parents[1]
MINERS = ("baseline", "bitset")


def digest(path):
    # Line endings may be converted by git on Windows; hash the LF form.
    return hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def read_run(directory):
    metadata = tomllib.loads((directory / "environment.toml").read_text(encoding="utf-8"))
    for name, expected in metadata["artifacts"].items():
        if digest(directory / name) != expected:
            raise ValueError(f"Modified artifact: {name}")
    with (directory / "summary.csv").open(newline="", encoding="utf-8") as stream:
        rows = list(csv.DictReader(stream))
    cases = [(c["dataset"], c["minsup"]) for c in metadata["config"]["case"]]
    for dataset, minsup in cases:
        group = {r["miner"]: r for r in rows if r["dataset"] == dataset and r["minsup"] == minsup}
        if set(group) != set(MINERS):
            raise ValueError(f"Missing miner for {dataset} {minsup}")
        for row in group.values():
            if row["status"] != "success" or int(row["repeats_ok"]) != metadata["config"]["repeats"]:
                raise ValueError("Unvalidated or incomplete group")
            if int(row["vertical_summarysize_bytes"]) < int(row["vertical_estimate_bytes"]):
                raise ValueError("Measured size below the formula lower bound")
        if group["baseline"]["itemsets"] != group["bitset"]["itemsets"]:
            raise ValueError("Counts disagree")
    if len(rows) != 2 * len(cases):
        raise ValueError("Unexpected rows in summary")
    return cases, {(r["dataset"], r["minsup"], r["miner"]): r for r in rows}


def bars(axis, cases, values, ylabel, title):
    width = 0.38
    for k, miner in enumerate(MINERS):
        axis.bar([i + (k - 0.5) * width for i in range(len(cases))],
                 [values[(c, miner)] for c in cases], width, label=miner)
    axis.set_xticks(range(len(cases)), [f"{d}\n{m}" for d, m in cases], fontsize=8)
    axis.set_xlabel("Dataset and minimum support")
    axis.set_ylabel(ylabel)
    axis.set_title(title)
    axis.grid(axis="y", alpha=0.25)


def plot(directory):
    cases, rows = read_run(directory)
    output = ROOT / "results" / "figures" / directory.name
    output.mkdir(parents=True, exist_ok=True)
    plt.rcParams.update({"font.size": 10, "svg.fonttype": "none"})

    # (a) Summed summarysize of the single-item TID structures (root only): lower bound, log scale.
    fig, axis = plt.subplots(figsize=(6.4, 4.0), layout="constrained")
    sizes = {(c, m): int(rows[(*c, m)]["vertical_summarysize_bytes"]) for c in cases for m in MINERS}
    bars(axis, cases, sizes, "Root vertical structure, summarysize (bytes, log)",
         "MEMORY — vertical structure (TID-list vs BitVector)")
    axis.set_yscale("log")
    axis.legend()
    # (b) Absolute peak RSS of the whole process; black ticks mark the RSS right before mining.
    fig2, axis2 = plt.subplots(figsize=(6.4, 4.0), layout="constrained")
    peaks = {(c, m): int(rows[(*c, m)]["median_peak_rss_bytes"]) / 1e6 for c in cases for m in MINERS}
    bars(axis2, cases, peaks, "Process peak RSS (MB, median of repeats)", "MEMORY — peak RSS")
    for k, miner in enumerate(MINERS):
        axis2.scatter([i + (k - 0.5) * 0.38 for i in range(len(cases))],
                      [int(rows[(*c, miner)]["median_rss_before_bytes"]) / 1e6 for c in cases],
                      marker="_", s=300, color="black", zorder=3,
                      label="RSS before mining" if k == 0 else None)
    axis2.legend()
    for figure, name in ((fig, "vertical_structure"), (fig2, "peak_rss")):
        for extension in ("png", "svg", "pdf"):
            figure.savefig(output / f"{name}.{extension}", dpi=180)
        plt.close(figure)
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
