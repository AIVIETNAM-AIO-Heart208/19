# Correctness trên bộ benchmark: Eclat của nhóm so với SPMF

## Phương pháp

- **Nguồn số liệu:** lần chạy runtime `runtime_20261117T101543270` do trưởng nhóm thực hiện
  ([summary.csv](../../results/metrics/benchmark_runs/runtime_20261117T101543270/summary.csv),
  [môi trường](../../results/metrics/benchmark_runs/runtime_20261117T101543270/environment.toml)).
  Bảng dưới chỉ trình bày lại kết quả đối chiếu đã có trong lần chạy đó, không chạy lại thuật toán.
- **So sánh:** với mỗi cặp (dataset, minsup), output của Eclat nhóm và của SPMF (ECLAT v2.65)
  được đọc lại, mỗi itemset được sort và so theo cặp (itemset, support). Hai tập phải bằng nhau
  hoàn toàn, nên không chỉ trùng số lượng. Thứ tự dòng trong file không ảnh hưởng.
- **Ngưỡng tuyệt đối:** `ceil(minsup × |DB|)` tính bằng số hữu tỉ. SPMF đọc phần trăm bằng số thực
  nên có thể làm tròn khác ở biên; hàm `levels` trong
  [experiments/dataset_benchmarks.jl](../../experiments/dataset_benchmarks.jl) loại bỏ mọi mức
  minsup mà hai cách tính cho ngưỡng khác nhau, nên cả hai miner dùng cùng một ngưỡng.
- **Nguồn đối chiếu:** `summary.csv` do `experiments/run_benchmarks.jl` tạo ra. Cấu hình nào lệch
  SPMF thì bị loại, không được ghi vào CSV. Vì vậy script `run_correctness.jl` còn đối chiếu
  danh sách cấu hình dự định trong `environment.toml`: thiếu dòng nào thì báo lỗi.
- **Dữ liệu:** tải từ FIMI, cố định bằng SHA-256 trong [data/datasets.toml](../../data/datasets.toml).
  Số giao dịch / số item: Chess 3.196 / 75 · Mushroom 8.124 / 119 · Retail 88.162 / 16.470 ·
  Accidents 340.183 / 468 · T10I4D100K 100.000 / 870.
- **Miner được kiểm:** cột `julia` trong lần chạy này là bản **bitset**. Bản baseline (TID-list)
  được kiểm riêng trên 27 case nhỏ trong `test/test_correctness.jl`, chưa nằm trong bảng này.
- **Tỉ lệ khớp:** hai tập kết quả được so nguyên tập (khớp hết hoặc không), không đếm từng
  itemset. Một cấu hình có mặt trong CSV nghĩa là hai tập bằng nhau, nên ghi "n/n (100%)" với n
  là số itemset; cấu hình lệch không có trong CSV và bị script báo là thiếu.

## Kết quả

Bảng sinh bằng:

```
julia --project experiments/run_correctness.jl results/metrics/benchmark_runs/runtime_20261117T101543270/summary.csv <output.md>
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

## Sai lệch

Không có. Cả 35 cấu hình (5 dataset × 7 mức minsup) khớp từng itemset và support với SPMF,
tỉ lệ khớp 100% ở mọi dòng, nên không có sai lệch nào cần giải thích.

Giới hạn cần nêu: lần chạy có `dirty = true` trong `environment.toml` (cây làm việc lúc đó có
thay đổi chưa commit), nên kết quả gắn với commit 391ce1a cộng thay đổi cục bộ.
