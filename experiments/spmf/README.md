# Tham chiếu SPMF

- Nguồn tải: https://www.philippe-fournier-viger.com/spmf/ (file `spmf.jar`). File .jar không được commit; đặt ở `tools/spmf.jar`.
- Phiên bản đã dùng: SPMF v2.65, thuật toán `Eclat`. SHA-256 của file đã dùng:
  `2cc2d89e39909230ea0455da4a1c79b389dc98ca04b0670befb63e679b5e2ea0` (14 960 635 byte).
- Java: cần **JDK 25 trở lên** (JDK 17 báo `UnsupportedClassVersionError`, class version 69). Đã chạy với OpenJDK 25.0.5.
- Lệnh chạy một case: `java -jar tools/spmf.jar run Eclat <input> <output> <minsup>%`.
- Ngưỡng tuyệt đối SPMF dùng là `ceil(minsup × |DB|)`.

## Các script

| File | Việc |
|---|---|
| `run_reference.jl` | Chạy SPMF trên mọi CSDL ở `test/fixtures/transactions/`, ghi `test/fixtures/spmf_expected/` và `test/fixtures/cases.toml`. |
| `compare.jl` | So khớp hai file kết quả dạng tập `{(itemset đã sort, support)}`; exit code 0 khi khớp 100%. |

```bash
julia --project experiments/spmf/run_reference.jl            # sinh lại toàn bộ expected
julia --project experiments/spmf/run_reference.jl path/to/spmf.jar
julia --project experiments/spmf/compare.jl ours.txt spmf.txt
```

Biến môi trường `SPMF_JAR` cũng được dùng để chỉ đường dẫn jar. Cả hai script chỉ gọi `java` qua `run`
nên chạy được trên Windows, Linux và Colab.

Quan sát hộp đen về input SPMF đọc được/không đọc được: xem `test/fixtures/README.md`.
Với dữ liệu benchmark thật, chạy `clean_spmf` trước rồi cho cả SPMF và code nhóm đọc file đã làm sạch.
