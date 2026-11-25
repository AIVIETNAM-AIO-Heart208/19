"""Integrity and drawing checks for the memory plots; no Julia, no mining, only a tiny fake run."""
import csv
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("memory_figures", ROOT / "experiments/plot_memory_real.py")
figures = importlib.util.module_from_spec(spec)
spec.loader.exec_module(figures)

FIELDS = ["dataset", "minsup", "miner", "status", "repeats_ok", "median_delta_peak_rss_bytes",
          "median_rss_before_bytes", "median_peak_rss_bytes", "vertical_summarysize_bytes",
          "vertical_estimate_bytes", "itemsets"]


def row(dataset, minsup, miner, repeats_ok=3, delta="5000000"):
    return dict(zip(FIELDS, [dataset, minsup, miner, "success", repeats_ok, delta, 240_000_000,
                             260_000_000, 1_000 if miner == "bitset" else 9_000, 800, 7]))


def make_run(path, rows, cases=(("chess", "75%"), ("retail", "0.1%"))):
    with (path / "summary.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, FIELDS)
        writer.writeheader()
        writer.writerows(rows)
    cases_toml = "".join(f'[[config.case]]\ndataset = "{d}"\nminsup = "{m}"\n' for d, m in cases)
    (path / "environment.toml").write_text(
        f'[config]\nrepeats = 3\n{cases_toml}[artifacts]\n"summary.csv" = "{figures.digest(path / "summary.csv")}"\n',
        encoding="utf-8")


def full_rows():
    return [row(d, m, miner) for d, m in (("chess", "75%"), ("retail", "0.1%")) for miner in figures.MINERS]


class MemoryFigureTests(unittest.TestCase):
    def test_rejects_modified_summary(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            make_run(path, full_rows())
            (path / "summary.csv").write_text("modified", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "Modified artifact"):
                figures.read_run(path)

    def test_rejects_incomplete_run(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            make_run(path, full_rows()[:2])  # the second planned case was never measured
            with self.assertRaisesRegex(ValueError, "Missing miner"):
                figures.read_run(path)
            rows = full_rows()
            rows[0] = row("chess", "75%", "baseline", repeats_ok=2)  # fewer repeats than planned
            make_run(path, rows)
            with self.assertRaisesRegex(ValueError, "incomplete"):
                figures.read_run(path)

    def test_rejects_failed_count_validation_before_drawing(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            rows = full_rows()
            for entry in rows:
                if entry["dataset"] == "chess":
                    entry.update(status="validation_failed", itemsets="")
            make_run(path, rows)
            with self.assertRaisesRegex(ValueError, "Unvalidated"):
                figures.plot(path)

    def test_draws_both_figures_and_never_a_zero_bar(self):
        rows = full_rows()
        rows[1] = row("chess", "75%", "bitset", delta="")  # delta not measurable, peak still known
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "memory_real_fake"
            path.mkdir()
            make_run(path, rows)
            drawn = []
            with mock.patch.object(figures, "ROOT", Path(directory)), \
                    mock.patch.object(figures.plt, "close", side_effect=drawn.append):
                figures.plot(path)
            for name in ("vertical_structure", "peak_rss"):
                self.assertTrue((Path(directory) / "results/figures/memory_real_fake" / f"{name}.png").is_file())
            self.assertEqual(len(drawn), 2)
            for figure in drawn:
                heights = [bar.get_height() for bar in figure.axes[0].patches]
                self.assertEqual(len(heights), 4)
                self.assertTrue(all(height > 0 for height in heights))
            figures.plt.close("all")

    def test_labels_follow_the_report_glossary(self):
        self.assertEqual(figures.MINER_LABELS, {"baseline": "Bản cơ bản (TID-list)", "bitset": "Bản bitset"})
        self.assertEqual(figures.vi_number(1264032.0), "1.264.032")
        self.assertEqual(figures.vi_number(254.6), "254,6")


if __name__ == "__main__":
    unittest.main()
