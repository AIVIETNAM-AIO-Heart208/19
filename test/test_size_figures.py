"""Integrity regressions for scalability/length plots; no mining required."""
import csv
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("size_figures", ROOT / "experiments/plot_size_benchmarks.py")
figures = importlib.util.module_from_spec(spec)
spec.loader.exec_module(figures)


def write_csv(path, rows):
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def fixture(directory, count=5):
    rows, raw = [], []
    for case_id in range(1, count+1):
        rows.append(dict(case_id=case_id, level=case_id, validation="exact_match",
                         scope="warmed_api", repeats=5, input_sha256=f"hash_{case_id}",
                         itemsets=10, median_seconds=3, q1_seconds=2, q3_seconds=4, iqr_seconds=2))
        raw.extend(dict(case_id=case_id, repeat=rep, seconds=rep, validation="exact_match",
                        scope="warmed_api", itemsets=10) for rep in range(1, 6))
    write_csv(directory/"summary.csv", rows)
    write_csv(directory/"raw.csv", raw)
    return rows, raw


def metadata(directory, count=5):
    text = 'complete = true\npilot = false\nkind = "transaction_length"\nnote = "kiểm tra"\n'
    text += '[config]\nrepeats = 5\nlengths = '+json.dumps(list(range(1,count+1)))+'\n'
    text += '[artifacts]\n'
    for name in ("raw.csv", "summary.csv"):
        digest = hashlib.sha256((directory/name).read_bytes().replace(b"\r\n", b"\n")).hexdigest()
        text += f'"{name}" = "{digest}"\n'
    for i in range(1,count+1):
        text += f'[[cases]]\ncase_id = {i}\nstatus = "exact_match"\nsha256 = "hash_{i}"\n'
    (directory/"environment.toml").write_text(text, encoding="utf-8")


class SizeFigureTests(unittest.TestCase):
    def test_dataset_titles(self):
        for dataset in ("retail", "accidents"):
            self.assertEqual(figures.plot_title({"kind":"scalability","config":{"dataset":dataset}}),
                             "Khả năng mở rộng trên "+dataset.capitalize())
        self.assertEqual(figures.plot_title({"kind":"transaction_length"}), "Độ dài giao dịch trên CSDL tổng hợp")

    def test_six_length_levels_and_unicode(self):
        with tempfile.TemporaryDirectory(prefix="thử nghiệm ") as directory:
            path = Path(directory)
            fixture(path,6); metadata(path,6)
            self.assertEqual(len(figures.read_run(path)[1]),6)

    def test_duplicate_case(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            rows, _ = fixture(path)
            rows[-1]["case_id"] = 1
            write_csv(path/"summary.csv",rows); metadata(path)
            with self.assertRaisesRegex(ValueError,"grid"):
                figures.read_run(path)

    def test_wrong_median(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            rows, _ = fixture(path)
            rows[0]["median_seconds"] = 8
            write_csv(path/"summary.csv",rows); metadata(path)
            with self.assertRaisesRegex(ValueError,"Summary disagrees"):
                figures.read_run(path)

    def test_duplicate_repeat(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            _, raw = fixture(path)
            raw[1]["repeat"] = 1
            write_csv(path/"raw.csv",raw); metadata(path)
            with self.assertRaisesRegex(ValueError,"duplicate repeats"):
                figures.read_run(path)

    def test_changed_csv(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            fixture(path); metadata(path)
            with (path/"raw.csv").open("a",encoding="utf-8") as stream:
                stream.write("tampered")
            with self.assertRaisesRegex(ValueError,"checksum mismatch"):
                figures.read_run(path)


if __name__ == "__main__":
    unittest.main()
