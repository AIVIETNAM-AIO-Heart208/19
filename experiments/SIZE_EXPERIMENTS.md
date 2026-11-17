# Scalability và độ dài giao dịch

Julia >=1.9, SPMF jar và Java 25+ như hướng dẫn trong `BENCHMARKS.md`.
`JAVA` có thể chỉ đường dẫn java.exe, `SPMF_JAR` mặc định là `tools/spmf.jar`.
Chuẩn bị dữ liệu: `julia --project=. scripts/prepare_benchmarks.jl retail`.

```powershell
julia --startup-file=no --threads=1 --project=. experiments/run_scalability.jl --pilot
julia --startup-file=no --threads=1 --project=. experiments/run_transaction_length.jl --pilot
# Chạy đủ test/cài dependency trước khi đo chính thức; không chạy tác vụ nặng song song.
julia --startup-file=no --threads=1 --project=. experiments/run_scalability.jl
# Bổ sung Accidents, cấu hình riêng minsup 75%:
julia --startup-file=no --threads=1 --project=. experiments/run_scalability.jl --dataset=accidents --pilot
julia --startup-file=no --threads=1 --project=. experiments/run_scalability.jl --dataset=accidents
julia --startup-file=no --threads=1 --project=. experiments/run_transaction_length.jl
# Một cấu hình nhỏ, phục vụ kiểm tra (không phải nghiệm thu toàn bộ):
julia --startup-file=no --threads=1 --project=. experiments/run_transaction_length.jl --pilot --case=1
```

Cấu hình Retail ở `configs/scalability.toml`, Accidents ở
`configs/scalability_accidents.toml`, tổng hợp ở `configs/transaction_length.toml`.
Không truyền --dataset thì scalability mặc định dùng Retail. Accidents dùng
75%, giữ cố định trên cả năm mức kích thước; không dùng ngưỡng 0,1% của Retail.
Mỗi run tạo thư mục riêng trong `results/metrics/size_runs/`, không resume
hoặc ghép mẫu. Các đường dẫn input/cấu hình tính từ repo root. Cần chạy
với project của repo; nếu ở thư mục khác, truyền đường dẫn tuyệt đối cho
`--project` và script.

## Input

Retail và Accidents dùng MersenneTwister(42), một randperm trên toàn bộ chỉ số giao dịch.
Các mức lấy prefix dài floor(p*N/100), rồi sắp chỉ số tăng để giữ thứ tự nguồn.
Không unique giao dịch. Mức 100% dùng chính processed source; các mức khác
lưu input dẫn xuất riêng. Manifest trong environment.toml ghi source/input
hash, index hash, actual_fraction, seed, phiên bản Julia/RNG và cấu hình.
Seed không bảo đảm cùng byte giữa mọi phiên bản Julia; kiểm tra input hash.

Dữ liệu tổng hợp: N=20.000, U=64, L=8/12/16/20/24, minsup=5%.
Sinh một hoán vị 1:U cho từng giao dịch bằng RNG cục bộ MersenneTwister(42).
Mỗi L lấy prefix của cùng hoán vị, sort item trước khi dùng. N và miền item
giữ cố định; từng giao dịch lồng nhau theo L. Giao dịch trùng vẫn được giữ.

## Đo và xác thực

Metric chính là thời gian API sau warm-up, khác phạm vi toàn trình của
`run_benchmarks.jl`. Worker đọc input, gọi đầy đủ eclat_bitset một lần để
warm-up và so từng itemset/support với output SPMF thực tế. Sau đó chạy năm
lần API; GC.gc() trước mỗi mẫu, ngoài timer. Timer bao gồm validation của
miner, xây mask, DFS, cấp phát và tạo đầy đủ kết quả. GC trong lời gọi vẫn
thuộc thời gian đo. Không tính đọc/ghi, lấy mẫu, generator, fingerprint hoặc
so correctness. Mỗi mẫu phải có fingerprint kết quả giống lượt đã xác nhận
và input không bị mutate. Count bằng nhau không được dùng thay exact match.

Pilot dùng một mẫu sau warm-up mỗi cấu hình, không đưa vào kết quả chính
thức. Retail pilot thử 0,1%, Accidents thử 75% trên cả năm mức và giữ nguyên; tổng hợp thử cấu
hình ở trên, không đổi seed, không timeout, toàn bộ khớp SPMF. Mức cuối sinh
pattern dài hơn singleton. Minsup tuyệt đối tính lại theo từng N; kiểm tra
thêm phép chuyển phần trăm binary64 của SPMF trước khi chạy.

Timeout 900 giây áp riêng cho tiến trình SPMF và cho toàn worker (startup,
warm-up, năm mẫu, validation), không phải cho một lời gọi API. Parent chỉ
quản lý timeout, không dùng timer polling làm số liệu mining. Worker không
tạo subprocess khác. Run lỗi không complete; đọc status/reason và log của
case. raw.csv chỉ chứa mẫu đã qua kiểm tra; case lỗi nằm trong metadata.

summary.csv ghi N, item thực tế, tổng số item, mean length, threshold,
minsup, seed, checksum, số pattern/singleton/max length, median/Q1/Q3/IQR.
raw.csv join với summary qua case_id. Metadata lưu câu lệnh, phiên bản,
CPU/OS/RAM/threads, commit/dirty và source/artifact hashes.

Mỗi run gắn với phiên bản mã và checksum tại thời điểm đo. Khi mã thay đổi,
giữ nguyên metadata lịch sử; dùng thư mục run riêng cho các lần đo mới.

## Biểu đồ và kiểm tra

Sau khi có completed run:

```powershell
.venv-figures/Scripts/python.exe experiments/plot_size_benchmarks.py results/metrics/size_runs/<run_id>
```

Dùng môi trường matplotlib đã khai báo tại `requirements-figures.txt`.
Script từ chối pilot, run chưa hoàn tất, CSV sai hash, case thiếu/trùng hoặc
không khớp grid cấu hình. Retail có năm case; họ độ dài có thể có nhiều hơn
năm mức. Trước khi vẽ, script kiểm tra số mẫu/thứ tự repeat, trạng thái và
tính lại median/Q1/Q3/IQR từ raw.csv để đối chiếu bảng tổng hợp.
Xuất runtime và count ra PNG/SVG/PDF trong `results/figures/<run_id>/`.
Trục x dùng N thực tế hoặc mean length; thanh dọc runtime là Q1–Q3, không
phải khoảng tin cậy. Các mẫu chỉ lặp lại timing cùng input, không phải nhiều
seed lấy mẫu độc lập.

Kiểm tra từng yêu cầu:
- Scalability: summary có level 10/25/50/75/100 và N theo floor; case 100% có source hash.
- Runtime: repeats=5, scope=warmed_api; xem runtime.png và raw.csv.
- Độ dài: N cố định, mean_length=8/12/16/20/24, total_items=N*L; xem count và runtime.
- Correctness: mỗi case status exact_match; worker TOML lưu fingerprint kết quả.
- Nội dung báo cáo: `docs/report/scalability.md`.
