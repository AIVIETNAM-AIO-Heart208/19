# Eclat Mining

Đồ án Khai thác tập phổ biến triển khai Eclat bằng Julia, đối chiếu kết quả với SPMF và đánh giá hiệu năng trên dữ liệu tổng hợp và dữ liệu thực.

## Thông tin nhóm

**Mã nhóm**: 19

| Họ tên | MSSV |
|---|---|
| Nguyễn Văn Minh | 24127205 |
| Lưu Minh Quân | 24127223 |

## Demo trên Google Colab

[Mở demo trên Google Colab](https://colab.research.google.com/github/AIVIETNAM-AIO-Heart208/19/blob/main/notebooks/demo.ipynb)

Kết nối runtime và chọn **Runtime → Run all**. Notebook khởi tạo môi trường Julia, chạy lần lượt hai ứng dụng bằng Eclat của nhóm rồi chuẩn bị năm bộ dữ liệu benchmark trong `data/processed/`.

- **Phân tích giỏ hàng** hiển thị 10 luật có lift cao nhất tại minsup 1% và minconf 50%. Có thể đối chiếu với [bảng kết quả tham chiếu](results/metrics/online_retail_rules.md). [Nguồn UCI Online Retail](https://archive.ics.uci.edu/dataset/352/online+retail) · [Báo cáo ứng dụng](docs/report/market_basket.md)
- **Phân tích mẫu DNA quanh vị trí cắt nối gen** tự kiểm tra cả 8 bảng CSV với bản đã lưu, xác nhận SHA-256 của dữ liệu dùng để vẽ hai biểu đồ và hiển thị hai hình đã lưu. [Nguồn UCI Splice-junction](https://doi.org/10.24432/C5M888) · [Phân tích kết quả](docs/splice_notes.md)

## Trạng thái

Hàm `eclat` mặc định gọi bản bitset dùng `BitVector`. Cả baseline TID-list và bitset đều khớp với SPMF trong 27 ca kiểm thử nhỏ. Trên năm bộ dữ liệu benchmark, bản bitset khớp với SPMF về itemset và support ở cả 35 cấu hình. Phép đo runtime thu 350 mẫu trên 7 mức minsup mỗi bộ. [Kết quả và phân tích](docs/report/runtime_benchmarks.md)

## Môi trường

Julia >= 1.9. Tại thư mục gốc, khởi tạo môi trường bằng:

```powershell
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

Với Julia 1.11.4, lệnh trên cài các phiên bản gói ghi trong `Manifest-v1.11.toml`. Ứng dụng [phân tích giỏ hàng](docs/report/market_basket.md) dùng XLSX.jl để đọc trực tiếp dữ liệu UCI Online Retail.

## Cấu trúc

- src/: module, thuật toán, I/O (`io.jl`) và ứng dụng.
- scripts/: điểm vào CLI.
- test/: kiểm thử và kết quả SPMF tham chiếu.
- experiments/: cấu hình và chương trình thực nghiệm.
- data/: thông tin nguồn và dữ liệu cục bộ.
- notebooks/demo.ipynb: demo Colab cho cả hai ứng dụng.
- results/: số liệu và biểu đồ đã chọn cho báo cáo.
- docs/: đề bài, checklist, ghi chú và nguồn báo cáo.

## Cách chạy CLI

- `--input`: file giao dịch định dạng SPMF (mỗi dòng một giao dịch, item nguyên cách nhau dấu cách; bỏ dòng trống và dòng bắt đầu `@`, `#`, `%`; dòng chỉ có khoảng trắng là một giao dịch rỗng).
- `--output`: mỗi dòng `i1 i2 ... #SUP: n` (support tuyệt đối).
- `--minsup`: tỉ lệ `0.4` hoặc phần trăm `40%`, quy đổi bằng `ceil(minsup × số giao dịch)` như SPMF.

Ví dụ:

```bash
julia --project scripts/run_eclat.jl --input test/fixtures/transactions/toy.txt --output out.txt --minsup 40%
julia --project experiments/spmf/compare.jl out.txt test/fixtures/spmf_expected/toy_40.txt
```

Lệnh thứ hai so khớp dạng tập `{(itemset, support)}` và thoát với mã 0 khi khớp 100%.
CLI dùng bản bitset. Có thể gọi `eclat_baseline` từ Julia để chạy bản TID-list. [Giao diện và thuật toán](docs/algorithm_notes.md)
Dữ liệu benchmark thật cần đi qua `EclatMining.clean_spmf(in, out)` trước khi đưa cho SPMF và cho CLI.

## Chạy test

```bash
julia --project=. test/runtests.jl
```

`test/runtests.jl` kiểm tra I/O và CLI, đối chiếu hai bản Eclat với SPMF, kiểm tra quy trình benchmark và kiểm thử hai ứng dụng.

Để kiểm tra các script vẽ biểu đồ, chạy trong môi trường Python của dự án.

```bash
python -m pip install -r experiments/requirements-figures.txt
python -m unittest discover -s test -p "test_*figures.py"
```

Kết quả ngày 25/11/2026 trên Windows với Julia 1.11.4 và Python 3.11.9.

```text
Test Summary: | Pass  Broken  Total     Time
EclatMining   | 4069       1   4070  1m30.9s
```

Mục `Broken` là ca kiểm thử CLI được bỏ qua bằng `@test_skip` khi Windows không cho tạo symlink.

```text
Ran 23 tests in 1.130s

OK
```

## So sánh hiệu năng

Scalability và ảnh hưởng độ dài giao dịch: [hướng dẫn](experiments/SIZE_EXPERIMENTS.md).

Benchmark trên năm bộ dữ liệu giao dịch chuẩn, trong đó T10I4D100K là bộ tổng hợp. [Hướng dẫn đo runtime](experiments/BENCHMARKS.md)
Luồng này dùng `experiments/run_benchmarks.jl`, độc lập với phép đo tối ưu bên dưới.

```powershell
julia --startup-file=no --threads=1 --project=. experiments/run_runtime.jl
julia --startup-file=no --threads=1 --project=. experiments/run_memory.jl
julia --startup-file=no --threads=1 --project=. experiments/summarize_optimization.jl
```

Cấu hình đo dùng dữ liệu tổng hợp với seed 42. Các file `results/metrics/optimization_*.csv` ghi số liệu và hai file `optimization_*_environment.toml` trong cùng thư mục ghi môi trường đo. Chạy lại sẽ ghi đè các kết quả này. Runtime được tóm tắt bằng median và IQR của 7 lần đo sau warm-up. Peak RAM là median của 3 tiến trình mới cho mỗi cấu hình và thuật toán. [Cấu hình](experiments/configs/optimization.toml) · [Bảng số liệu và phân tích](docs/algorithm_notes.md#kết-quả-đo-thực-tế)

Trên dữ liệu tổng hợp dày, bitset chạy nhanh hơn baseline 31,4–31,6 lần và cấp phát ít bộ nhớ hơn. Trên dữ liệu tổng hợp thưa, bitset chạy nhanh hơn 1,7–2,6 lần nhưng cấp phát nhiều bộ nhớ hơn. Peak RAM của bitset cao hơn ở một trong hai cấu hình thưa.

## Chạy SPMF tham chiếu

Cần **JDK 25 trở lên** và `spmf.jar` (tải tại https://www.philippe-fournier-viger.com/spmf/, đặt vào `tools/spmf.jar`, không commit). Sinh lại toàn bộ output tham chiếu:

```bash
julia --project experiments/spmf/run_reference.jl
```

Chi tiết (phiên bản, checksum, hành vi SPMF với input bẩn) ở `experiments/spmf/README.md` và `test/fixtures/README.md`.

## Khác với cấu trúc gợi ý của đề

Đề gợi ý `tests/`, `src/utils.jl`, `src/structures.jl`, `data/toy/`; repo theo khung của nhóm: `test/` (fixtures nhỏ ở `test/fixtures/transactions/` thay cho `data/toy/`, output SPMF ở `test/fixtures/spmf_expected/`), I/O và so khớp kết quả ở `src/io.jl`, CLI ở `scripts/run_eclat.jl`, script đối chiếu SPMF ở `experiments/spmf/`.

## Báo cáo

Báo cáo IEEE trình bày hai phiên bản Eclat, kết quả thực nghiệm và hai ứng dụng. [Đọc báo cáo PDF](docs/Report.pdf) · [Chương cài đặt](docs/report/chapter1.md) · [Nguồn báo cáo và hướng dẫn biên dịch](docs/report/README.md)

## Chuẩn bị benchmark

Từ thư mục gốc, chạy lệnh sau để tải, kiểm tra SHA-256 và chuẩn hóa Chess, Mushroom, Retail, Accidents và T10I4D100K.

```bash
julia --project=. scripts/prepare_benchmarks.jl
```

Dùng các file `data/processed/*.txt` làm đầu vào chung cho baseline, bitset và SPMF. [Nguồn FIMI](https://fimi.uantwerpen.be/data/) · [Hướng dẫn và bản lưu Kaggle đã xác minh](data/README.md#nguồn-và-điều-kiện-sử-dụng) · [Manifest và SHA-256](data/datasets.toml)

| Bộ dữ liệu | Liên kết tải |
|---|---|
| Chess và Accidents | [Kaggle, bản 1](https://www.kaggle.com/datasets/mominazahidd/accidents-dat) |
| Mushroom | [Kaggle, bản 1](https://www.kaggle.com/datasets/subhamila/mushroom) |
| Retail | [FIMI, retail.dat](https://fimi.uantwerpen.be/data/retail.dat) |
| T10I4D100K | [FIMI, T10I4D100K.dat](https://fimi.uantwerpen.be/data/T10I4D100K.dat) |
