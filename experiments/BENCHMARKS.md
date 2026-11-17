# Runtime trên dữ liệu thật

Chuẩn bị input bằng `julia --project=. scripts/prepare_benchmarks.jl`.
Cấu hình dùng chung tại `configs/benchmarks.toml`: 5 dataset, mỗi bộ 7 mức
minsup giảm dần. Có thể dùng đường dẫn Julia tuyệt đối nếu chưa thêm vào PATH.
Chạy từ repo root:

```powershell
# Java 25+; có thể đặt JAVA thành đường dẫn java.exe portable.
$env:JAVA = 'C:/Tools/Java/bin/java.exe'
$env:SPMF_JAR = 'C:/Tools/spmf.jar'
julia --startup-file=no --threads=1 --project=. experiments/run_benchmarks.jl --pilot
julia --startup-file=no --threads=1 --project=. experiments/run_benchmarks.jl
# Hoặc chỉ một dataset (vẫn đủ 7 mức):
julia --startup-file=no --threads=1 --project=. experiments/run_benchmarks.jl retail
```

Nếu JAVA/SPMF_JAR không được đặt, script dùng `java` trong PATH và
`tools/spmf.jar`. Jar là SPMF Eclat chính thức; xem `spmf/README.md`.
Không chạy benchmark nặng khác cùng lúc. Có thể gọi script bằng đường dẫn
tuyệt đối từ thư mục khác; đường dẫn cấu hình/input luôn tính từ repo root.

Mỗi lần chạy tạo thư mục riêng trong `results/metrics/benchmark_runs/`.
Không resume hoặc ghép các run. `pilot_*` chạy một mẫu mỗi miner/case;
`runtime_*` chạy một lượt sơ bộ (repeat=0) rồi 5 lượt chính thức.
Lượt sơ bộ không warm JIT cho các tiến trình mới sau đó.

## Phương pháp

Đồng hồ monotonic `time_ns()` đo từ khởi chạy tới kết thúc tiến trình mới,
bao gồm startup/JIT, đọc input, xây cấu trúc dữ liệu, khai thác và ghi output.
Đây là **end-to-end wall time**, không phải thời gian thuần thuật toán.
Không dùng timer khai thác riêng do SPMF in ra để tính speedup.
Các cột `seconds` dùng đơn vị giây; polling kết thúc mỗi 10 ms tạo sai số
quan sát nhỏ, đặc biệt đáng lưu ý với tác vụ rất ngắn.

Julia gọi API bitset và `write_spmf(...; sorted=false)` vì SPMF không yêu cầu
thứ tự dòng. Java dùng `-Xmx2g -XX:ActiveProcessorCount=1`; Julia một thread.
Giới hạn Java heap là lựa chọn môi trường được ghi nhận, không phải tuyên bố
hai runtime có cơ chế quản lý bộ nhớ giống nhau. Thứ tự Julia/Java luân phiên
theo repeat. Mọi mẫu thành công đều được giữ, không loại outlier.

Kiểm tra SHA-256/số dòng input trước đo và SHA-256 lần nữa sau đo. Ngưỡng
Julia tính bằng số hữu tỉ; cấu hình bị từ chối nếu phép chuyển phần trăm
binary64 của SPMF cho ngưỡng tuyệt đối khác. Smoke test thật dùng toy ở
20%, 21%, 39%, 40% để kiểm tra cả trường hợp ceil sát ranh giới.

Sau mỗi lần chạy, kiểm tra exit code, marker hoàn tất và output. Lượt đầu
của mỗi case so chính xác mọi itemset/support bằng API so sánh hiện có;
những lượt sau phải khớp byte checksum của output đã xác nhận cho từng miner.
Không yêu cầu thứ tự output giữa hai miner giống nhau. Count không được
giảm khi minsup giảm. Nếu có lỗi, run không được đánh dấu hoàn tất.

`raw.csv` lưu cả preliminary sample và lỗi tiến trình; `summary.csv` chỉ
chứa các case đã xác thực đủ số mẫu, median/Q1/Q3/IQR. Lỗi timeout không
có giá trị thời gian hoàn tất. Output/log cục bộ được giữ để chẩn đoán,
không commit các output mining lớn. Metadata chứa commands, source hashes,
jar hash, cấu hình, commit/dirty, CPU/OS/RAM và phiên bản runtime.
`complete=true` chỉ có nghĩa hoàn tất các dataset được chọn trong run;
để nghiệm thu toàn bộ cần run đủ năm bộ. Không đổi mã/cấu hình trong lúc đo.

## Biểu đồ

Python 3.11+ chỉ dùng để vẽ biểu đồ, không cài đặt hoặc chạy mining.
Dependency ở môi trường riêng, không thay Project.toml của thuật toán:

```powershell
python -m venv .venv-figures
.venv-figures/Scripts/python.exe -m pip install -r experiments/requirements-figures.txt
.venv-figures/Scripts/python.exe experiments/plot_benchmarks.py results/metrics/benchmark_runs/<run_id>
```

Script kiểm tra completed marker, checksum CSV, grid, số mẫu và trạng thái
đối chiếu trước khi vẽ. Mỗi dataset có runtime (median, thanh Q1–Q3) và count
trên trục minsup giảm dần. Xuất PNG, SVG và PDF ở
`results/figures/<run_id>/`. Không log-transform hoặc thay số 0 bằng epsilon.
Biểu đồ lịch sử dùng metadata của lần đo đó; không đòi mã hiện tại giống mã
của lần đo cũ. Các file kết quả cũ không bị ghi đè.

## Chọn dải

Pilot ban đầu thử đủ 7 mức trong cấu hình hiện tại. Toàn bộ 35 case khớp
SPMF, không timeout; giữ nguyên dải trước khi đo chính thức. Chess/Mushroom
cần phần trăm cao hơn các bộ sparse để output không bùng nổ. Accidents
dùng 95%–65% do kích thước lớn và thời gian tham chiếu tăng khi hạ ngưỡng.
Retail và T10I4D100K dùng 2%–0.1% để quan sát pattern ngoài singleton.
Các ngưỡng này mô tả hành vi trong dải khả thi đã thử, không đại diện mọi
minsup. Không có ngưỡng pilot thất bại bị giấu khỏi cấu hình.
