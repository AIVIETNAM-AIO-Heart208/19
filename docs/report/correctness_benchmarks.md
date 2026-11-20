# Kiểm tra tính đúng đắn của Eclat trên năm bộ dữ liệu

## Phương pháp

- **Nguồn số liệu:** lần chạy runtime `runtime_20261117T101543270`
  ([summary.csv](../../results/metrics/benchmark_runs/runtime_20261117T101543270/summary.csv),
  [môi trường](../../results/metrics/benchmark_runs/runtime_20261117T101543270/environment.toml)).
  Bảng kết quả sử dụng phép đối chiếu thực hiện trong cùng lần đo thời gian.
- **So sánh:** với mỗi bộ dữ liệu và mức minsup, chương trình đọc kết quả của Eclat BitVector
  và của Eclat trong SPMF 2.65, sắp xếp các item trong từng itemset rồi đối chiếu toàn bộ
  các cặp (itemset, support). Thứ tự dòng trong tệp kết quả không ảnh hưởng đến phép so sánh.
- **Ngưỡng tuyệt đối:** `ceil(minsup × |DB|)` tính bằng số hữu tỉ. SPMF đọc phần trăm bằng số thực
  nên có thể làm tròn khác ở biên. Trước khi đo, hàm `levels` so sánh hai cách tính
  tại từng mức minsup. Nếu bất kỳ ngưỡng nào khác nhau, chương trình báo lỗi và dừng
  cả lần chạy. [Mã kiểm tra ngưỡng](../../experiments/dataset_benchmarks.jl).
- **Nguồn đối chiếu:** `summary.csv` do `experiments/run_benchmarks.jl` tạo ra. Cấu hình nào lệch
  SPMF thì bị loại, không được ghi vào CSV. Trước khi lập bảng, `run_correctness.jl`
  kiểm tra trạng thái hoàn tất và SHA-256 của CSV theo `environment.toml`, rồi kiểm tra
  có đủ dòng cho cả hai miner ở từng cấu hình dự kiến.
- **Dữ liệu:** tải từ FIMI, cố định bằng SHA-256 trong [data/datasets.toml](../../data/datasets.toml).
  Số giao dịch / số item: Chess 3.196 / 75 · Mushroom 8.124 / 119 · Retail 88.162 / 16.470 ·
  Accidents 340.183 / 468 · T10I4D100K 100.000 / 870.
- **Phạm vi kiểm thử:** cột `julia` trong lần chạy này là bản **bitset**. Bản baseline (TID-list)
  được kiểm riêng trên 27 trường hợp kiểm thử nhỏ trong `test/test_correctness.jl`, chưa nằm trong bảng này.
- **Tỉ lệ khớp:** ký hiệu `n/n (100%)` cho biết cả hai chương trình tìm được cùng
  `n` itemset và giá trị support trùng nhau ở từng itemset.

## Kết quả

Bảng sinh bằng:

```
julia --project=. experiments/run_correctness.jl results/metrics/benchmark_runs/runtime_20261117T101543270/summary.csv correctness_table.md
```

| Dataset | minsup | Ngưỡng tuyệt đối | Itemset Julia | Itemset SPMF | Tỉ lệ khớp itemset + support |
|---|---:|---:|---:|---:|---|
| chess | 90% | 2877 | 622 | 622 | 622/622 (100%) |
| chess | 85% | 2717 | 2669 | 2669 | 2669/2669 (100%) |
| chess | 80% | 2557 | 8227 | 8227 | 8227/8227 (100%) |
| chess | 75% | 2397 | 20993 | 20993 | 20993/20993 (100%) |
| chess | 70% | 2238 | 48731 | 48731 | 48731/48731 (100%) |
| chess | 65% | 2078 | 111239 | 111239 | 111239/111239 (100%) |
| chess | 60% | 1918 | 254944 | 254944 | 254944/254944 (100%) |
| mushroom | 60% | 4875 | 51 | 51 | 51/51 (100%) |
| mushroom | 50% | 4062 | 153 | 153 | 153/153 (100%) |
| mushroom | 40% | 3250 | 565 | 565 | 565/565 (100%) |
| mushroom | 30% | 2438 | 2735 | 2735 | 2735/2735 (100%) |
| mushroom | 25% | 2031 | 5545 | 5545 | 5545/5545 (100%) |
| mushroom | 20% | 1625 | 53583 | 53583 | 53583/53583 (100%) |
| mushroom | 15% | 1219 | 98575 | 98575 | 98575/98575 (100%) |
| retail | 2% | 1764 | 55 | 55 | 55/55 (100%) |
| retail | 1.5% | 1323 | 84 | 84 | 84/84 (100%) |
| retail | 1% | 882 | 159 | 159 | 159/159 (100%) |
| retail | 0.75% | 662 | 277 | 277 | 277/277 (100%) |
| retail | 0.5% | 441 | 580 | 580 | 580/580 (100%) |
| retail | 0.25% | 221 | 1882 | 1882 | 1882/1882 (100%) |
| retail | 0.1% | 89 | 7589 | 7589 | 7589/7589 (100%) |
| accidents | 95% | 323174 | 15 | 15 | 15/15 (100%) |
| accidents | 90% | 306165 | 31 | 31 | 31/31 (100%) |
| accidents | 85% | 289156 | 71 | 71 | 71/71 (100%) |
| accidents | 80% | 272147 | 149 | 149 | 149/149 (100%) |
| accidents | 75% | 255138 | 313 | 313 | 313/313 (100%) |
| accidents | 70% | 238129 | 529 | 529 | 529/529 (100%) |
| accidents | 65% | 221119 | 1093 | 1093 | 1093/1093 (100%) |
| t10i4d100k | 2% | 2000 | 155 | 155 | 155/155 (100%) |
| t10i4d100k | 1.5% | 1500 | 237 | 237 | 237/237 (100%) |
| t10i4d100k | 1% | 1000 | 385 | 385 | 385/385 (100%) |
| t10i4d100k | 0.75% | 750 | 561 | 561 | 561/561 (100%) |
| t10i4d100k | 0.5% | 500 | 1073 | 1073 | 1073/1073 (100%) |
| t10i4d100k | 0.25% | 250 | 7703 | 7703 | 7703/7703 (100%) |
| t10i4d100k | 0.1% | 100 | 27532 | 27532 | 27532/27532 (100%) |

Tổng: **35/35** cấu hình khớp hoàn toàn với SPMF.

**Khả năng tái lập.** Kết quả gắn với commit `391ce1a` và các thay đổi cục bộ tại thời
điểm đo (`dirty = true`). File `environment.toml` lưu checksum để đối chiếu mã nguồn,
cấu hình và các bảng số liệu của lần chạy.
