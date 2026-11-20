"""Small integrity checks for plotting; no Java or benchmark data required."""
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("figures", ROOT / "experiments/plot_benchmarks.py")
figures = importlib.util.module_from_spec(spec)
spec.loader.exec_module(figures)


class FigureIntegrityTests(unittest.TestCase):
    def test_crlf_summary_with_lf_checksum(self):
        summary = (b"dataset,minsup,miner,itemsets,validation,repeats\n"
                   b"toy,50%,julia,622,exact_match,1\n"
                   b"toy,50%,spmf,622,exact_match,1\n")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "environment.toml").write_text(
                'complete = true\npilot = true\n[config.minsup]\ntoy = ["50%"]\n'
                f'[artifacts]\n"summary.csv" = "{hashlib.sha256(summary).hexdigest()}"\n',
                encoding="utf-8")
            csv = path / "summary.csv"
            csv.write_bytes(summary.replace(b"\n", b"\r\n"))
            self.assertEqual(len(figures.read_run(path)), 2)
            csv.write_bytes(csv.read_bytes().replace(b"622", b"623"))
            with self.assertRaisesRegex(ValueError, "Modified artifact"):
                figures.read_run(path)

    def test_incomplete_run(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "environment.toml").write_text("complete = false\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "incomplete"):
                figures.read_run(path)

    def test_modified_csv(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "summary.csv").write_text("modified", encoding="utf-8")
            (path / "environment.toml").write_text(
                'complete = true\n[artifacts]\n"summary.csv" = "wrong hash"\n', encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "Modified artifact"):
                figures.read_run(path)


if __name__ == "__main__":
    unittest.main()
