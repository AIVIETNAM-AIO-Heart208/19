# Eclat Mining

Đồ án Khai thác tập phổ biến — cài đặt Eclat từ bài báo gốc, đối chiếu SPMF, đánh giá hiệu năng và thực hiện hai ứng dụng.

## Trạng thái

Repository hiện có khung dự án Julia; thuật toán, kiểm thử và thực nghiệm chưa được triển khai.

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
Hiện `src/algorithm/stub.jl` là stub brute-force tạm (có cảnh báo STUB khi chạy); xóa nó khi Eclat thật đã có trong `baseline.jl`/`optimized.jl`.
Dữ liệu benchmark thật cần đi qua `EclatMining.clean_spmf(in, out)` trước khi đưa cho SPMF và cho CLI.

## Chạy test

```bash
julia --project test/runtests.jl
```

`test/runtests.jl` chạy `test_io.jl` (parser, writer, minsup, `clean_spmf`) và `test_correctness.jl` (toy 15 itemset, edge case, khớp output thật của SPMF trên `test/fixtures/`). Đề ghi thư mục `tests/`, repo dùng `test/` cho khớp lệnh chạy trong đề.

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
- Hướng dẫn CLI và ví dụ sau khi triển khai.
- Link Colab công khai, nguồn dữ liệu và checksum.
- Lệnh kiểm thử: julia --project=. test/runtests.jl (sau khi triển khai tests).
- Output của lần chạy kiểm thử cuối.

## Hướng ứng dụng dự kiến

Market Basket Analysis và dữ liệu sinh học; nhóm có thể đổi sang hướng khác được đề cho phép.

