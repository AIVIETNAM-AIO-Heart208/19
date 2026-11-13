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

- src/: module, thuật toán, I/O và ứng dụng.
- scripts/: điểm vào CLI.
- test/: kiểm thử và kết quả SPMF tham chiếu.
- experiments/: cấu hình và chương trình thực nghiệm.
- data/: thông tin nguồn và dữ liệu cục bộ.
- notebooks/demo.ipynb: khung demo Colab.
- results/: số liệu và biểu đồ đã chọn cho báo cáo.
- docs/: đề bài, checklist, ghi chú và nguồn báo cáo.

## Thông tin cần bổ sung

- Thành viên và mã nhóm.
- Bài báo gốc Eclat và ít nhất ba tài liệu liên quan.
- Hướng dẫn CLI và ví dụ sau khi triển khai.
- Link Colab công khai, nguồn dữ liệu và checksum.
- Lệnh kiểm thử: julia --project=. test/runtests.jl (sau khi triển khai tests).
- Output của lần chạy kiểm thử cuối.

## Hướng ứng dụng dự kiến

Market Basket Analysis và dữ liệu sinh học; nhóm có thể đổi sang hướng khác được đề cho phép.

