"""Small integrity checks for plotting; no Java or benchmark data required."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("figures", ROOT / "experiments/plot_benchmarks.py")
figures = importlib.util.module_from_spec(spec)
spec.loader.exec_module(figures)


class FigureIntegrityTests(unittest.TestCase):
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
