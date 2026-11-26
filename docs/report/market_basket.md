# Phân tích giỏ hàng trên UCI Online Retail

## Dữ liệu và đơn vị phân tích

Thí nghiệm tìm các sản phẩm thường được mua cùng nhau để đề xuất cách trưng bày
và bán theo bộ. Dữ liệu [UCI Online Retail](https://doi.org/10.24432/C5BW33)
của Daqing Chen ghi nhận 541.909 dòng hàng của một nhà bán lẻ trực tuyến tại
Anh trong giai đoạn tháng 12/2010 đến tháng 12/2011. Workbook gốc được đối
chiếu SHA-256 trước khi đọc.

Mỗi hóa đơn (`InvoiceNo`) tương ứng với một giỏ. Mỗi mã hàng (`StockCode`)
được tính một lần trong giỏ, kể cả khi khách mua nhiều đơn vị hoặc cùng mã
xuất hiện trên nhiều dòng. Các hóa đơn có cùng tập mặt hàng vẫn là các giao
dịch riêng. Mã được ánh xạ sang ID nguyên theo thứ tự từ điển. Tên hiển thị là
mô tả không rỗng đầu tiên của từng mã trong thứ tự dòng nguồn đủ điều kiện
về hóa đơn, số lượng và đơn giá.

| Bước | Dòng hàng | Hóa đơn | Mã hàng |
|---|---:|---:|---:|
| Dữ liệu nguồn | 541.909 | 25.900 | 4.070 |
| Lọc hóa đơn hủy, mã thiếu, số lượng và đơn giá | 530.104 | 19.960 | 3.922 |
| Bỏ mã phí và điều chỉnh, bỏ giỏ rỗng | 527.794 | 19.775 | 3.914 |

Chương trình loại hóa đơn có tiền tố `C` hoặc `c`, dòng thiếu mã hóa đơn
hoặc mã hàng và dòng có số lượng hoặc đơn giá thiếu, không hợp lệ hay không
dương. Các mã phi hàng hóa được xác định từ mô tả trong workbook gồm `POST`,
`DOT`, `C2` (cước giao hàng), `BANK CHARGES`, `AMAZONFEE` (phí), `M`,
`m` (mục điều chỉnh thủ công) và `B` (điều chỉnh nợ xấu). Bước này loại 2.310
dòng và làm 185 hóa đơn không còn mặt hàng. Hóa đơn `536365` có bảy mã
hàng phân biệt sau lọc. [Thống kê và ví dụ chuyển đổi](../../results/metrics/online_retail_rules.md)

## Khai phá và xếp hạng luật

Eclat BitVector khai phá trên toàn bộ 19.775 giỏ. Minsup **1%** tương ứng
ngưỡng **198 giỏ** và trả về **2.007 itemset phổ biến**. Với mỗi itemset có
ít nhất hai phần tử, chương trình xét các cách tách thành hai vế có hướng.
Giữ **956 luật** đạt minconf **50%**.

Gọi (N) là số giỏ và (n(S)) là số giỏ chứa toàn bộ tập (S). Support của
luật (X → Y) là (n(X∪Y)/N). Confidence là (n(X∪Y)/n(X)). Lift là
confidence chia cho tần suất nền (n(Y)/N). Bảng xếp giảm dần theo lift,
confidence và số giỏ chứa đồng thời. Hai vế được dùng để phân định các luật
còn hòa theo thứ tự từ điển của ID. Phép lọc và sắp xếp dùng giá trị chính
xác. Số lẻ chỉ được làm tròn khi hiển thị. Chương trình kiểm tra lại ba số
đếm của từng luật trong bảng bằng cách duyệt trực tiếp các giỏ.

**Bảng 1. Mười luật có lift cao nhất trên UCI Online Retail**

| Hạng | Vế trái | Vế phải | Giỏ chứa cả hai | Support | Confidence | Lift |
|---:|---|---|---:|---:|---:|---:|
| 1 | HERB MARKER ROSEMARY [22917] + HERB MARKER PARSLEY [22918] | HERB MARKER THYME [22916] | 203 | 1.0265% | 94.4186% | 78.7818 |
| 2 | HERB MARKER THYME [22916] | HERB MARKER ROSEMARY [22917] + HERB MARKER PARSLEY [22918] | 203 | 1.0265% | 85.654% | 78.7818 |
| 3 | HERB MARKER THYME [22916] + HERB MARKER PARSLEY [22918] | HERB MARKER ROSEMARY [22917] | 203 | 1.0265% | 95.3052% | 78.5275 |
| 4 | HERB MARKER ROSEMARY [22917] | HERB MARKER THYME [22916] + HERB MARKER PARSLEY [22918] | 203 | 1.0265% | 84.5833% | 78.5275 |
| 5 | HERB MARKER THYME [22916] + HERB MARKER BASIL [22920] | HERB MARKER ROSEMARY [22917] | 200 | 1.0114% | 95.2381% | 78.4722 |
| 6 | HERB MARKER ROSEMARY [22917] | HERB MARKER THYME [22916] + HERB MARKER BASIL [22920] | 200 | 1.0114% | 83.3333% | 78.4722 |
| 7 | HERB MARKER ROSEMARY [22917] + HERB MARKER BASIL [22920] | HERB MARKER THYME [22916] | 200 | 1.0114% | 93.4579% | 77.9802 |
| 8 | HERB MARKER THYME [22916] | HERB MARKER ROSEMARY [22917] + HERB MARKER BASIL [22920] | 200 | 1.0114% | 84.3882% | 77.9802 |
| 9 | HERB MARKER THYME [22916] | HERB MARKER ROSEMARY [22917] | 221 | 1.1176% | 93.2489% | 76.8332 |
| 10 | HERB MARKER ROSEMARY [22917] | HERB MARKER THYME [22916] | 221 | 1.1176% | 92.0833% | 76.8332 |

[Nguồn số liệu và thống kê tiền xử lý](../../results/metrics/online_retail_rules.md)

## Ý nghĩa kinh doanh

- **Rosemary và Parsley → Thyme.** Trong 215 giỏ có thẻ đánh dấu cây hương
  thảo và mùi tây, 203 giỏ cũng có thẻ đánh dấu cỏ xạ hương. Confidence đạt
  **94,42%**. Tần suất nền của thẻ cỏ xạ hương là **1,20%** (237/19.775),
  cho lift **78,78**.
- **Thyme và Basil → Rosemary.** Trong 210 giỏ có thẻ cỏ xạ hương và húng
  quế, 200 giỏ cũng chứa thẻ hương thảo. Confidence **95,24%** so với tần
  suất nền **1,21%** của thẻ hương thảo (240/19.775), cho lift **78,47**.
- **Thyme → Rosemary.** Cặp thẻ xuất hiện trong 221 giỏ. Confidence
  **93,25%** (221/237) và lift **76,83**. Cặp này có số giỏ đồng xuất hiện
  cao hơn hai bộ ba trên, nên là ứng viên cho một gói hai sản phẩm.

Cả 10 luật thuộc dòng thẻ đánh dấu cây gia vị, tạo thành 5 cặp thuận/nghịch
và quy về 3 bộ sản phẩm khi gộp hai vế. Hai chiều có cùng lift, còn confidence
theo từng chiều giúp chọn lời gợi ý để thử nghiệm, chẳng hạn gợi ý Thyme khi
giỏ đã có Rosemary và Parsley. Dữ liệu mô tả hành vi trong các hóa đơn quan
sát được. Để đo tác động lên tỷ lệ mua, cần kiểm tra trên giao dịch mới
hoặc thực hiện thử nghiệm có nhóm so sánh.

## Tái lập

Chạy phần phân tích giỏ hàng trong [notebook](../../notebooks/demo.ipynb)
hoặc chạy từ thư mục gốc của repository với Julia 1.9 trở lên. Lệnh dưới đây
tự tải workbook gốc từ UCI nếu chưa có. Nếu truyền đường dẫn Excel riêng,
tệp phải tồn tại. Julia kiểm tra SHA-256 rồi đọc từng dòng bằng XLSX.jl.
Trong notebook Colab, ô khởi tạo chuẩn bị Julia và ô
thực nghiệm gọi cùng lệnh khai phá dưới đây.

```powershell
julia --project=. -e "using Pkg; Pkg.instantiate()"
julia --project=. scripts/run_market_basket.jl results/metrics/online_retail_rules.md 1% 50%
```

Trích dẫn dữ liệu: Chen, D. (2015). *Online Retail* [Dataset]. UCI Machine
Learning Repository. [DOI 10.24432/C5BW33](https://doi.org/10.24432/C5BW33)
