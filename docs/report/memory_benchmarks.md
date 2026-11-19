# Bộ nhớ: baseline TID-list và bitset trên dữ liệu thật

## Thiết kế đo

Đề yêu cầu đo RAM tối đa (peak memory) cho mỗi tập dữ liệu tại một minsup
trung bình và so sánh bản cơ bản với bản tối ưu. Thực nghiệm dùng cả năm CSDL
của phần runtime, cùng file processed có SHA-256 cố định trong
`data/datasets.toml`.

| Dataset | Minsup | Ngưỡng tuyệt đối | Lý do chọn |
|---|---:|---:|---|
| Chess | 75% | 2.397 | điểm thứ 4 trong dải 7 mức của phần runtime |
| Mushroom | 30% | 2.438 | điểm thứ 4 |
| Retail | 0,75% | 662 | điểm thứ 4 |
| Retail | 0,1% | 89 | điểm thứ 7 (thấp nhất), đo thêm để thấy trường hợp bitset bất lợi |
| Accidents | 80% | 272.147 | điểm thứ 4 |
| T10I4D100K | 0,75% | 750 | điểm thứ 4 |

Runner kiểm tra mỗi minsup phải nằm trong dải runtime và checksum dataset
phải khớp trước khi đo. Mỗi phép đo là **một tiến trình Julia mới** chạy một
miner một lần (`experiments/memory_real_worker.jl`). Worker biên dịch hàm
mining trên một CSDL 3 giao dịch (không làm nóng trên dữ liệu đo), đọc input,
gọi `GC.gc()`, rồi ghi lại:

- `rss_before`: RSS hiện tại ngay trước khi gọi hàm mining;
- `peak_before`: `Sys.maxrss()` trước mining, tức đỉnh của tiến trình đã đạt
  trong lúc khởi động, biên dịch và đọc dữ liệu;
- `peak`: `Sys.maxrss()` sau mining;
- thời gian riêng lời gọi hàm mining (không gồm khởi động, đọc, ghi).

Mỗi cấu hình đo 3 lần, đảo thứ tự baseline/bitset giữa các lần; bảng lấy
trung vị. Cả 36/36 phép đo thành công. Số itemset của baseline và bitset bằng
nhau ở mọi cấu hình (runner dừng nếu lệch) và trùng với số đã đối chiếu SPMF ở
phần runtime: 20.993, 2.735, 277, 7.589, 149, 561.

Ba đại lượng được báo cáo, theo thứ tự từ rộng đến hẹp:

1. **Peak RSS của tiến trình**: đại lượng đề yêu cầu. Nó gồm cả runtime Julia,
   mã đã biên dịch và CSDL đã đọc (khoảng 236–380 MB trước khi mining), nên
   không phải bộ nhớ riêng của thuật toán.
2. **Delta RSS** `= peak − rss_before`, chỉ ghi khi mining đẩy đỉnh lên cao hơn
   `peak_before`. Nếu đỉnh không tăng thì phần mining dùng không vượt đỉnh đã
   có từ lúc khởi động; ô đó để trống ("—"), không ghi 0.
3. **Cấu trúc dọc ở gốc**: `Base.summarysize` của các TID-list hoặc BitVector
   của item đơn phổ biến, dựng lại độc lập trong worker theo đúng cách hai hàm
   lõi dựng (không sửa `src/algorithm/`). Đây chỉ là **cận dưới** của bộ nhớ
   thuật toán: chưa gồm các lớp con sinh ra trong DFS và output.

Kích thước cấu trúc dọc được đối chiếu với công thức trước khi ghi:
bitset `k × ceil(N/64) × 8` byte (k item phổ biến, N giao dịch), TID-list
`8 × tổng support` byte. Bitset phải nằm trong khoảng công thức cộng 64 byte
header mỗi item; TID-list được phép lớn hơn công thức đến 3 lần vì `push!`
cấp dư dung lượng. Runner còn chạy một self-check trên CSDL 130 giao dịch biết
trước đáp án. Kết quả thực đo, TID-list lớn hơn công thức 1,4–1,9 lần.

Máy đo: AMD Ryzen 7 5800H, RAM 31,4 GiB, Windows, Julia 1.11.9, `--threads=1`,
commit `e3831d8`, cây làm việc sạch (`dirty = false`). **Máy này khác máy đo
runtime/scalability** (Ryzen 7 7735HS, Julia 1.11.4), nên không so trực tiếp
thời gian ở bảng dưới với các bảng runtime.

## Kết quả

Run: `memory_real_20261119T060226`. MB = 10^6 byte. "B" = baseline TID-list,
"S" = bitset. Delta có ghi số lần đo được trong ngoặc khi khác 3.

| Dataset / minsup | Peak RSS B / S (MB) | RSS trước mining B / S (MB) | Delta RSS B / S (MB) | Thời gian mining B / S (s) |
|---|---:|---:|---:|---:|
| Chess 75% | 260,8 / 254,6 | 240,7 / 241,6 | 20,1 / — | 1,253 / 0,009 |
| Mushroom 30% | 254,8 / 254,6 | 236,6 / 236,5 | 18,1 (2/3) / — | 0,198 / 0,008 |
| Retail 0,75% | 275,1 / 286,9 | 258,2 / 260,6 | 17,2 / 26,6 | 0,260 / 0,128 |
| Retail 0,1% | 314,3 / **386,3** | 258,5 / 257,1 | 56,0 / **129,2** | 12,622 / 10,119 |
| Accidents 80% | **665,6** / 433,4 | 359,9 / 379,9 | **305,9** / — | 1,812 / 0,397 |
| T10I4D100K 0,75% | 305,1 / 299,9 | 251,0 / 252,7 | 54,1 / 47,3 | 3,316 / 0,509 |

Cấu trúc dọc ở gốc (byte, `summarysize`; k = số item đơn phổ biến; "support
TB" = support trung bình của k item đó chia cho N):

| Dataset / minsup | k | Support TB | TID-list B | BitVector S | B / S |
|---|---:|---:|---:|---:|---:|
| Chess 75% | 23 | 90,74% | 754.216 | 10.672 | 70,7 |
| Mushroom 30% | 28 | 55,41% | 1.397.304 | 30.240 | 46,2 |
| Retail 0,75% | 114 | 2,69% | 3.372.040 | 1.264.032 | 2,67 |
| Retail 0,1% | 2.117 | 0,36% | 9.886.056 | 23.473.296 | **0,42** |
| Accidents 80% | 11 | 90,69% | 46.377.640 | 468.512 | 99,0 |
| T10I4D100K 0,75% | 463 | 1,88% | 10.807.440 | 5.818.984 | 1,86 |

k và support TB suy ra từ hai công thức trên (`vertical_estimate_bytes` trong
CSV); k = 2.117 của Retail 0,1% trùng số singleton phổ biến ghi ở phần runtime.

Nguồn: [summary.csv](../../results/metrics/benchmark_runs/memory_real_20261119T060226/summary.csv),
[raw.csv](../../results/metrics/benchmark_runs/memory_real_20261119T060226/raw.csv),
[environment.toml](../../results/metrics/benchmark_runs/memory_real_20261119T060226/environment.toml).
Hình: [peak RSS](../../results/figures/memory_real_20261119T060226/peak_rss.png),
[cấu trúc dọc (trục log)](../../results/figures/memory_real_20261119T060226/vertical_structure.png);
mỗi hình có bản SVG/PDF cùng tên. Vẽ lại bằng
`python experiments/plot_memory_real.py` (script kiểm checksum CSV trước khi vẽ).

## Phân tích

**Khi nào bitset gọn hơn TID-list.** Một item có support s (tuyệt đối) tốn
`8s` byte nếu lưu TID-list `Int64`, nhưng luôn tốn khoảng `N/8` byte nếu lưu
mask N bit, bất kể s lớn hay nhỏ. Hai cách bằng nhau khi `s = N/64`, tức
support tương đối khoảng **1,56%**. Item phổ biến hơn mức này thì bitset gọn
hơn; hiếm hơn thì TID-list gọn hơn. Theo công thức, tỉ lệ B / S xấp xỉ
`64 × support TB`.

Bảng cấu trúc dọc khớp quy luật này ở cả sáu cấu hình. Chess và Accidents có
support TB khoảng 91% nên bitset nhỏ hơn 70–99 lần. Mushroom (55%) nhỏ hơn 46
lần. Hai cấu hình thưa có support TB chỉ hơi trên 1,56% (Retail 0,75%: 2,69%;
T10I4D100K: 1,88%) nên bitset chỉ nhỏ hơn 1,9–2,7 lần. Retail 0,1% có 2.117
item với support TB 0,36%, **dưới** ngưỡng, nên bitset lớn hơn TID-list 2,4
lần (23,5 MB so với 9,9 MB). Như vậy nhãn dense/sparse của cả CSDL chưa đủ;
yếu tố quyết định là support của các item còn lại sau khi lọc theo minsup.

**Peak RSS.** Phần lớn peak RSS là nền của tiến trình: 236–260 MB trước khi
mining ở bốn CSDL nhỏ/vừa, 360–380 MB ở Accidents (do đọc 340.183 giao dịch).
Vì thế ở Chess, Mushroom, Retail 0,75% và T10I4D100K, peak RSS của hai miner
chênh nhau không quá 12 MB. Chênh lệch rõ chỉ xuất hiện ở hai cấu hình:

- **Accidents 80%:** baseline đạt 665,6 MB, bitset 433,4 MB. Baseline tăng
  305,9 MB trong lúc mining. Mỗi TID-list ở đây dài khoảng 300 nghìn phần tử
  (2,4 MB), và mỗi phép giao ở DFS tạo thêm một danh sách dài gần như vậy.
  Bitset không đẩy được đỉnh vượt mức đã có trước mining.
- **Retail 0,1%:** bitset đạt 386,3 MB, baseline 314,3 MB; delta bitset 129,2
  MB so với 56,0 MB. Ngoài 23,5 MB mask ở gốc, mỗi phép giao trong
  `_bitset_dfs!` cấp một mask mới dài đủ N = 88.162 bit (khoảng 11 KB), kể cả
  khi kết quả chỉ có vài trăm bit 1 hoặc bị loại vì không đủ support; TID-list
  con thì ngắn theo support. Đây là giải thích từ cấu trúc code và số đo, chưa
  phải kết quả profile cấp phát từng pha.

Ở các ô "—" (Chess, Mushroom, Accidents bản bitset; một lần Mushroom bản
baseline), mining không làm đỉnh tiến trình tăng, nên chỉ kết luận được phần
mining dùng không vượt đỉnh đã có lúc khởi động/đọc dữ liệu.

**Thời gian mining.** Bitset nhanh hơn baseline ở cả sáu cấu hình khi chỉ đo
lời gọi hàm: khoảng 146 lần ở Chess, 26 lần ở Mushroom, 4,6 lần ở Accidents,
6,5 lần ở T10I4D100K, 2,0 lần ở Retail 0,75%, nhưng chỉ 1,25 lần ở Retail 0,1%.
Retail 0,1% cũng là chỗ bitset tốn bộ nhớ hơn; cả hai cùng xuất phát từ việc
mask luôn dài N trong khi phần lớn item rất hiếm.

**Tóm lại**, bitset là tối ưu cả về tốc độ và bộ nhớ trên dữ liệu mà các item
phổ biến có support tương đối cao (Chess, Mushroom, Accidents). Trên dữ liệu
thưa ở minsup thấp (Retail 0,1%), bitset vẫn nhanh hơn baseline một chút
nhưng tốn bộ nhớ hơn rõ rệt. Đây không phải tối ưu bộ nhớ cho mọi input.

## Giới hạn

- Peak RSS là của cả tiến trình; delta RSS có thể gồm rác chưa được GC thu
  gom, nên là cận trên thô của phần mining, không phải số byte thuật toán thực
  sự cần.
- `summarysize` chỉ đo cấu trúc item đơn ở gốc, là cận dưới; không gồm các lớp
  con trong DFS và output.
- 3 lần đo mỗi cấu hình, chỉ ở một minsup cho mỗi CSDL (Retail hai mức); không
  suy rộng sang mọi minsup.
- Một máy, một phiên bản Julia, khác máy đo runtime. Thời gian ở đây là lời gọi
  hàm mining, không phải thời gian toàn trình như phần runtime.
- `environment.toml` của run không có cờ `complete`; script vẽ coi run là hoàn
  tất khi đủ mọi cấu hình và đủ số lần lặp, và dừng nếu thiếu.

Tái lập: `julia --project experiments/run_memory_real.jl` (khoảng 5 phút trên máy đo),
sau đó `python experiments/plot_memory_real.py <thư mục run>`.
