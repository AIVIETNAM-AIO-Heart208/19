# Eclat Mining

Đồ án Khai thác tập phổ biến — cài đặt Eclat từ bài báo gốc, đối chiếu SPMF, đánh giá hiệu năng và thực hiện hai ứng dụng.

## Trạng thái

Đã có baseline TID-list và optimized BitVector; `eclat` mặc định gọi bitset. Cả hai khớp 27/27 case SPMF. Kiểm thử Julia 1.11.4: 3842 pass, 0 fail/error, 1 skip do quyền tạo symlink Windows. Đã có số liệu tối ưu trên dữ liệu tổng hợp và benchmark runtime trên cả 5 CSDL thật: 7 mức minsup mỗi bộ, 350 mẫu chính thức, 35/35 cấu hình khớp itemset/support với SPMF. Xem [kết quả và phân tích](docs/report/runtime_benchmarks.md).

## Môi trường

Julia >= 1.9. Tại thư mục gốc, khởi tạo môi trường bằng:

```powershell
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

Julia sẽ sinh Manifest.toml khi thiết lập môi trường; commit file này để cố định dependencies.

## Cấu trúc

- src/: module, thuật toán, I/O (`io.jl`) và ứng dụng.
- scripts/: điểm vào CLI.
- test/: kiểm thử và kết quả SPMF tham chiếu.
- experiments/: cấu hình và chương trình thực nghiệm.
- data/: thông tin nguồn và dữ liệu cục bộ.
- notebooks/demo.ipynb: khung demo Colab.
- results/: số liệu và biểu đồ đã chọn cho báo cáo.
- docs/: đề bài, checklist, ghi chú và nguồn báo cáo.

## Cách chạy CLI

```bash
julia --project scripts/run_eclat.jl --input <file> --output <file> --minsup <0.4 | 40%>
```

- `--input`: file giao dịch định dạng SPMF (mỗi dòng một giao dịch, item nguyên cách nhau dấu cách; bỏ dòng trống và dòng bắt đầu `@`, `#`, `%`; dòng chỉ có khoảng trắng là một giao dịch rỗng).
- `--output`: mỗi dòng `i1 i2 ... #SUP: n` (support tuyệt đối).
- `--minsup`: tỉ lệ `0.4` hoặc phần trăm `40%`, quy đổi bằng `ceil(minsup × số giao dịch)` như SPMF.

Ví dụ:

```bash
julia --project scripts/run_eclat.jl --input test/fixtures/transactions/toy.txt --output out.txt --minsup 40%
julia --project experiments/spmf/compare.jl out.txt test/fixtures/spmf_expected/toy_40.txt
```

Lệnh thứ hai so khớp dạng tập `{(itemset, support)}` và thoát với mã 0 khi khớp 100%.
CLI chạy bitset thật; baseline vẫn gọi riêng được. API và phân tích: [ghi chú thuật toán](docs/algorithm_notes.md).
Dữ liệu benchmark thật cần đi qua `EclatMining.clean_spmf(in, out)` trước khi đưa cho SPMF và cho CLI.

## Chạy test

```bash
julia --project test/runtests.jl
```

`test/runtests.jl` chạy `test_io.jl` (parser, writer, minsup, `clean_spmf`) và `test_correctness.jl` (toy 15 itemset, edge case, khớp output thật của SPMF trên `test/fixtures/`). Đề ghi thư mục `tests/`, repo dùng `test/` cho khớp lệnh chạy trong đề.

Kết quả kiểm tra hai implementation ngày 17/11/2026 (Windows, Julia 1.11.4):

```text
Khớp SPMF: 27/27 case, 7 CSDL, tổng 552 itemset tham chiếu (mỗi bản)
Test Summary: | Pass  Broken  Total
EclatMining   | 3842       1   3843
```

Một Broken là @test_skip do Windows thiếu quyền tạo symlink. Không skip bitset/baseline. CLI toy @40% khớp 100%; module không có cảnh báo ghi đè hoặc method ambiguity.

## So sánh hiệu năng

Benchmark trên năm bộ dữ liệu thật: xem [hướng dẫn runtime](experiments/BENCHMARKS.md).
Luồng này dùng `experiments/run_benchmarks.jl`, độc lập với phép đo tối ưu bên dưới.

```powershell
julia --startup-file=no --threads=1 --project=. experiments/run_runtime.jl
julia --startup-file=no --threads=1 --project=. experiments/run_memory.jl
julia --startup-file=no --threads=1 --project=. experiments/summarize_optimization.jl
```

Cấu hình: `experiments/configs/optimization.toml`; dữ liệu tổng hợp seed 42. Số liệu ở `results/metrics/optimization_*.csv`, môi trường trong `optimization_runtime_environment.toml và optimization_memory_environment.toml`. Chạy lại sẽ ghi đè các kết quả này. Runtime median/IQR sau warm-up (7 lần), peak RAM median của 3 tiến trình mới mỗi case/miner; allocated bytes và peak RAM được ghi riêng. Bảng và phân tích: [algorithm_notes.md](docs/algorithm_notes.md#kết-quả-đo-thực-tế).

Dense: bitset nhanh hơn 31.4–31.6x và cấp phát ít hơn. Sparse: 1.7–2.6x nhanh hơn nhưng cấp phát và peak RAM cao hơn. Đây chưa phải kết quả benchmark thật Chương 2.

## Chạy SPMF tham chiếu

Cần **JDK 25 trở lên** và `spmf.jar` (tải tại https://www.philippe-fournier-viger.com/spmf/, đặt vào `tools/spmf.jar`, không commit). Sinh lại toàn bộ output tham chiếu:

```bash
julia --project experiments/spmf/run_reference.jl
```

Chi tiết (phiên bản, checksum, hành vi SPMF với input bẩn) ở `experiments/spmf/README.md` và `test/fixtures/README.md`.

## Khác với cấu trúc gợi ý của đề

Đề gợi ý `tests/`, `src/utils.jl`, `src/structures.jl`, `data/toy/`; repo theo khung của nhóm: `test/` (fixtures nhỏ ở `test/fixtures/transactions/` thay cho `data/toy/`, output SPMF ở `test/fixtures/spmf_expected/`), I/O và so khớp kết quả ở `src/io.jl`, CLI ở `scripts/run_eclat.jl`, script đối chiếu SPMF ở `experiments/spmf/`.

## Thông tin cần bổ sung

- Thành viên và mã nhóm.
- Bài báo gốc Eclat và ít nhất ba tài liệu liên quan.
- Link Colab công khai, nguồn dữ liệu và checksum.
- Lệnh kiểm thử: julia --project test/runtests.jl (cả baseline và bitset thật).

## Hướng ứng dụng dự kiến

Market Basket Analysis và dữ liệu sinh học; nhóm có thể đổi sang hướng khác được đề cho phép.


## Nội dung Chương 1

Bản viết chung: [docs/report/chapter1.md](docs/report/chapter1.md). Phần cài đặt có baseline, bitset, I/O/CLI, kiểm thử và đo tối ưu. `clean_spmf` và CLI dùng chung kiểm tra file nguồn/đích, bao gồm alias hoa/thường và hard link. Báo cáo IEEE tổng hợp sẽ ghép nội dung này cùng Chương 2–3.

## Chuẩn bị benchmark

Đã chuẩn bị Chess, Mushroom, Retail, Accidents và T10I4D100K từ FIMI.
Tải lại/kiểm tra/chuẩn hóa: `julia --project=. scripts/prepare_benchmarks.jl`.
Dùng file data/processed/*.txt cho mọi miner; raw và processed được giữ ngoài Git.
Nguồn, checksum và thống kê: [data/README.md](data/README.md), [data/datasets.toml](data/datasets.toml).
