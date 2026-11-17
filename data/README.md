# Dữ liệu benchmark

Năm bộ transaction được tải từ [FIMI Dataset Repository, Đại học Antwerp](https://fimi.uantwerpen.be/data/).
Mỗi phiên bản được cố định bằng SHA-256 trong [datasets.toml](datasets.toml).
Các file raw/processed lớn nằm trên máy, được .gitignore loại khỏi commit.

| Dataset | Giao dịch | Item phân biệt | Độ dài trung bình | File dùng để mining |
|---|---:|---:|---:|---|
| Chess | 3,196 | 75 | 37.0000 | `data/processed/chess.txt` |
| Mushroom | 8,124 | 119 | 23.0000 | `data/processed/mushroom.txt` |
| Retail | 88,162 | 16,470 | 10.3058 | `data/processed/retail.txt` |
| Accidents | 340,183 | 468 | 33.8079 | `data/processed/accidents.txt` |
| T10I4D100K | 100,000 | 870 | 10.1023 | `data/processed/t10i4d100k.txt` |

## Tải và chuẩn hóa tái lập

Chạy từ repo root, cần Julia >=1.9:

```powershell
julia --project=. scripts/prepare_benchmarks.jl
```

Chỉ chuẩn bị một số bộ:

```powershell
julia --project=. scripts/prepare_benchmarks.jl chess mushroom
```

Script tải raw còn thiếu theo URL trong manifest, kiểm tra checksum trước khi
đưa vào raw/, rồi gọi EclatMining.clean_spmf để tạo processed/. File raw đã có
nhưng sai checksum bị từ chối và giữ nguyên. Output chỉ được thay khi chuẩn hóa
xong, đủ số giao dịch và khớp checksum dự kiến. File đã đúng checksum được tái sử
dụng. Cuối cùng script kiểm tra thống kê theo dòng, không giữ nhiều bản CSDL lớn
trong RAM. Script có thể gọi từ notebook Colab bằng lệnh shell Julia tương tự.

## Quy tắc sử dụng

- raw/: byte gốc FIMI (.dat), không sửa, không commit.
- processed/: transaction .txt đã chuẩn hóa, là input chung của baseline, bitset và SPMF.
- datasets.toml: URL, đường dẫn, SHA-256 hai bản, kích thước và thống kê thực đo.
- ../results/metrics/dataset_statistics.csv: bảng thống kê đã kiểm tra.
- CSDL nhỏ/unit tests riêng tại test/fixtures/transactions/.

Tất cả file gốc của snapshot này đã sort và không trùng item trong một dòng,
nhưng có dấu cách cuối dòng. Chuẩn hóa bỏ dấu cách cuối, dùng một dấu cách giữa
các item và newline LF. Không lọc item hiếm, lấy mẫu hoặc xóa giao dịch trùng.
Số giao dịch và tập item không đổi. Retail có item 0, được giữ nguyên.

Mushroom FIMI này có 8124 giao dịch, không dùng con số 8416 đang ghi trong bảng
SPMF để thay đổi dữ liệu. Retail có 16470 item phân biệt; T10I4D100K có 870 item
phân biệt, không đồng nhất số item với max(item ID). Báo cáo dùng số liệu thực
đo và checksum của manifest.

## Nguồn và điều kiện sử dụng

Đã ưu tiên tra cứu mirror HF/Kaggle nhưng chưa xác minh được bản transaction
đúng của toàn bộ bộ dữ liệu; dùng nguồn FIMI gốc mà đề cho phép. Trước khi nộp,
cần bổ sung link lưu trữ dài hạn HF/Kaggle phù hợp chính sách dữ liệu của đề;
hiện chưa tự đăng hoặc công bố lại các file lớn.

Catalog FIMI ghi yêu cầu acknowledgement cho Retail và Accidents; xem điều kiện
và nguồn gốc tại trang catalog. Không gán giấy phép SPDX cho các file không có
giấy phép rõ trong catalog. Trường license trong manifest ghi đúng trạng thái
nguồn, không suy ra quyền phân phối từ việc tải được công khai.
