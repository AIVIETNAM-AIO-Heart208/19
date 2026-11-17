# Thực nghiệm runtime và kích thước kết quả

## Thiết kế thực nghiệm

Thực nghiệm dùng toàn bộ năm CSDL Chess, Mushroom, Retail, Accidents và
T10I4D100K. Input là các file processed có SHA-256 cố định trong
`data/datasets.toml`, chung cho Julia và SPMF. Không lấy mẫu giao dịch,
lọc item hoặc loại giao dịch trùng. Retail giữ nguyên item 0.

Để phân biệt dữ liệu dày và thưa, dùng mật độ giao dịch trung bình
`d = L̄ / |I|`, trong đó `L̄` là số item trung bình mỗi giao dịch và `|I|`
là số item phân biệt. Các thống kê lấy từ `data/datasets.toml`:

| Dataset | Số giao dịch | Số item | Độ dài trung bình | Mật độ (%) |
|---|---:|---:|---:|---:|
| Chess | 3.196 | 75 | 37,00 | 49,333 |
| Mushroom | 8.124 | 119 | 23,00 | 19,328 |
| Retail | 88.162 | 16.470 | 10,31 | 0,063 |
| Accidents | 340.183 | 468 | 33,81 | 7,224 |
| T10I4D100K | 100.000 | 870 | 10,10 | 1,161 |

Chess và Mushroom có mật độ cao hơn rõ rệt hai bộ sparse Retail và
T10I4D100K; Accidents có giao dịch dài và số giao dịch lớn nhất.

| Dataset | Minsup (%) từ cao xuống thấp |
|---|---|
| Chess | 90, 85, 80, 75, 70, 65, 60 |
| Mushroom | 60, 50, 40, 30, 25, 20, 15 |
| Retail | 2, 1.5, 1, 0.75, 0.5, 0.25, 0.1 |
| Accidents | 95, 90, 85, 80, 75, 70, 65 |
| T10I4D100K | 2, 1.5, 1, 0.75, 0.5, 0.25, 0.1 |

Dải được thử bằng pilot trước khi đo chính thức. Pilot hoàn thành 35/35
cặp dataset/minsup, mỗi cặp một lượt mỗi miner, khớp hoàn toàn itemset và
support với SPMF. Không có timeout hoặc mức thử thất bại; giữ nguyên các
mức này cho phép đo chính thức. Dải không giống nhau giữa dense/sparse vì
cùng một tỉ lệ support có thể sinh kích thước output rất khác nhau.

Mỗi cấu hình chạy một lượt sơ bộ và năm lần chính thức cho mỗi miner.
Mỗi mẫu tạo tiến trình mới, đo thời gian toàn trình bằng đồng hồ monotonic,
bao gồm startup/JIT, đọc input, xây TID-set, mining và xuất đầy đủ kết quả.
Lượt sơ bộ không được tính vào median và không làm nóng JIT của các tiến
trình tiếp theo. Thứ tự Julia/SPMF luân phiên giữa các lần lặp.

Vì vậy, đồ thị trả lời thời gian hoàn thành một tác vụ độc lập trên máy
đo, không tách riêng chi phí thuật toán. Khác biệt startup, quản lý bộ nhớ,
định dạng output và I/O đều có thể góp phần vào kết quả. Cả hai đường trên
đồ thị dùng cùng phạm vi toàn trình. Trong CSV, `miner=julia` chỉ cài đặt
Eclat BitVector của nhóm, còn `miner=spmf` chỉ Eclat tham chiếu trong SPMF;
kết quả không phải so sánh tổng quát giữa hai ngôn ngữ Julia và Java.

Julia 1.11.4 dùng một thread, cài đặt chính là BitVector. Worker ghi output
không sắp thứ tự toàn bộ các dòng, vì định dạng SPMF không yêu cầu điều đó.
Tham chiếu là SPMF 2.65, Java Temurin 25.0.5+8, JVM flags
`-Xmx2g -XX:ActiveProcessorCount=1`. SHA-256 jar:
`2cc2d89e39909230ea0455da4a1c79b389dc98ca04b0670befb63e679b5e2ea0`.
Máy đo: AMD Ryzen 7 7735HS, Windows; RAM và thông tin môi trường đầy đủ
được ghi trong metadata từng run.

Trước đo, kiểm tra checksum và số transaction. Support tuyệt đối tính bằng
`ceil(minsup × N)` với số hữu tỉ ở Julia; cấu hình bị từ chối nếu chuyển đổi
binary64 phía SPMF cho ngưỡng khác. Smoke test thật kiểm tra cả ngưỡng 21%
và 39% trên toy. Sau đo đối chiếu mỗi itemset/support của lượt đầu, các lượt
tiếp theo phải khớp checksum output đã xác nhận của từng miner. Thứ tự dòng
giữa Julia và SPMF có thể khác nhau.

Thống kê gồm median, Q1, Q3 và IQR, giữ mọi mẫu thành công, không loại
outlier. Với năm mẫu đã sắp tăng dần, median là mẫu thứ ba, Q1 và Q3 là
mẫu thứ hai và thứ tư; `IQR = Q3 − Q1`. Biểu đồ runtime có thanh Q1–Q3,
thể hiện độ phân tán của mẫu, không phải khoảng tin cậy hay min–max.
Đồ thị count đặt cả hai miner lên
cùng hệ trục để thể hiện kết quả trùng nhau. Trục support giảm dần, dùng
thang tuyến tính và không thay số 0 bằng epsilon.

## Kết quả thực đo

Run chính thức: `runtime_20261117T101543270`. Có 420 mẫu toàn trình,
gồm 70 mẫu sơ bộ và **350 mẫu chính thức** (35 case × 2 miner × 5 lần).
Tất cả tiến trình thành công; toàn bộ 35 case khớp itemset/support, count
giữ nguyên giữa các lần lặp và không giảm khi hạ support. Bảng dưới lấy
median năm lần, đơn vị giây. Hai cặp thời gian tương ứng ngưỡng cao nhất
và thấp nhất trong dải của từng dataset, không phải min/max runtime.

| Dataset | Count: ngưỡng cao → thấp | Julia / SPMF ở ngưỡng cao (s) | Julia / SPMF ở ngưỡng thấp (s) |
|---|---:|---:|---:|
| Chess | 622 → 254.944 | 1,469 / 0,372 | 1,948 / 7,769 |
| Mushroom | 51 → 98.575 | 1,487 / 0,371 | 1,581 / 1,322 |
| Retail | 55 → 7.589 | 1,565 / 1,143 | 10,634 / 1,435 |
| Accidents | 15 → 1.093 | 2,928 / 5,295 | 2,869 / 15,263 |
| T10I4D100K | 155 → 27.532 | 1,627 / 0,790 | 3,132 / 1,456 |

CSV nguồn: [bảng tổng hợp](../../results/metrics/benchmark_runs/runtime_20261117T101543270/summary.csv),
[mẫu thô](../../results/metrics/benchmark_runs/runtime_20261117T101543270/raw.csv),
[môi trường](../../results/metrics/benchmark_runs/runtime_20261117T101543270/environment.toml).

| Dataset | Runtime (median và Q1–Q3) | Số lượng itemset |
|---|---|---|
| Chess | [Hình](../../results/figures/runtime_20261117T101543270/chess_runtime.png) | [Hình](../../results/figures/runtime_20261117T101543270/chess_itemsets.png) |
| Mushroom | [Hình](../../results/figures/runtime_20261117T101543270/mushroom_runtime.png) | [Hình](../../results/figures/runtime_20261117T101543270/mushroom_itemsets.png) |
| Retail | [Hình](../../results/figures/runtime_20261117T101543270/retail_runtime.png) | [Hình](../../results/figures/runtime_20261117T101543270/retail_itemsets.png) |
| Accidents | [Hình](../../results/figures/runtime_20261117T101543270/accidents_runtime.png) | [Hình](../../results/figures/runtime_20261117T101543270/accidents_itemsets.png) |
| T10I4D100K | [Hình](../../results/figures/runtime_20261117T101543270/t10i4d100k_runtime.png) | [Hình](../../results/figures/runtime_20261117T101543270/t10i4d100k_itemsets.png) |

Mỗi hình có thêm bản SVG/PDF cùng tên để chèn báo cáo.

### Phân tích

Khi hạ minsup, cả năm bộ đều sinh nhiều pattern hơn. Mức tăng khác nhau rõ
rệt: Chess tăng từ 622 lên 254.944, còn Accidents chỉ tăng từ 15 lên 1.093
trong dải phần trăm cao được chọn. Không thể so trực tiếp hai count này
để kết luận bộ nào luôn nhiều pattern hơn, vì dải ngưỡng và số giao dịch khác nhau.

Trên cùng một CSDL, hạ ngưỡng support không loại các itemset đã phổ biến,
đồng thời có thể bổ sung các itemset trước đó chưa đủ support. Do đó count
phải không giảm; nó không bắt buộc tăng ở mọi mức ngưỡng. Trong ma trận này,
count thực tế tăng tại mọi bước giảm minsup của cả năm bộ. Các đường count
trùng nhau phản ánh số lượng bằng nhau; kết luận correctness còn dựa trên
đối chiếu từng itemset/support, không chỉ hình dạng đồ thị.

Trên Chess, SPMF nhanh hơn ở các ngưỡng cao; bitset nhanh hơn từ 70% xuống
60%. Ở 60%, tỉ lệ median SPMF/Julia khoảng 3,99. Với Accidents, bitset
nhanh hơn ở cả bảy ngưỡng; tại 65%, tỉ lệ này khoảng 5,32. Đây là quan sát
của phép đo toàn trình, không phải bằng chứng bitset luôn tốt hơn.

Mushroom cũng dense nhưng SPMF nhanh hơn ở toàn bộ dải đã thử. Điều đó cho
thấy nhãn dense/sparse chưa đủ dự đoán ưu thế giữa hai chương trình.
Trên Mushroom, output tăng từ 51 lên 98.575 pattern nhưng median Julia chỉ
đổi từ 1,487 lên 1,581 giây giữa hai đầu dải. Một giả thuyết là các chi phí
khởi động, JIT và đọc dữ liệu che lấp một phần biến thiên của mining ở các
tác vụ nhỏ. Chưa đo riêng từng thành phần nên chưa định lượng được phần
đóng góp của JIT hoặc xác nhận đây là nguyên nhân chính. Cấu trúc đồng xuất
hiện của item và khác biệt triển khai cũng có thể ảnh hưởng.

Trên hai bộ sparse, SPMF nhanh hơn ở cả bảy mức của mỗi bộ. Retail tại 0,1%
có median Julia 10,634 giây so với SPMF 1,435 giây, dù chỉ 7.589 pattern.
SPMF hoàn thành tác vụ này nhanh hơn khoảng 7,41 lần theo median toàn trình.

Đếm singleton từ output Julia của lượt sơ bộ cho thấy Retail có 712 item
phổ biến ở 0,25% và 2.117 item ở 0,1%. Hàm `_bitset_dfs!` thử giao mọi cặp
singleton tại gốc, tương ứng `k(k−1)/2`: số phép giao ở riêng mức gốc tăng
từ 253.116 lên 2.239.786, khoảng 8,85 lần. Đây là số phép giao suy ra từ
cấu trúc vòng lặp và output, chưa phải số đếm do profiler ghi nhận. Mỗi mask
vẫn dài theo toàn bộ số giao dịch, kể cả khi chỉ ít bit bằng 1; các giao
không đủ support vẫn tốn công trước khi bị loại.

Trong cùng bước giảm ngưỡng, output Retail chỉ tăng khoảng 4,03 lần
(1.882 → 7.589), còn median Julia tăng khoảng 4,33 lần (2,455 → 10,634 giây).
Điều này minh họa vì sao số pattern cuối cùng chưa mô tả đầy đủ khối lượng
công việc. Nó cung cấp căn cứ cho hạn chế của cài đặt bitset hiện tại khi
có nhiều singleton phổ biến trên dữ liệu thưa; chưa chứng minh phép giao
là nguyên nhân duy nhất hoặc giải thích nội bộ cài đặt SPMF.

Mật độ cũng không quyết định riêng độ dài pattern. Tại các ngưỡng thấp nhất
đã thử, đếm từ output sơ bộ cho thấy độ dài itemset lớn nhất là 14 trên
Chess, 15 trên Mushroom, 5 trên Retail, 8 trên Accidents và 10 trên
T10I4D100K. T10I4D100K vẫn sinh pattern dài dù sparse. Đây là mô tả các cấu
hình cụ thể, không phải so sánh có kiểm soát ở cùng một minsup.

Các thống kê singleton và độ dài trên được đếm từ output cục bộ
`<dataset>_<threshold>_0_julia.txt` của run đã nêu, với `threshold` tra trong
`summary.csv`. Có thể tái tạo các file này bằng runner benchmark.

Tổng cộng bitset nhanh hơn tại 10/35 cấu hình, SPMF nhanh hơn tại 25/35.
Không gộp thành một speedup trung bình để khẳng định ưu thế phổ quát:
thành phần dataset và dải minsup quyết định mạnh tới phép tổng hợp đó.
Runtime Julia trên Accidents còn dao động nhẹ dù count tăng liên tục;
đây không phải lỗi correctness hoặc vi phạm tính đơn điệu của support.

## Khả năng tái lập và giới hạn

Lệnh chạy, raw samples, bảng tổng hợp, cấu hình, checksum input/code/jar và
môi trường được lưu theo run riêng. Output mining/log lớn giữ cục bộ,
không đưa vào Git. Hướng dẫn đầy đủ: `experiments/BENCHMARKS.md`.

Các phép đo chỉ đại diện cho máy, phiên bản và dải ngưỡng đã ghi nhận.
Năm mẫu mỗi cấu hình giúp mô tả biến thiên nhưng chưa đủ để suy ra ưu thế
trên mọi phần cứng; các so sánh nhanh/chậm ở đây dựa trên median, chưa phải
kiểm định ý nghĩa thống kê. Dải minsup khác nhau và mức thấp nhất được chọn
theo pilot, nên không suy rộng thành độ phức tạp tiệm cận hoặc kết luận về
mọi ngưỡng support. Chưa đo riêng thời gian mining sau warm-up hoặc profile
các pha đọc, xây mask, giao mask và ghi output. Cache hệ điều hành có thể
được làm nóng sau lượt đầu;
đây không phải phép đo cold disk. Giới hạn Java heap cũng là điều kiện đo.
Đồng hồ quan sát tiến trình mỗi 10 ms tạo sai số nhỏ ở điểm chạy ngắn.
Số lượng itemset có tính đơn điệu khi hạ minsup; runtime có thể dao động.
Không suy ra độ phức tạp hoặc nguyên nhân hiệu năng chỉ từ một đường cong.
