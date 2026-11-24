"""Checks for the splice-junction plots: input guards and drawing from the recorded run; no Julia, no mining."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("splice_figures", ROOT / "scripts/plot_splice_patterns.py")
figures = importlib.util.module_from_spec(spec)
spec.loader.exec_module(figures)


class SpliceFigureTests(unittest.TestCase):
    def test_digest_ignores_crlf(self):
        with tempfile.TemporaryDirectory() as directory:
            lf, crlf = Path(directory) / "lf.csv", Path(directory) / "crlf.csv"
            lf.write_bytes(b"a,b\n1,2\n")
            crlf.write_bytes(b"a,b\r\n1,2\r\n")
            self.assertEqual(figures.digest(lf), figures.digest(crlf))

    def test_rejects_run_from_dirty_checkout(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "run_info.toml").write_text("[environment]\ndirty = true\n", encoding="utf-8")
            with mock.patch.object(figures, "RUN", path), self.assertRaises(SystemExit):
                figures.read_run()

    def test_counts_need_every_class(self):
        info, counts, _ = figures.read_run()
        without_n = [r for r in counts if r["class"] != "N"]
        with self.assertRaises(SystemExit):
            figures.plot_counts(info, without_n)

    def test_counts_reject_missing_minsup(self):
        info, counts, _ = figures.read_run()
        target = ("nucleotide", "EI", info["mining"]["nucleotide"]["minsup_grid"][1])
        partial = [row for row in counts
                   if (row["encoding"], row["class"], row["minsup"]) != target]
        self.assertEqual(len(partial), len(counts) - 1)
        with self.assertRaisesRegex(SystemExit, f"thiếu nucleotide/EI/minsup={target[2]}"):
            figures.plot_counts(info, partial)

    def test_counts_reject_duplicate_even_with_correct_row_count(self):
        info, counts, _ = figures.read_run()
        repeated, missing = counts[:2]
        duplicate = f'{repeated["encoding"]}/{repeated["class"]}/minsup={repeated["minsup"]}'
        omitted = f'{missing["encoding"]}/{missing["class"]}/minsup={missing["minsup"]}'
        with self.assertRaisesRegex(SystemExit, f"thiếu {omitted}, trùng {duplicate}"):
            figures.plot_counts(info, [repeated, repeated, *counts[2:]])

    def test_counts_reject_out_of_grid_minsup(self):
        info, counts, _ = figures.read_run()
        extra = dict(counts[0], minsup="0.01%")
        key = f'{extra["encoding"]}/{extra["class"]}/minsup=0.01%'
        with self.assertRaisesRegex(SystemExit, f"ngoài cấu hình {key}"):
            figures.plot_counts(info, [*counts, extra])

    def test_draws_recorded_run(self):
        info, counts, patterns = figures.read_run()
        for fig in (figures.plot_counts(info, counts[::-1]), figures.plot_enrichment(info, patterns)):
            self.assertEqual(len(fig.axes), 2)
            figures.plt.close(fig)


if __name__ == "__main__":
    unittest.main()
