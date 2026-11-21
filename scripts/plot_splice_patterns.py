"""Vẽ hình cho ứng dụng splice junction từ kết quả đã ghi của scripts/splice_patterns.jl.

Không khai thác lại: chỉ đọc results/applications/splice/ (phải là một lần chạy trên commit sạch)
và ghi results/figures/splice/. Chạy từ repo root:  python scripts/plot_splice_patterns.py
"""
import csv
import hashlib
import json
import platform
import tomllib
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
matplotlib.rcParams["svg.hashsalt"] = "splice"  # id trong SVG cố định, chạy lại ra cùng file
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[1]
RUN = ROOT / "results" / "applications" / "splice"
OUT = ROOT / "results" / "figures" / "splice"
INPUTS = ("itemset_counts.csv", "patterns.csv", "run_info.toml")

CLASSES = ("EI", "IE", "N")
NAMES = {"EI": "EI (donor)", "IE": "IE (acceptor)", "N": "N (đối chứng)"}
COLORS = {"EI": "#2a78d6", "IE": "#eb6834", "N": "#1baf7a"}  # ba slot đầu của bảng màu đã kiểm CVD
MARKERS = {"EI": "o", "IE": "s", "N": "^"}  # mã hóa phụ để in đen trắng vẫn phân biệt
INK, MUTED, GRID = "#0b0b0b", "#52514e", "#e1e0d9"
ENCODINGS = (("nucleotide", "Mã hóa nucleotide (A/C/G/T)"), ("purine_pyrimidine", "Mã hóa purin/pyrimidin (R/Y)"))


def digest(path):
    # Git có thể đổi xuống dòng thành CRLF khi checkout trên Windows; băm bản LF.
    return hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def read_csv(name):
    with (RUN / name).open(newline="", encoding="utf-8") as stream:
        return list(csv.DictReader(stream))


def read_run():
    info = tomllib.loads((RUN / "run_info.toml").read_text(encoding="utf-8"))
    if info["environment"]["dirty"]:
        raise SystemExit("run_info.toml ghi dirty = true: kết quả không ứng với một commit sạch")
    return info, read_csv("itemset_counts.csv"), read_csv("patterns.csv")


def style(axis):
    for side in ("top", "right"):
        axis.spines[side].set_visible(False)
    for side in ("left", "bottom"):
        axis.spines[side].set_color(MUTED)
    axis.tick_params(colors=MUTED, labelcolor=INK, labelsize=8)
    axis.grid(axis="y", color=GRID, linewidth=0.6)
    axis.set_axisbelow(True)


def percent(text):
    return float(text.rstrip("%"))


def plot_counts(info, rows):
    """Số itemset có ít nhất 2 item theo minsup giảm dần, mỗi lớp một đường."""
    fig, axes = plt.subplots(1, 2, figsize=(7.0, 2.8), sharey=True, constrained_layout=True)
    for axis, (encoding, title) in zip(axes, ENCODINGS):
        main = percent(info["mining"][encoding]["minsup_main"])
        axis.axvline(main, color=MUTED, linewidth=0.8)
        axis.annotate(f"minsup chính {main:g}%", (main, 1), xytext=(3, 2), textcoords="offset points",
                      fontsize=7, color=MUTED)
        for cls in CLASSES:
            points = sorted(((percent(r["minsup"]), int(r["itemsets_2plus"]))
                             for r in rows if r["encoding"] == encoding and r["class"] == cls), reverse=True)
            if not points:
                raise SystemExit(f"thiếu dòng {encoding}/{cls} trong itemset_counts.csv")
            xs, ys = zip(*points)
            axis.plot(xs, ys, color=COLORS[cls], marker=MARKERS[cls], markersize=5, linewidth=1.6,
                      label=NAMES[cls])
            axis.annotate(cls, (xs[-1], ys[-1]), xytext=(5, 0), textcoords="offset points", va="center",
                          fontsize=8, color=INK)
        axis.set_xticks(sorted({percent(r["minsup"]) for r in rows if r["encoding"] == encoding}))
        axis.invert_xaxis()
        axis.set_yscale("symlog", linthresh=1)
        axis.set_yticks([0, 1, 10, 100, 1000], ["0", "1", "10", "100", "1000"])
        axis.set_title(title, fontsize=9, color=INK)
        axis.set_xlabel("minsup trong lớp (%)", fontsize=8, color=INK)
        style(axis)
    axes[0].set_ylabel("Số itemset có ≥ 2 item", fontsize=8, color=INK)
    axes[0].legend(fontsize=7, frameon=False, loc="upper left")
    return fig


def plot_enrichment(info, rows):
    """Item đơn phổ biến của EI, IE: tỉ lệ trong lớp chia tỉ lệ ở lớp N, theo vị trí, cả cửa sổ."""
    half = info["data"]["window"] // 2
    positions = [p for p in range(-half, half + 1) if p != 0]
    index = {p: i for i, p in enumerate(positions)}
    main = info["mining"]["nucleotide"]["minsup_main"]
    fig, axes = plt.subplots(2, 1, figsize=(7.0, 4.2), sharex=True, constrained_layout=True)
    for axis, cls in zip(axes, ("EI", "IE")):
        by_position = {}
        for r in rows:
            if r["encoding"] != "nucleotide" or r["class"] != cls or r["length"] != "1":
                continue
            label, ratio = r["itemset"], float(r["growth_vs_n"])
            if ratio != ratio or ratio in (float("inf"), float("-inf")):
                raise SystemExit(f"tỉ lệ không hữu hạn cho {cls} {label}")
            by_position.setdefault(int(label[:-1]), []).append((label[-1], ratio))
        for position, items in by_position.items():
            items.sort()
            for k, (base, ratio) in enumerate(items):
                x = index[position] + (k - (len(items) - 1) / 2) * 0.5
                axis.vlines(x, 1, ratio, color=COLORS[cls], linewidth=1.6)
                axis.text(x, ratio, base, ha="center", va="bottom" if ratio >= 1 else "top", fontsize=6.5,
                          fontweight="bold", color=INK)
        axis.axhline(1, color=MUTED, linewidth=0.8)
        axis.axvline(index[-1] + 0.5, color=MUTED, linewidth=0.8)
        axis.set_ylim(0, 4.6)
        axis.set_title(f"{NAMES[cls]}: item đơn có support ≥ {main} trong lớp", loc="left", fontsize=9, color=INK)
        axis.set_ylabel("tỉ lệ ở lớp / tỉ lệ ở N", fontsize=8, color=INK)
        style(axis)
    axes[0].annotate("ranh giới", (index[-1] + 0.5, 4.4), xytext=(3, 0), textcoords="offset points",
                     fontsize=7, color=MUTED, va="center")
    shown = {-half, -1, 1, half} | {p for p in positions if p % 5 == 0}
    axes[-1].set_xticks(range(len(positions)), [f"{p:+d}" if p in shown else "" for p in positions], fontsize=7)
    # -1 và +1 nằm sát nhau: đẩy hai nhãn về hai phía của đường ranh giới để không dính vào nhau.
    for position, tick in zip(positions, axes[-1].get_xticklabels()):
        if position in (-1, 1):
            tick.set_horizontalalignment("right" if position < 0 else "left")
    axes[-1].set_xlabel("Vị trí so với ranh giới exon/intron (không có vị trí 0)", fontsize=8, color=INK)
    return fig


def main():
    info, counts, patterns = read_run()
    OUT.mkdir(parents=True, exist_ok=True)
    figures = {"itemset_counts": plot_counts(info, counts)}
    figures["position_enrichment"] = plot_enrichment(info, patterns)
    no_date = {"pdf": {"CreationDate": None}, "svg": {"Date": None}, "png": None}  # bỏ ngày giờ khỏi file
    for name, fig in figures.items():
        for ext in ("pdf", "png", "svg"):
            fig.savefig(OUT / f"{name}.{ext}", dpi=300, metadata=no_date[ext])
        plt.close(fig)
    environment = {
        "python": platform.python_version(),
        "matplotlib": matplotlib.__version__,
        "script_sha256": digest(Path(__file__)),
        "inputs_sha256": {name: digest(RUN / name) for name in INPUTS},
    }
    (OUT / "environment.json").write_text(json.dumps(environment, indent=2, ensure_ascii=False) + "\n",
                                          encoding="utf-8", newline="\n")
    # Chỉ in ASCII: console Windows mặc định cp1252 không in được tiếng Việt và sẽ làm script thoát lỗi.
    print(f"Wrote {len(figures)} figures to {OUT}")


if __name__ == "__main__":
    main()
