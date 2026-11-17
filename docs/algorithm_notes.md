# Eclat baseline — Goal 1

## Bài báo đã đọc

Mohammed J. Zaki, “Scalable Algorithms for Association Mining”, IEEE TKDE,
12(3), 372–390, 2000. DOI: https://doi.org/10.1109/69.846291.
[PDF tại Đại học Granada](https://sci2s.ugr.es/keel/pdf/algorithm/articulo/2000%20-%20IEEETKDE%20-%20Zaki%20-%20%28Eclat%29%20ScalableAlgorithms%20for%20Association%20Mining%20.pdf).
Đã đọc Support Counting (4.1), phân lớp prefix (4.2), Bottom-Up Search
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

## API bàn giao cho B

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

`eclat` gọi baseline thật; stub đã gỡ, src/ không include oracle.
`eclat_bitset` báo chưa triển khai. Khi làm Goal 2: thêm bản thật vào
IMPLEMENTED_MINERS, bỏ test pending, áp dụng API tests cho bitset và chạy lại
cùng fixtures. Chưa có đo hiệu năng hoặc tuyên bố tối ưu.

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

## Kiểm chứng

Lệnh: `julia --project test/runtests.jl`.
Ngày 17/11/2026 đã chạy bằng Julia 1.11.4 portable trên Windows, startup file tắt:
1950 pass, 0 fail/error, 2 skip. Baseline khớp 27/27 case trên 7 file đầu vào,
tổng 552 itemset/support tham chiếu. Tests giữ đủ case, >=5 CSDL.
Bao gồm API biên, aliasing, hơn 20 item, oracle seed 20261117 và vét cạn
mọi CSDL 3 giao dịch trên 3 item [0, 7, typemax(Int)] ở ngưỡng 1–3:
8^3 × 3 = 1536 phép so sánh với oracle.

Hai skip là bitset thuộc Goal 2 và test symlink do Windows không cho tạo liên kết.
Baseline không bị skip. Module nạp/precompile không cảnh báo ghi đè method,
`Test.detect_ambiguities(EclatMining; recursive=true)` trả rỗng.
CLI chạy trong tiến trình riêng trên toy @40% trả 15 mẫu, so với fixture SPMF
khớp 100%, thiếu/thừa/sai support đều bằng 0. Không chạy lại Java SPMF trong
lần kiểm tra này; fixtures tham chiếu được giữ nguyên.

Không phát hiện lỗi trong phạm vi trên; kiểm thử hữu hạn không bảo đảm mọi input
đều không có lỗi. Chưa kiểm chứng hiệu năng hoặc giới hạn tài nguyên ở benchmark lớn.
