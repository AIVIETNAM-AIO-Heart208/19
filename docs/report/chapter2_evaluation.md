# Đánh giá tổng hợp, hướng tối ưu và kết luận Chương 2

Phần này tổng hợp số liệu đã đo ở [runtime_benchmarks.md](runtime_benchmarks.md),
[correctness_benchmarks.md](correctness_benchmarks.md), [scalability.md](scalability.md)
và [memory_benchmarks.md](memory_benchmarks.md).
Trong các bảng so sánh, “Julia” chỉ Eclat BitVector của nhóm, "SPMF" là
Eclat trong SPMF 2.65. So sánh thời gian với SPMF luôn là thời gian **toàn
trình** (khởi động, đọc, mining, ghi) trong run `runtime_20261117T101543270`.

## Điểm mạnh và điểm yếu so với SPMF

### Điểm mạnh

**1. Kết quả đúng hoàn toàn.** Cả 35/35 cấu hình (5 CSDL × 7 minsup) khớp từng
itemset và support với SPMF. Ngoài ra cả baseline và bitset khớp SPMF trên 27
case kiểm thử nhỏ trong `test/`.

**2. Thời gian tăng chậm khi output lớn trên dữ liệu dày.** Trên Chess, khi hạ
minsup từ 90% xuống 60%, số itemset tăng khoảng 410 lần (622 → 254.944).
Median Julia chỉ tăng từ 1,469 lên 1,948 giây, còn SPMF tăng từ 0,372 lên
7,769 giây. So phần tăng thêm (không bị chi phí cố định của mỗi lần chạy làm
lệch): Julia tăng thêm 0,48 giây, SPMF tăng thêm 7,40 giây. Julia chậm hơn
ở 90–75% nhưng nhanh hơn từ 70% trở xuống (gấp 3,99 lần ở 60%). Trên
Accidents, Julia nhanh hơn ở cả bảy mức, từ 1,81 lần (95%) đến 5,32 lần (65%), và thời gian Julia gần như không đổi (2,73–3,05
giây) trong khi SPMF tăng từ 5,29 lên 15,26 giây (không đơn điệu: 5,25 giây
ở 90%).

Lý giải theo thuật toán: các CSDL này có ít item phổ biến (Chess 75%: 23 item;
Accidents 80%: 11 item) nhưng support rất cao, khoảng 91% số giao dịch. Một
phép giao hai mask là AND trên `ceil(N/64)` từ máy 64 bit, chi phí không phụ
thuộc support; trong khi giao hai TID-list tốn `O(|a| + |b|)`, tức tỉ lệ với
support. Support càng cao, mask càng có lợi. Phần bộ nhớ cho thấy mask cũng
gọn hơn TID-list 70–99 lần trên hai CSDL này. Đây là lập luận về bản của
nhóm; không suy ra cách SPMF cài đặt bên trong.

**3. Có bằng chứng tối ưu trên dữ liệu thật.** Khi chỉ đo lời gọi hàm mining,
bitset nhanh hơn baseline của nhóm ở cả sáu cấu hình đo bộ nhớ (từ 1,25 lần ở
Retail 0,1% đến khoảng 146 lần ở Chess 75%) và giảm peak RSS ở Accidents 80%
từ 665,6 xuống 433,4 MB.

### Điểm yếu

**1. Thời gian toàn trình ở các cấu hình nhẹ.** Ở các cấu hình nhỏ, median
toàn trình của Julia không xuống dưới khoảng 1,37 giây (thấp nhất 1,374 giây,
Chess 80%), còn SPMF chỉ khoảng 0,37 giây (Chess 90%, Mushroom 50–60%). Vì
vậy SPMF nhanh hơn ở mọi mức cao của Chess và cả dải Mushroom (tỉ lệ
SPMF/Julia từ 0,25 tăng dần lên 0,84 khi hạ minsup). Ở phép đo bộ nhớ, riêng
lời gọi mining bitset trên Chess 75% chỉ mất 0,0086 giây và trên Mushroom 30%
0,0075 giây, trong khi toàn trình ở cùng cấu hình là 1,404 và 1,380 giây.
Thời gian toàn trình bao gồm cả khởi động Julia, biên dịch JIT và đọc, ghi
dữ liệu. Hai thí nghiệm chạy trên hai máy khác nhau, nên muốn định lượng
đóng góp của từng pha cần đo chúng trên cùng một máy.

**2. Dữ liệu thưa, minsup thấp.** SPMF nhanh hơn ở cả 7 mức của Retail và
T10I4D100K. Chênh lệch lớn nhất xuất hiện ở Retail 0,1%: Julia 10,634 giây, SPMF 1,435 giây
(SPMF nhanh hơn khoảng 7,41 lần), dù chỉ có 7.589 itemset. Retail 0,1% có
2.117 item phổ biến, nên ngay mức gốc `_bitset_dfs!` thử
`2117 × 2116 / 2 = 2.239.786` phép giao. Mỗi phép giao là AND trên mask dài đủ
N = 88.162 bit (1.378 từ máy) và cấp một mask mới, dù các item này chỉ có
support trung bình 0,36% (khoảng 313 giao dịch). Phần lớn công sức là xử lý
các bit 0. Số ứng viên bị loại có thể ước tính từ kết quả. Có 7.589 − 2.117 =
5.472 itemset dài từ 2 trở lên, nên có nhiều nhất 5.472 cặp phổ biến, tức ít
nhất 99,7% trong 2.239.786 phép giao ở gốc cho kết quả bị loại (nhưng vẫn
được cấp mask).

**3. Bitset không tối ưu bộ nhớ trên dữ liệu thưa.** Cũng ở Retail 0,1%, cấu
trúc mask ở gốc lớn gấp 2,4 lần TID-list (23,5 MB so với 9,9 MB), peak RSS
bitset 386,3 MB so với baseline 314,3 MB. Với TID-list `Int64` cấp vừa đủ,
ngưỡng hòa vốn lý thuyết của phần dữ liệu là khoảng N/64 giao dịch cho mỗi
item (support tương đối 1,56%). Khi dựng list bằng `push!`, dung lượng dự
phòng quan sát được cho ngưỡng ước tính khoảng 0,8–1,1%.
[Phân tích kích thước cấu trúc dọc](memory_benchmarks.md).

**4. Mật độ toàn CSDL không đủ để dự đoán.** Cùng là Retail (thưa), tỉ lệ cấu
trúc dọc TID-list / mask đi từ 2,67 ở minsup 0,75% (mask gọn hơn) xuống 0,42 ở
minsup 0,1% (mask tốn hơn). Yếu tố quyết định là minsup và support của các
item còn lại sau khi lọc, không phải nhãn dense/sparse của cả CSDL. Ở
scalability, Accidents (minsup 75%) tăng gần tuyến tính theo N (T/N
0,550–0,569 µs/giao dịch), còn Retail (minsup 0,1%) dao động (98–177
µs/giao dịch). Khác biệt này đi kèm số item phổ biến rất khác nhau: khi dùng
100% số giao dịch, Retail có 2.117 singleton phổ biến, Accidents chỉ 14
([scalability.md](scalability.md)). Hai bộ chạy ở minsup khác nhau, nên đây là
tương quan, chưa phải phép thử có kiểm soát. Ngoài ra T10I4D100K thưa nhưng ở
minsup 0,1% vẫn sinh itemset dài đến 10 item, nên độ dài pattern cũng không
suy ra được từ nhãn thưa.

## Hai hướng tối ưu đề xuất

Cả hai đều chỉ là đề xuất, nhóm chưa cài đặt và chưa đo.

### Hướng 1: chọn TID-list hay bitset theo support của từng nút

**Vấn đề.** Bản hiện tại dùng mask N bit cho mọi nút, kể cả nút có support rất
thấp. Điểm yếu 2 và 3 ở trên đều xuất phát từ đây.

**Cách làm.** Khi tạo một nút (item đơn ở gốc hoặc kết quả một phép giao trong
DFS), chọn cách lưu theo support s của nút:

- `s ≥ N/64`: lưu mask (BitVector), như hiện nay;
- `s < N/64`: lưu TID-list đã sắp. Có thể dùng `Int32` thay `Int64` vì N của
  mọi benchmark nhỏ hơn 2^31, giảm nửa bộ nhớ list (ngưỡng chuyển khi đó là
  N/32).

Cần ba kiểu giao: mask & mask (AND từng từ máy), list ∩ list (trộn hai danh
sách đã sắp, như baseline), và list ∩ mask (với mỗi TID trong list, kiểm tra
bit tương ứng, chi phí `O(|list|)`). Kết quả giao có support không lớn hơn
input, nên một nhánh chỉ đi từ mask sang list, không cần chuyển ngược. Với hai mask, có thể đếm số bit 1 của phép AND trước và chỉ cấp
mask mới khi đủ support, để các ứng viên bị loại không cấp bộ nhớ.

**Lý do kỹ thuật và căn cứ số liệu.** Ngưỡng N/64 rút ra từ hai công thức kích
thước đã kiểm chứng: list tốn `8s` byte, mask tốn khoảng `N/8` byte. Sáu cấu
hình đo bộ nhớ đều khớp ngưỡng này. Với Retail 0,1%, support trung bình 0,36%
nằm dưới ngưỡng, nên hầu hết item sẽ được lưu dạng list: cấu trúc gốc còn tối
đa khoảng 5,3 MB (`Int64`) hoặc 2,7 MB (`Int32`; là cận trên vì các item có
support ≥ N/64 sẽ thành mask và còn nhỏ hơn), thay vì 23,5 MB. Hai số
này giả định list được cấp đúng kích thước (đếm support trước rồi mới cấp);
nếu dựng bằng `push!` như baseline hiện tại thì số đo là 9,9 MB.

Trên dữ liệu dày, bản lai **giữ nguyên biểu diễn**: mọi nút được giữ lại đều
có support ≥ minsup, nên khi minsup ≥ N/64 (khoảng 1,56%) thì mọi nút vẫn là
mask như bản hiện tại. Trong dải runtime đã đo, Chess (thấp nhất 60%), Mushroom
(15%) và Accidents (65%) đều thuộc trường hợp này. (Chi tiết đếm bit 1 trước
khi cấp mask là thay đổi riêng, áp cho mọi cấu hình.) Việc chọn list hay mask
chỉ có tác dụng ở các cấu hình có minsup dưới 1,56%: Retail và T10I4D100K từ
1,5% trở xuống. Trong 25 cấu hình Julia chạy chậm hơn SPMF, 12 cấu hình có minsup dưới
ngưỡng này. Ở 13 cấu hình còn lại, mọi nút phổ biến vẫn dùng mask. Ảnh hưởng tới thời gian trên Retail
cần đo lại: giao list ∩ list tốn khoảng `|a| + |b|` phép so sánh (trung bình
khoảng 630) thay vì 1.378 từ máy, nhưng phép trộn có rẽ nhánh nên chưa chắc
nhanh hơn tương ứng.

### Hướng 2: diffset (dEclat) để thu gọn TID-list trên dữ liệu dày

**Vấn đề.** Trên Accidents 80%, TID-list của mỗi item phổ biến dài khoảng
300 nghìn phần tử (support trung bình 90,7% của 340.183 giao dịch). Baseline
tăng 305,9 MB RSS trong lúc mining, vì mỗi phép giao lại tạo một danh sách dài
gần như vậy.

**Cách làm.** Theo Zaki và Gouda (2003, *Fast Vertical Mining Using Diffsets*,
KDD'03, tr. 326–335, mục 3.1 và 4.1), thay vì lưu tập giao dịch **chứa**
itemset, lưu tập giao dịch **bị mất** so với nút cha. Với hai nút anh em PX và
PY cùng tiền tố P:

- `d(PXY) = t(PX) \ t(PY)` (giao dịch có PX nhưng không có Y);
- `σ(PXY) = σ(PX) − |d(PXY)|`;
- ở mức sâu hơn, `d(PXYZ) = d(PXZ) \ d(PXY)`, không cần quay lại tidset.

**Lý do kỹ thuật.** Khi support gần 100%, phần bị mất rất nhỏ: một item có
support 90,7% thì diffset so với toàn CSDL chỉ khoảng 9,3% số giao dịch, ngắn
hơn tidset gần 10 lần. Phép hiệu hai danh sách đã sắp có cùng chi phí trộn
`O(|a| + |b|)` như phép giao, nên thời gian cũng giảm theo độ dài. Ngược lại,
trên dữ liệu thưa diffset có thể dài hơn tidset, nên chỉ chuyển sang diffset
khi support của nút đạt ít nhất một nửa support của nút cha (khi đó
`|d| ≤ |t|`; bài báo gọi đây là điều kiện reduction ratio ≥ 1, mục 4.1).

**Phạm vi và quan hệ với Hướng 1.** Hướng này cải thiện **cách lưu TID-list
trên dữ liệu dày**, tức baseline của nhóm; nó nhắm điểm yếu đo được là baseline
tăng 305,9 MB khi mining trên Accidents 80%. Với bản bitset, lợi ích không
rõ: diffset lưu dạng list chỉ nhỏ hơn mask khi `|d| < N/64`. Ở mức item đơn
của Accidents 80%, `|d|` khoảng 9,3% của N, nên list diffset tốn khoảng `0,74N`
byte, vẫn lớn hơn mask (`N/8 = 0,125N` byte) khoảng 6 lần. Ở các mức sâu hơn,
diffset có thể co lại rất nhanh (Zaki và Gouda, Hình 10–11) và khi đó có thể
nhỏ hơn mask; nhóm chưa đo điều này. Với bản bitset, Accidents cũng không phải
điểm yếu (Julia đã nhanh hơn SPMF ở cả bảy mức).

Trong phương án lai dùng TID `Int64`, nút có support cao được lưu bằng mask,
còn nút dùng TID-list có ít hơn N/64 phần tử. Số liệu hiện có chưa cho phép
ước tính lợi ích của việc kết hợp thêm diffset vào phương án này.

## Kết luận Chương 2

- **Đúng đắn:** 35/35 cấu hình trên 5 CSDL benchmark khớp SPMF từng itemset và
  support (bảng ở [correctness_benchmarks.md](correctness_benchmarks.md)), cùng
  với 27 case kiểm thử nhỏ cho cả hai miner.
- **Runtime theo minsup:** bản bitset nhanh hơn SPMF ở 10/35 cấu hình (Chess
  70–60% và toàn bộ Accidents), chậm hơn ở 25/35. SPMF có ưu thế ở tác vụ nhỏ
  (median toàn trình của Julia khoảng 1,4 giây ở Chess 75% và Mushroom 30%)
  và ở dữ liệu thưa có nhiều item phổ biến.
- **Số itemset theo minsup:** không giảm khi hạ minsup ở cả 5 CSDL; mức tăng
  phụ thuộc mạnh vào dữ liệu (Chess tăng 410 lần, Accidents 73 lần trong dải
  đã chọn).
- **Scalability:** Accidents ở 75% tăng gần tuyến tính theo số giao dịch;
  Retail ở 0,1% tăng nhưng T/N dao động, chưa đủ để kết luận tuyến tính.
  Tăng độ dài giao dịch (L từ 8 lên 24) làm runtime tăng khoảng 25,7 lần, có
  bước nhảy khi xuất hiện cặp item phổ biến.
- **Bộ nhớ:** peak RSS phần lớn là runtime Julia cùng dữ liệu đã đọc (236–380
  MB trước khi mining; Accidents cao hơn hẳn chính vì dữ liệu lớn).
  Bitset nhanh hơn baseline ở cả 6 cấu hình đo. Cấu trúc dọc ở gốc của
  bitset nhỏ hơn ở 5/6 cấu hình. Chênh lệch peak RSS có lợi cho bitset
  lớn nhất ở Accidents 80% (433,4 so với 665,6 MB). Ở Retail 0,1%, bitset
  dùng nhiều bộ nhớ hơn baseline ở cả cấu trúc gốc và peak RSS.
- **Hướng tiếp theo:** chọn TID-list hay bitset theo support từng nút (nhắm
  điểm yếu đo được ở Retail 0,1%: chậm hơn SPMF và tốn bộ nhớ hơn baseline);
  hoặc, nếu giữ biểu diễn TID-list, dùng diffset để thu gọn TID-list trên dữ
  liệu dày, nơi baseline tăng 305,9 MB RSS trong lúc khai phá Accidents ở
  minsup 80%.

## Giới hạn của phần tổng hợp

Số liệu runtime và bộ nhớ đo trên hai máy khác nhau (Ryzen 7 7735HS, Julia
1.11.4 và Ryzen 7 5800H, Julia 1.11.9); các so sánh chéo giữa hai phép đo chỉ
dùng để ước lượng độ lớn. Các nhận định về nguyên nhân dựa trên cấu trúc code
và công thức kích thước, chưa có profile từng pha. So sánh với SPMF chỉ là
thời gian toàn trình trên một máy, median 5 lần, không kiểm định thống kê và
không suy ra cách SPMF cài đặt bên trong.
