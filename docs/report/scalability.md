# Scalability và ảnh hưởng của độ dài giao dịch

## Thiết kế và phạm vi đo

Thực nghiệm đánh giá Eclat BitVector của nhóm. Metric chính là thời gian
gọi trọn API sau warm-up, gồm validation input, xây mask, DFS, cấp phát và
tạo đầy đủ itemset/support. Sinh/lấy mẫu input, đọc/ghi, so SPMF, fingerprint
và ghi số liệu nằm ngoài timer. Mỗi cấu hình có một warm-up trên chính input
đó và năm mẫu chính thức; GC chủ động trước mẫu nằm ngoài timer, GC xảy ra
bên trong API vẫn được tính. Báo cáo median và Q1–Q3; thanh Q1–Q3 mô tả phân
tán mẫu, không phải khoảng tin cậy. Không loại mẫu nhanh/chậm tùy ý.

Phạm vi này khác phép đo toàn trình ở phần runtime theo minsup, vốn gồm
startup/JIT và I/O. Mức 100% được đo lại cùng phương pháp API với bốn mức
còn lại; không ghép số end-to-end cũ vào đường cong hoặc trừ hai phép đo để
ước tính riêng chi phí I/O.

Retail lấy từ processed input có checksum cố định trong data/datasets.toml.
Sử dụng RNG cục bộ MersenneTwister, seed 42 và một hoán vị trên chỉ số giao
dịch. Mức p lấy prefix gồm floor(p*N/100) chỉ số, sau đó sắp chỉ số về thứ
tự gốc. Các tập con lồng nhau, không lấy mẫu hoàn lại, không loại giao dịch
trùng hoặc đổi item ID. Mức 100% dùng chính file nguồn. Giữ minsup tương
đối 0,1%, tính lại threshold=ceil(0,001*N_subset) cho từng mức.

| Tỉ lệ yêu cầu (%) | Giao dịch thực tế | Ngưỡng support tuyệt đối |
|---:|---:|---:|
| 10 | 8.816 | 9 |
| 25 | 22.040 | 23 |
| 50 | 44.081 | 45 |
| 75 | 66.121 | 67 |
| 100 | 88.162 | 89 |

Accidents sử dụng cùng quy tắc lấy mẫu, seed 42 và năm tỉ lệ trên.
Minsup giữ cố định 75% trong họ Accidents, tương ứng các threshold dưới đây.
Ngưỡng cao hơn Retail được chọn để không gian tìm kiếm khả thi; hai đường
cong không dùng chung minsup và không nhằm so trực tiếp tốc độ giữa hai bộ.

| Tỉ lệ yêu cầu (%) | Giao dịch Accidents | Ngưỡng support tuyệt đối |
|---:|---:|---:|
| 10 | 34.018 | 25.514 |
| 25 | 85.045 | 63.784 |
| 50 | 170.091 | 127.569 |
| 75 | 255.137 | 191.353 |
| 100 | 340.183 | 255.138 |

Thực nghiệm độ dài giữ N=20.000, miền item 1:64, minsup=5% (threshold=1.000)
và seed 42. Với từng giao dịch, sinh một hoán vị chung của 64 item; mức L
lấy L item đầu rồi sort. Dùng L=8,12,16,20,24. Mỗi dòng có đúng L item phân
biệt; giao dịch lồng nhau theo L và giao dịch trùng giữa các dòng được giữ.
Input có đúng N*L lần xuất hiện item, được sinh xong trước khi đo.

Pilot kiểm tra đủ mười lăm cấu hình của Retail, Accidents và họ dữ liệu
tổng hợp, mỗi cấu hình một mẫu sau warm-up. Tất cả khớp SPMF và không
timeout. Giữ nguyên tham số cho lần chạy chính thức, không chọn lại seed
hay điều chỉnh minsup riêng từng điểm để ổn định output.

## Xác thực và môi trường

SPMF Eclat là tham chiếu hộp đen, chạy trên cùng file/minsup trước worker
timing. Sau warm-up, đối chiếu mọi itemset/support với output tham chiếu;
mỗi mẫu đo tiếp theo phải có fingerprint giống kết quả đã xác nhận. Worker
còn kiểm tra input không bị mutate. Với họ dữ liệu độ dài, runner kiểm tra
support của mọi pattern phổ biến trước đó không giảm khi tăng L. Không áp
tính đơn điệu này cho hai họ scalability vì N và threshold đồng thời thay đổi.

Môi trường: Windows, AMD Ryzen 7 7735HS, Julia 1.11.4 với --threads=1,
SPMF 2.65 và Temurin Java 25.0.5+8. Java dùng -Xmx2g và
-XX:ActiveProcessorCount=1 để sinh tham chiếu; không đo speedup Julia/SPMF
trong thí nghiệm này. Timeout 900 giây áp cho từng tiến trình SPMF và toàn
worker, gồm startup, warm-up, năm mẫu và validation. Parent quản lý timeout,
timer API nằm trong worker. Các benchmark chính thức chạy tuần tự sau test.

Metadata lưu seed, RNG/Julia, cấu hình, input/index/source hashes, câu lệnh,
commit/dirty, mã nguồn và môi trường. Seed không bảo đảm input giống hệt
giữa mọi phiên bản Julia; phải đối chiếu checksum thực tế. Output mining và
input dẫn xuất lớn nằm ngoài Git, có thể sinh lại bằng runner.

## Kết quả chính thức

Ba run: `scalability_20261117T114929979`,
`transaction_length_20261117T115244301` và
`scalability_accidents_20261117T123628055`. Mỗi run gồm năm cấu hình, mỗi cấu
hình năm mẫu API sau warm-up: tổng cộng 75 mẫu chính thức, cả mười lăm cấu hình
khớp từng itemset/support với SPMF và input không bị mutate.

### Scalability trên Retail

| Tỉ lệ (%) | N | Item thực tế | Mean length | Itemset | Singleton phổ biến | Median (s) | Q1–Q3 (s) | T/N (µs/giao dịch) |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 10 | 8.816 | 10.103 | 10,292 | 8.908 | 2.222 | 1,086 | 1,077–1,123 | 123,18 |
| 25 | 22.040 | 12.806 | 10,312 | 7.576 | 2.105 | 3,911 | 3,558–4,079 | 177,45 |
| 50 | 44.081 | 14.768 | 10,313 | 7.646 | 2.088 | 5,636 | 5,563–6,092 | 127,86 |
| 75 | 66.121 | 15.784 | 10,311 | 7.663 | 2.122 | 7,718 | 7,538–7,882 | 116,73 |
| 100 | 88.162 | 16.470 | 10,306 | 7.589 | 2.117 | 8,650 | 8,616–8,757 | 98,12 |

[CSV thô](../../results/metrics/size_runs/scalability_20261117T114929979/raw.csv),
[CSV tổng hợp](../../results/metrics/size_runs/scalability_20261117T114929979/summary.csv),
[metadata](../../results/metrics/size_runs/scalability_20261117T114929979/environment.toml),
[runtime](../../results/figures/scalability_20261117T114929979/runtime.png),
[count](../../results/figures/scalability_20261117T114929979/itemsets.png).

Runtime tăng tại cả năm điểm. Từ mức 10% lên 100%, N tăng khoảng 10 lần,
còn median tăng khoảng 7,97 lần. Tuy nhiên T/N dao động từ khoảng 98,12
đến 177,45 µs/giao dịch; dữ liệu không thể hiện tỉ lệ thuận chính xác
`T=cN`. T/N biến thiên không tự loại trừ mô hình có hệ số chặn `T=a+bN`.
Năm điểm này chưa đủ để kết luận xu hướng tuyến tính/phi tuyến tổng quát
hoặc chứng minh một độ phức tạp tiệm cận.

Độ dài trung bình gần như ổn định quanh 10,3, số singleton phổ biến quanh
2.100–2.200 và tổng output quanh 7.500–8.900. Khi N tăng, mỗi mask dài hơn,
trong khi số singleton đầu tìm kiếm khá ổn định. Đây là căn cứ từ dữ liệu
và cấu trúc cài đặt để giải thích xu hướng tăng; không phải kết quả profile
chứng minh phép giao chiếm toàn bộ runtime. Số item thực tế cũng tăng từ
10.103 lên 16.470 nên không chỉ một đại lượng workload thay đổi.

Count giảm từ 8.908 ở 10% xuống 7.576 ở 25%, rồi dao động nhẹ. Điều này
không phải lỗi: tăng N đồng thời tăng threshold từ 9 lên 23, và phân bố
support của tập con khác tập đầy đủ. Tính lồng nhau của giao dịch không bảo
đảm tập frequent itemset lồng nhau khi support tuyệt đối cũng tăng.

### Scalability trên Accidents

Giữ minsup 75% trên toàn bộ năm mức. Mỗi điểm là median năm lời gọi API
sau warm-up; bảng này đổi thời gian sang millisecond, CSV và đồ thị dùng giây.

| Tỉ lệ (%) | N | Item thực tế | Mean length | Itemset | Singleton phổ biến | Median (ms) | Q1–Q3 (ms) | T/N (µs/giao dịch) |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 10 | 34.018 | 353 | 33,814 | 319 | 14 | 18,702 | 18,500–18,727 | 0,550 |
| 25 | 85.045 | 380 | 33,811 | 319 | 14 | 47,194 | 46,862–48,384 | 0,555 |
| 50 | 170.091 | 417 | 33,810 | 319 | 14 | 94,757 | 93,467–95,039 | 0,557 |
| 75 | 255.137 | 444 | 33,808 | 315 | 14 | 142,022 | 141,856–142,035 | 0,557 |
| 100 | 340.183 | 468 | 33,808 | 313 | 14 | 193,703 | 192,367–195,931 | 0,569 |

[CSV thô](../../results/metrics/size_runs/scalability_accidents_20261117T123628055/raw.csv),
[CSV tổng hợp](../../results/metrics/size_runs/scalability_accidents_20261117T123628055/summary.csv),
[metadata](../../results/metrics/size_runs/scalability_accidents_20261117T123628055/environment.toml),
[runtime](../../results/figures/scalability_accidents_20261117T123628055/runtime.png),
[count](../../results/figures/scalability_accidents_20261117T123628055/itemsets.png).

**Nhận xét xu hướng:** Accidents thể hiện tăng gần tuyến tính, gần tỉ lệ
thuận với N trong dải 10%–100% ở minsup 75%. Số giao dịch tăng khoảng 10 lần
thì median tăng 10,36 lần; T/N chỉ thay đổi khoảng 0,550–0,569 µs/giao dịch
(chênh lệch hai đầu khoảng 3,6%). Đây là bằng chứng thực nghiệm phù hợp với
xu hướng gần tuyến tính trong dải đã đo, chưa phải chứng minh thuật toán
có độ phức tạp O(N) trên mọi input hoặc minsup.

Độ dài trung bình ổn định quanh 33,81, số singleton phổ biến luôn là 14,
output chỉ thay đổi nhẹ từ 319 xuống 313 và độ dài pattern lớn nhất luôn
là 6. Không gian kết quả do đó khá ổn định trong khi tổng số item đầu vào
tăng từ 1.150.276 lên 11.500.870. Chiều dài mask tăng theo N; cấu hình ít
biến động về singleton và output giúp quan sát ảnh hưởng của N rõ hơn.
Chưa đo riêng các pha nên không khẳng định chỉ một phép toán quyết định
toàn bộ thời gian chạy.

Count giảm nhẹ vẫn hợp lệ: threshold tăng cùng kích thước và phân bố
support của các tập con có thể lệch nhau. Tất cả năm cấu hình đã so chính
xác từng itemset/support với SPMF, không chỉ so tổng số pattern.

### Đối chiếu xu hướng Retail và Accidents

Trong các cấu hình đã chọn, Accidents gần tỉ lệ thuận với N rõ hơn Retail:
T/N tương đối ổn định, còn Retail có T/N dao động 98,12–177,45 µs/giao dịch.
Cả hai bộ đều cho runtime tăng khi tăng số giao dịch, nhưng mức tăng phụ
thuộc workload tìm kiếm và không chỉ kích thước file hay nhãn dense/sparse.

Không dùng thời gian tuyệt đối giữa hai bộ để kết luận Accidents dễ hơn
hoặc dữ liệu dense luôn nhanh hơn sparse. Retail chạy ở 0,1%, Accidents ở
75%, dẫn đến không gian tìm kiếm rất khác. Ví dụ tại 100%, Retail có 2.117
singleton phổ biến còn Accidents chỉ có 14. Với vòng lặp tại gốc của cài
đặt hiện tại, số cặp cần giao lần lượt là 2.239.786 và 91 (k(k−1)/2).
Đây là khối lượng suy ra từ số singleton và code, chưa phải số đếm profiler.
Nó giải thích vì sao chỉ so N và độ dài giao dịch có thể dẫn đến nhận xét
sai; chưa định lượng riêng đóng góp thời gian của từng pha.

### Độ dài giao dịch tổng hợp

| L | Tổng item đầu vào | Item thực tế | Singleton phổ biến | Itemset | Độ dài pattern lớn nhất | Median (ms) | Q1–Q3 (ms) |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 8 | 160.000 | 64 | 64 | 64 | 1 | 4,055 | 4,048–4,227 |
| 12 | 240.000 | 64 | 64 | 64 | 1 | 6,378 | 6,107–6,506 |
| 16 | 320.000 | 64 | 64 | 2.080 | 2 | 55,583 | 55,568–56,850 |
| 20 | 400.000 | 64 | 64 | 2.080 | 2 | 60,749 | 59,495–61,183 |
| 24 | 480.000 | 64 | 64 | 9.816 | 3 | 104,237 | 101,760–104,800 |

CSV và biểu đồ lưu thời gian theo giây; bảng trên đổi sang millisecond.
[CSV thô](../../results/metrics/size_runs/transaction_length_20261117T115244301/raw.csv),
[CSV tổng hợp](../../results/metrics/size_runs/transaction_length_20261117T115244301/summary.csv),
[metadata](../../results/metrics/size_runs/transaction_length_20261117T115244301/environment.toml),
[runtime](../../results/figures/transaction_length_20261117T115244301/runtime.png),
[count](../../results/figures/transaction_length_20261117T115244301/itemsets.png).

Tăng L từ 8 lên 24 nhân ba tổng số item đầu vào, nhưng median tăng khoảng
25,71 lần; output tăng từ 64 lên 9.816. Xu hướng có bước nhảy rõ ở L=16,
không chỉ tỉ lệ với L. Tại L=8 và L=12 chỉ có singleton phổ biến; L=16 và
L=20 có đủ 64 singleton và 2.016 cặp item, tổng 2.080 pattern. Cặp item
phổ biến cho phép DFS đi sâu và thử các giao tiếp theo, kể cả khi các
pattern dài hơn không qua ngưỡng. L=24 bắt đầu có thêm pattern độ dài ba.
Số singleton vẫn là 64 tại mọi mức, nên chỉ đếm số singleton cũng chưa đủ
giải thích chi phí tìm kiếm sâu hơn.

Ở N cố định, mọi mask có cùng chiều dài 20.000 bit. Chênh lệch runtime
không đến từ mask dài thêm; nó gắn với lượng input lớn hơn và sự mở rộng
không gian tìm kiếm. Từ L=16 lên L=20, output vẫn 2.080 nhưng runtime tăng
từ 55,583 lên 60,749 ms, minh họa rằng chi phí xử lý input và các ứng viên
bị loại cũng cần được xét. Chưa tách riêng từng thành phần bằng profiling.

## Giới hạn diễn giải

Scalability dùng một seed cho mỗi họ tập con Retail và Accidents. Năm lần timing lặp lại
cùng input, không phải năm lần lấy mẫu độc lập. Ngoài số giao dịch, số item
xuất hiện, các singleton phổ biến và cấu trúc support cũng có thể thay đổi.
Vì vậy, không suy ra độ phức tạp O(N) hoặc O(N²) chỉ từ năm điểm và không
dùng R² để chứng minh độ phức tạp. T(N)/N chỉ là chỉ báo trên các cấu hình đã thử.

Khi tăng L, đồng thời tăng tổng item đầu vào, mật độ và khả năng đồng xuất
hiện/output. Đây là tổng ảnh hưởng trong mô hình sinh đã chọn, chưa cô lập
chi phí của riêng độ dài. Tại N cố định, mask vẫn dài theo N; tăng L không
làm mask dài thêm mà thay đổi số bit 1, support và số nhánh tìm kiếm.
Không mặc định runtime phải tăng ở mọi điểm, cũng không suy ra dense luôn
nhanh hoặc chậm hơn sparse. Chưa profiling riêng các pha nên không gán
dao động cho JIT/GC/cache như một nguyên nhân đã được chứng minh.

Hướng dẫn tái lập và kiểm tra từng yêu cầu:
[SIZE_EXPERIMENTS.md](../../experiments/SIZE_EXPERIMENTS.md).
