# Chương 1. Cài đặt Eclat

## 1.1. Mục tiêu và cơ sở thuật toán

Nhóm hiện thực Eclat bằng Julia từ mô tả trong bài báo của Mohammed J. Zaki,
“Scalable Algorithms for Association Mining”, IEEE TKDE, 12(3), 372–390, 2000,
DOI: [10.1109/69.846291](https://doi.org/10.1109/69.846291).
Các phần được sử dụng là support counting bằng tid-list, phân lớp theo tiền tố
và bottom-up search đệ quy. Nhóm viết implementation trong bộ nhớ, bắt đầu từ
singleton; không sao chép mã nguồn SPMF hay implementation FIM có sẵn.
[Bản bài báo tham khảo](https://sci2s.ugr.es/keel/pdf/algorithm/articulo/2000%20-%20IEEETKDE%20-%20Zaki%20-%20%28Eclat%29%20ScalableAlgorithms%20for%20Association%20Mining%20.pdf).

Cho CSDL D gồm N giao dịch và itemset X, T(X) là tập chỉ số giao dịch chứa X.
Support tuyệt đối được định nghĩa là sup(X) = |T(X)|. Với ngưỡng tương đối s
thuộc (0,1], implementation sử dụng ngưỡng tuyệt đối θ = ceil(sN). Mục tiêu là
xuất mọi tập X khác rỗng thỏa sup(X) ≥ θ, cùng support của từng tập.

Tính chất nền tảng là T(X ∪ Y) = T(X) ∩ T(Y). Do phép giao không làm tăng
kích thước TID-set, mọi tập mở rộng của một tập không phổ biến cũng không phổ
biến. Thuật toán dùng tính chất này để tỉa nhánh.

## 1.2. Cấu trúc dữ liệu và bản baseline

Dữ liệu ngang có kiểu Vector{Vector{Int}}. Mỗi giao dịch chứa item nguyên không
âm theo thứ tự tăng nghiêm ngặt. Parser chuẩn hóa giao dịch trước khi gọi lõi;
API vẫn kiểm tra hợp đồng để phát hiện input gọi trực tiếp không hợp lệ.
Giao dịch lặp lại được giữ riêng, mỗi dòng giao dịch có TID riêng. Giao dịch
rỗng vẫn tính vào N nhưng không làm tăng support của item nào.

Baseline trong src/algorithm/baseline.jl chuyển dữ liệu thành ánh xạ item tới
Vector{Int} chứa các TID tăng dần. Loại singleton không đủ support, sắp các item
còn lại tăng dần rồi duyệt sâu theo tiền tố (prefix DFS). Một lớp với prefix P
lưu các phần mở rộng x và T(P ∪ {x}).

**Thuật toán 1. Mở rộng lớp tiền tố.**

```text
DFS(P, extensions):
    với mỗi (x, Tx) tại vị trí i:
        thêm x vào P
        xuất bản sao P với support |Tx|
        children = rỗng
        với mỗi (y, Ty) phía sau i:
            common = Tx giao Ty
            nếu |common| ≥ θ: thêm (y, common) vào children
        DFS(P, children) nếu children khác rỗng
        bỏ x khỏi P
```

Phép giao hai danh sách dùng hai con trỏ: dịch con trỏ ở giá trị nhỏ hơn; khi
hai giá trị bằng nhau thì ghi nhận TID một lần và dịch cả hai. Ví dụ D =
[{1,2}, {1}, {1,2}] có T(1)=[1,2,3], T(2)=[1,3]; T(1,2)=[1,3]. Với θ=2,
kết quả là {1}:3, {1,2}:2, {2}:2.

Bất biến của mỗi lớp bảo đảm support đúng qua phép giao. Mỗi tổ hợp chỉ được
mở rộng theo thứ tự item tăng dần nên không sinh hoán vị trùng. Mọi tập con của
một tập phổ biến đều phổ biến, nên các prefix cần thiết không bị tỉa mất.
Vì vậy thuật toán sinh đủ và đúng các tập phổ biến. Prefix được sao chép khi
lưu để các mẫu không dùng chung vector có thể bị sửa ở bước đệ quy sau.

## 1.3. Tối ưu bằng BitVector

Bản optimized trong src/algorithm/optimized.jl giữ cùng cách phân lớp và DFS,
nhưng thay TID-list bằng BitVector có N bit. Bit tại TID t là true khi giao
dịch t chứa itemset. Phép giao dùng mask .& next_mask; support dùng count(mask).
Các thao tác dùng API công khai, không truy cập trường nội bộ .chunks.
Tham khảo [tài liệu BitArray của Julia](https://docs.julialang.org/en/v1/base/arrays/#Base.BitArray).

Trước tiên đếm support singleton, sau đó chỉ cấp mask cho singleton đủ ngưỡng.
Mỗi mask có vùng nhớ riêng; phép AND tạo mask mới, không sửa mask cha hoặc
nhánh anh em. Bất biến và lập luận tính đúng của baseline được giữ nguyên.
Một word đóng gói nhiều TID, giúp giảm chi phí giao khi TID-set dày. Với dữ
liệu thưa, việc cấp và quét mask dài N cho cả các giao thất bại có thể tăng
bộ nhớ so với danh sách TID ngắn; bitset không luôn tốt hơn ở mọi tiêu chí.

## 1.4. API, I/O và giao diện dòng lệnh

Hai API có chung input/output:

```julia
eclat_baseline(db::Vector{Vector{Int}}, minsup_abs::Int)::Vector{Pair{Vector{Int},Int}}
eclat_bitset(db::Vector{Vector{Int}}, minsup_abs::Int)::Vector{Pair{Vector{Int},Int}}
```

Hàm eclat mặc định gọi bitset. Baseline được giữ để kiểm tra và đo so sánh.
Ngưỡng âm bị từ chối; ngưỡng 0 chỉ hợp lệ khi D rỗng. Nếu θ>N thì trả vector
rỗng. Item âm, giao dịch chưa sort hoặc trùng item bị báo ArgumentError.
Hai implementation không sửa input, không cắt output, không dùng oracle của test.

read_spmf đọc file transaction .txt: tách item bằng khoảng trắng, loại BOM,
sort và loại item trùng trong từng dòng; giữ các giao dịch lặp. Bỏ dòng trống
hoàn toàn và dòng metadata/comment bắt đầu bằng @, #, %. Dòng chỉ chứa khoảng
trắng được giữ như giao dịch rỗng theo quy ước fixture SPMF của nhóm.
write_spmf xuất từng dòng dạng `i1 i2 ... #SUP: n`; support là số tuyệt đối.
Thứ tự dòng được chuẩn hóa khi ghi để kết quả ổn định giữa các lần chạy.

parse_minsup nhận tỉ lệ hoặc phần trăm và chuyển thành số hữu tỉ, tránh sai số
Float64 khi tính ceil(sN). Tích số nguyên dùng widemul để tránh tràn Int64 ở
miền input hỗ trợ. Kết quả SPMF trong chương này được kiểm chứng trên các ngưỡng
fixture đã lưu; chưa coi đây là chứng minh mọi biên làm tròn của mọi bản SPMF.

clean_spmf tạo bản dữ liệu chuẩn hóa cho SPMF và trả số giao dịch đã ghi.
Trước khi mở output để ghi, hàm kiểm tra hai đường dẫn có trỏ cùng file không,
bao gồm alias hoa/thường Windows, đường dẫn tương đối, hard link và symlink.
CLI dùng chung kiểm tra này để tránh ghi đè file nguồn do chọn nhầm output.

Ví dụ chạy từ repo root:

```powershell
julia --project=. scripts/run_eclat.jl --input test/fixtures/transactions/toy.txt --output out_toy.txt --minsup "40%"
julia --project=. experiments/spmf/compare.jl out_toy.txt test/fixtures/spmf_expected/toy_40.txt
```

CLI nhận input, output, minsup; kiểm tra tham số thiếu/lặp/lạ, file input và
đường dẫn output trùng nguồn. Toy có 5 giao dịch, θ=2 và 15 tập phổ biến ở 40%.
Thời gian hiển thị của CLI là một lần mining, có thể gồm JIT; không dùng trực
tiếp số đó làm thời gian steady-state của thuật toán.

## 1.5. Thiết kế kiểm thử và correctness

Lệnh kiểm thử: `julia --project=. test/runtests.jl`. Bộ test gồm parser/writer,
ngưỡng support, API, tính độc lập của input/output, CLI, hai thuật toán và tính
nhất quán số liệu thực nghiệm. Mỗi miner được đối chiếu từng itemset và support
với expected SPMF và một oracle vét cạn độc lập trên dữ liệu nhỏ.

**Bảng 1. Dữ liệu và các case đối chiếu SPMF đã lưu.**

| File CSDL | Số case minsup | Tổng itemset tham chiếu qua các case | Baseline | Bitset |
|---|---:|---:|---:|---:|
| dup_items_comments_clean.txt | 3 | 30 | 100% | 100% |
| dup_items_comments_cleaned.txt | 3 | 25 | 100% | 100% |
| dup_tx.txt | 3 | 28 | 100% | 100% |
| rand_dense.txt | 3 | 266 | 100% | 100% |
| rand_sparse.txt | 6 | 122 | 100% | 100% |
| toy.txt | 5 | 73 | 100% | 100% |
| ws_line.txt | 4 | 8 | 100% | 100% |

Bảng 1 có 27 case, 7 file input, tổng 552 itemset qua các ngưỡng; con số này
không phải số mẫu duy nhất của một lần mining. Hai file clean/cleaned là các
biến thể chuẩn hóa; năm CSDL còn lại cung cấp các tình huống kiểm thử khác nhau.
Manifest cases.toml bắt buộc mọi input/expected tồn tại, đủ số case và ≥5 CSDL.
Bộ kiểm thử đối chiếu kết quả với các tệp tham chiếu đã tạo bằng SPMF.

Ngoài fixture, tests có CSDL rỗng, ngưỡng vượt N, giao dịch lặp, item 0 và ID
rất lớn, hơn 20 item, input sai và kiểm tra aliasing. Với mỗi miner, đối chiếu
vét cạn mọi CSDL 3 giao dịch trên 3 item ở θ=1,2,3 (1536 phép so sánh), cùng
40 CSDL ngẫu nhiên seed cố định. Các độ dài 63/64/65 và 127/128/129 kiểm tra biên
word bitset. Regression tests xác nhận clean_spmf giữ nguyên nguồn khi output
là alias và vẫn ghi đúng khi output là file khác.

Kết quả Windows/Julia 1.11.4: **3825 pass, 0 fail/error, 1 skip** do Windows
không cho tạo symlink. Không skip baseline hoặc optimized. Hard link và alias
hoa/thường được kiểm thử thực tế. Tests về symlink sẽ chạy khi nền tảng cho phép.

## 1.6. Độ phức tạp

Gọi M là tổng số item xuất hiện, U số item phân biệt, F số singleton phổ biến.
Validation và dựng TID-list tốn O(N+M) kỳ vọng với hash lookup; sort singleton
O(F log F). Một phép giao danh sách a,b tốn O(|a|+|b|). Khởi tạo bitset cần
O(F ceil(N/w)) word, ngoài bước đếm/gán O(N+M) và lọc O(U); giao/đếm mask có chi
phí theo ceil(N/w), với w=64 trên máy đo.

Tổng thời gian còn phụ thuộc các ứng viên được thử và tổng độ dài output.
Có thể có 2^F-1 tập phổ biến, do đó không thể khẳng định tổng thuật toán tuyến
tính theo N. Bộ nhớ gồm biểu diễn dọc, các lớp còn sống trên stack DFS và output.
TID-list dọc dùng O(M+U); bitset dọc dùng O(F ceil(N/w)) word cộng counts O(U).
Output lớn có thể cạn RAM; đệ quy rất sâu có thể chạm giới hạn stack.

## 1.7. Đo tác động tối ưu hóa

Dùng CSDL Bernoulli tổng hợp với seed 42: dense có N=12000, U=24, p=.6;
sparse có N=20000, U=500, p=.01. Cấu hình ở experiments/configs/optimization.toml.
Hai cấu hình kiểm soát mật độ giao dịch để so sánh baseline với bitset.

Runtime gồm validation, dựng dữ liệu dọc, DFS và vật chất hóa output; loại
sinh input, đọc/ghi file và kiểm tra correctness. Warm-up cả hai trên cùng case,
đo 7 lần, luân phiên thứ tự, GC trước mẫu ngoài vùng đo, báo median/IQR.
Allocated bytes là tổng cấp phát của lời gọi; không đồng nhất với peak RAM.
Peak RSS là median 3 tiến trình mới cho mỗi miner/case, warm-up nhỏ, mỗi worker
chỉ gọi một miner trên input lớn. Đỉnh này gồm Julia/JIT, sinh dữ liệu, input,
output, không phải bộ nhớ riêng lõi thuật toán.

Metadata riêng runtime/memory lưu hash code/cấu hình/môi trường và checksum CSV;
script tổng hợp từ chối các đợt đo không tương thích hoặc file đã thay đổi.
Số liệu raw, độ phân tán và môi trường lưu tại results/metrics/optimization_*.

**Bảng 2. So sánh tối ưu (median), đơn vị ms và MiB = 2^20 byte.**

| Dữ liệu / minsup | Số mẫu | Baseline / bitset (ms) | Speedup | Allocated baseline / bitset (MiB) | Peak RSS baseline / bitset (MiB) |
|---|---:|---:|---:|---:|---:|
| synthetic_dense / 20% | 2324 | 394.13 / 12.54 | 31.43x | 368.96 / 21.43 | 301.64 / 293.73 |
| synthetic_dense / 35% | 300 | 118.95 / 3.77 | 31.56x | 142.20 / 3.82 | 297.64 / 292.48 |
| synthetic_sparse / 0.5% | 500 | 204.17 / 117.82 | 1.73x | 17.48 / 317.37 | 309.31 / 325.20 |
| synthetic_sparse / 1% | 248 | 53.81 / 20.55 | 2.62x | 7.17 / 78.30 | 308.99 / 305.98 |


Ở cả hai cấu hình dữ liệu dày, bitset giảm thời gian chạy và tổng dung lượng cấp phát.
Trên dữ liệu thưa, bitset vẫn chạy nhanh hơn nhưng cấp phát nhiều bộ nhớ hơn. Peak RSS
tăng ở minsup 0,5% và giảm nhẹ ở minsup 1%.

## 1.8. Kết luận

Hai phiên bản Eclat trả về cùng các cặp itemset và support trên 27 trường hợp
đối chiếu với SPMF. TID-list lưu danh sách các giao dịch chứa một itemset, còn
bitset dùng một bit cho mỗi giao dịch. Sự khác biệt này ảnh hưởng đến cả chi phí
phép giao và dung lượng cấp phát. [Thực nghiệm trên năm bộ dữ liệu](memory_benchmarks.md)
đánh giá hai cách biểu diễn ở quy mô lớn hơn.
