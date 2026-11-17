# Cài đặt Eclat: baseline và bitset

## Cơ sở thuật toán

Mohammed J. Zaki, “Scalable Algorithms for Association Mining”, IEEE TKDE,
12(3), 372–390, 2000. DOI: https://doi.org/10.1109/69.846291.
[PDF tại Đại học Granada](https://sci2s.ugr.es/keel/pdf/algorithm/articulo/2000%20-%20IEEETKDE%20-%20Zaki%20-%20%28Eclat%29%20ScalableAlgorithms%20for%20Association%20Mining%20.pdf).
Các phần làm cơ sở: Support Counting (4.1), phân lớp prefix (4.2), Bottom-Up Search
trong phần 5 (Fig. 12). Áp dụng giao tid-list và mở rộng lớp bằng đệ quy.
Bản này bắt đầu từ singleton trong bộ nhớ, không tái tạo toàn bộ pipeline I/O.
Không tham khảo mã nguồn SPMF hay implementation FIM khác.

## Dữ liệu và tìm kiếm

Chỉ số giao dịch là TID, từ 1. Giao dịch trùng nhau có TID khác nhau;
giao dịch rỗng vẫn có TID. `vertical::Dict{Int,Vector{Int}}` lưu TID-set tăng dần.
Lớp DFS là `Vector{Pair{Int,Vector{Int}}}`: với prefix P, phần tử `x => tids`
lưu **T(P ∪ {x})**. Support tuyệt đối là `length(tids)`.

```text
validate(db, threshold)
vertical = dựng TID-set theo thứ tự giao dịch
extensions = singleton đủ support, sắp theo item tăng dần
DFS(prefix, extensions):
    với mỗi (x, Tx) tại vị trí i:
        thêm x vào prefix
        lưu copy(prefix) => |Tx|
        children = rỗng
        với mỗi (y, Ty) phía sau i:
            common = giao_hai_con_trỏ(Tx, Ty)
            nếu |common| >= threshold: thêm y => common vào children
        DFS(prefix, children) nếu children khác rỗng
        bỏ x khỏi prefix
```

Ví dụ `db = [[1, 2], [1], [1, 2]]`, ngưỡng 2:
T(1) = [1, 2, 3], T(2) = [1, 3], T(1, 2) = [1, 3].
Output DFS: `[1] => 3`, `[1, 2] => 2`, `[2] => 2`.
Phép giao dịch con trỏ ở giá trị nhỏ hơn; khi bằng nhau ghi một TID và dịch cả hai.

## Tính đúng

Bất biến T(Px) đúng ở singleton. Giao T(Px) và T(Py) cho T(Pxy), nên
support đúng ở mọi tầng. Chỉ mở rộng về phía sau cho một đường sinh duy nhất.
Mọi tập con của tập phổ biến đều phổ biến nên các prefix cần thiết không bị
loại: không bỏ sót. Phép giao không tăng support, do đó nhánh thiếu support
không thể có tập mở rộng phổ biến. So ngưỡng dùng >=, kể cả tại đúng biên.
Mỗi output lưu copy(prefix), không chia sẻ vector với input hoặc mẫu khác.
Sort singleton và giữ thứ tự lớp con làm thứ tự kết quả xác định.

## Giao diện lập trình và hợp đồng dữ liệu

```julia
eclat_baseline(db::Vector{Vector{Int}}, minsup_abs::Int)::Vector{Pair{Vector{Int},Int}}
```

- Item không âm (kể cả 0, ID không liên tiếp); từng giao dịch tăng nghiêm ngặt.
- Item âm, chưa sort hoặc trùng: ArgumentError; không tự sửa db.
- Ngưỡng âm: ArgumentError. Db khác rỗng với ngưỡng 0: ArgumentError.
- Db rỗng với ngưỡng không âm: vector rỗng đúng kiểu.
- Db chỉ có giao dịch rỗng hoặc ngưỡng vượt số giao dịch: không có mẫu.
- Validation một lần, kể cả trước khi trả sớm vì ngưỡng quá lớn.
- Chuyển ngưỡng tương đối thuộc src/io.jl; lõi chỉ nhận support tuyệt đối.
- Output chứa mọi tập phổ biến khác rỗng, mỗi tập một lần.

```julia
using EclatMining
db = read_spmf("test/fixtures/transactions/toy.txt")
patterns = eclat_baseline(db, minsup_abs("40%", length(db)))
write_spmf("out.txt", patterns)
```

`eclat` hiện gọi `eclat_bitset`; baseline vẫn giữ API riêng làm mốc so sánh.
Oracle chỉ phục vụ kiểm thử, không được gọi từ src/. Cả hai bản chạy chung correctness và API tests.

## Độ phức tạp và giới hạn

N là số giao dịch, M tổng số item xuất hiện, U số item phân biệt,
F số singleton phổ biến, D độ sâu DFS. Validation O(N+M), dựng dữ liệu dọc
O(N+M) kỳ vọng với hash lookup, lọc O(U), sort O(F log F).
Giao a,b tốn O(|a|+|b|) thời gian, O(min(|a|,|b|)) bộ nhớ kết quả.
Tổng mining phụ thuộc tổng chi phí các phép giao đã thử và tổng độ dài output.
Có thể có 2^F-1 mẫu: thời gian và output có thể tăng theo hàm mũ.
Bộ nhớ gồm dữ liệu dọc O(U+M), prefix/stack O(D), các lớp còn sống trên stack,
và output O(sum(|X|+1) trên mọi mẫu X). Nếu lớp ở độ sâu d có Ld phần mở rộng,
cận thô TID-set đang sống là O(N × sum(Ld)); không giữ toàn bộ cây tìm kiếm.
Output lớn có thể cạn RAM; đệ quy rất sâu có thể chạm giới hạn stack.
Không áp giới hạn nhân tạo 20 item hoặc cắt độ dài mẫu.

## Kiểm chứng tính đúng

Julia 1.11.4, Windows, ngày 17/11/2026: 3825 pass, 0 fail/error,
1 skip do Windows không cho tạo symlink. Không skip baseline hoặc bitset.
Mỗi bản khớp 27/27 case SPMF, 7 CSDL, 552 itemset/support. Fixtures giữ nguyên;
không chạy lại Java SPMF. API, aliasing, oracle ngẫu nhiên và vét cạn chạy cả hai bản.
Tests bổ sung ranh giới 1,63,64,65,127,128,129 giao dịch, mask đầy/rỗng,
TID ở đầu/cuối và biên word. Module nạp không cảnh báo ghi đè; không có method
ambiguity. CLI trong tiến trình riêng khớp toy @40% đủ 15 mẫu.

## Bitset: thiết kế và tính đúng

BitVector có N bit, bit thứ t bằng true khi giao dịch t chứa itemset.
Code dùng `falses(N)`, `mask .& next_mask` và `count(mask)` qua API công khai;
không truy cập .chunks. Tham khảo [tài liệu BitArray Julia](https://docs.julialang.org/en/v1/base/arrays/#Base.BitArray).
API đóng gói nhiều giá trị boolean vào word. Đã xác nhận trên runtime 1.11.4
phép AND trả BitVector. Không đọc implementation FIM bên ngoài.

Đếm singleton trước để chỉ cấp mask cho item phổ biến; một mask cho mỗi item,
không cấp lại khi item xuất hiện trong giao dịch khác. Mỗi mask độc lập.
DFS giữ bất biến T(Px) như baseline; phép AND tạo mask mới nên không sửa cha
hoặc nhánh anh em. Support bằng số bit true; các bit ngoài N không được đếm.
Prefix được copy khi lưu output. Hai bản có cùng validation và thứ tự sinh.

Dựng bitset: validation/đếm/gán O(N+M) kỳ vọng, khởi tạo mask
O(F × ceil(N/w)), sort O(F log F), w là số bit trong word (64 trên máy đo).
Mỗi AND và đếm support có chi phí theo ceil(N/w), không theo số TID có mặt.
Do đó TID-list ngắn trên dữ liệu sparse có thể lợi hơn; bitset vẫn quét word
và cấp mask cho các giao thất bại. Bộ nhớ dọc khoảng F×ceil(N/8) byte dữ liệu
bit, cộng overhead, counts O(U), lớp DFS còn sống và output. Chi phí output
và giới hạn hàm mũ/stack vẫn tồn tại. Không suy ra mọi dataset đều nhanh hơn.

## Phương pháp đo tối ưu hóa

Chưa có benchmark thật trong data/datasets.toml. Dùng hai CSDL tổng hợp Bernoulli,
seed 42, cấu hình đầy đủ ở experiments/configs/optimization.toml. Mỗi giao dịch thử độc
lập từng item với xác suất p. Dense: N=12000, U=24, p=.6; sparse: N=20000,
U=500, p=.01. Không chọn lại seed để tạo kết quả thuận lợi, không trộn pilot.
Đây là đánh giá tối ưu hóa, chưa hoàn thành benchmark Chương 2.

Mỗi case kiểm tra hai output khớp từng mẫu/support trước khi đo. Runtime gồm
validation, dựng dữ liệu dọc, DFS và tạo đầy đủ output; không gồm sinh input,
I/O hoặc correctness. Gọi cả hai trên input đo để warm-up JIT, giải phóng output,
7 lần đo, luân phiên thứ tự, GC trước mỗi mẫu ngoài vùng đo. Báo median/IQR;
allocated bytes lấy từ @timed của cùng lời gọi, không gọi đó là peak RAM.

Peak RAM: 3 worker mới cho mỗi miner/case, chỉ một lời gọi lớn, warm-up bằng
3 giao dịch, GC trước mining. Worker không chạy miner kia hoặc vòng đo allocation.
Sys.maxrss() trả byte (xác nhận docstring trong Julia 1.11.4 base/sysinfo.jl).
Đó là đỉnh toàn tiến trình, gồm Julia/JIT, input generation, input và output;
không phải bộ nhớ riêng thuật toán. Không lấy hiệu maxrss để suy ra bộ nhớ lõi.
Số liệu raw và median giữ nguyên, không báo khác biệt nhỏ là chắc chắn có ý nghĩa.

Môi trường, commit + dirty=true và cấu hình lưu ở
results/metrics/optimization_runtime_environment.toml và optimization_memory_environment.toml. Không thêm dependency benchmark.

Chạy lại từ repo root (Julia trong PATH):

```powershell
julia --startup-file=no --threads=1 --project=. test/runtests.jl
julia --startup-file=no --threads=1 --project=. experiments/run_runtime.jl
julia --startup-file=no --threads=1 --project=. experiments/run_memory.jl
julia --startup-file=no --threads=1 --project=. experiments/summarize_optimization.jl
```

Nếu Julia chưa có trong PATH, dùng đường dẫn đến julia.exe đã cài trên máy.
Ví dụ PowerShell (thay đường dẫn dưới đây bằng đường dẫn thực tế):

```powershell
$juliaExe = 'C:/Tools/Julia/bin/julia.exe'
& $juliaExe --startup-file=no --threads=1 --project=. test/runtests.jl
```
Các script ghi đè file kết quả đo tương ứng khi chạy lại.

## Kết quả đo thực tế

Bảng dưới dùng ms và MiB (2^20 byte); peak RAM là median của 3 tiến trình.
IQR runtime và từng lần đo nằm trong CSV raw/summary, không dùng assertion tốc độ.

| Dữ liệu / minsup | Số mẫu | Baseline / bitset (ms) | Speedup | Allocated baseline / bitset (MiB) | Peak RSS baseline / bitset (MiB) |
|---|---:|---:|---:|---:|---:|
| synthetic_dense / 20% | 2324 | 394.13 / 12.54 | 31.43x | 368.96 / 21.43 | 301.64 / 293.73 |
| synthetic_dense / 35% | 300 | 118.95 / 3.77 | 31.56x | 142.20 / 3.82 | 297.64 / 292.48 |
| synthetic_sparse / 0.5% | 500 | 204.17 / 117.82 | 1.73x | 17.48 / 317.37 | 309.31 / 325.20 |
| synthetic_sparse / 1% | 248 | 53.81 / 20.55 | 2.62x | 7.17 / 78.30 | 308.99 / 305.98 |

Dense: runtime nhanh hơn khoảng 31.4–31.6 lần, allocation giảm rõ. TID-list dense
phải quét nhiều TID cho mỗi giao, trong khi bitset xử lý theo word. Peak process
RAM giảm ít hơn allocation vì chứa runtime, JIT và input.
Sparse: runtime nhanh hơn khoảng 1.7–2.6 lần trong các case này, nhưng allocation
và peak process RAM đều tăng. Nhiều cặp singleton không có giao đủ ngưỡng vẫn
cấp mask đầy chiều dài N. Không thể xem đây là tối ưu bộ nhớ cho mọi input.
Cần đo benchmark thật, nhiều môi trường trước khi tổng quát hóa kết quả.

## Bảo đảm số liệu cùng cấu hình/code

Mỗi loại phép đo ghi metadata riêng sau khi hoàn tất. Metadata lưu SHA-256 của
cấu hình, Project.toml, src/ và các script đo/tổng hợp, môi trường cùng checksum
các CSV. Nếu code/cấu hình thay đổi trong lúc đo, lần chạy không được xác nhận.
Tổng hợp chỉ chạy khi cả hai metadata khớp code/cấu hình/môi trường hiện tại và
CSV còn nguyên vẹn; thiếu file, chạy dở hoặc trộn lần đo khác sẽ báo lỗi.
Khởi động phép đo mới loại bỏ bảng tổng hợp cũ để tránh đọc nhầm kết quả stale.
Cần chạy lại cả runtime và memory nếu thay code/cấu hình/môi trường.
Bảy regression tests dùng file tạm kiểm chứng các trường hợp này.

Bản viết chung Chương 1: [report/chapter1.md](report/chapter1.md). clean_spmf và CLI dùng chung kiểm tra file nguồn/đích; regression tests bảo vệ alias hoa/thường, hard link và đường dẫn tương đương.
