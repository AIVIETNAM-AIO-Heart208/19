# Báo cáo khai phá tập mục phổ biến bằng Eclat

Báo cáo gồm ba chương về cài đặt thuật toán, đánh giá thực nghiệm và hai ứng dụng.
Bản nộp dùng mẫu IEEE conference, dài 10–15 trang tiếng Việt (không tính tài liệu tham khảo và phụ lục), trích dẫn bài báo gốc và ít nhất ba tài liệu liên quan. Đường dẫn của bản nộp là `docs/Report.pdf`.

## Nguồn LaTeX và cách biên dịch

Nguồn bản nộp là `Report.tex` (lớp `IEEEtran`, chế độ `conference`), các mục trong `sections/` và tài liệu tham khảo trong `references.bib`. Các file `.md` trong thư mục này là bản nháp chi tiết của từng phần; số liệu đưa vào LaTeX phải khớp với chúng và với `results/`.

Báo cáo cần XeTeX để hiển thị tiếng Việt với font TeX Gyre Termes. Cách đã thử là [Tectonic](https://tectonic-typesetting.github.io/) 0.17.0, chạy từ thư mục gốc repository:

```powershell
tectonic -X compile docs/report/Report.tex --outdir docs
```

Lệnh ghi `docs/Report.pdf`. Lần chạy đầu Tectonic tải các gói LaTeX cần dùng nên mất vài phút. Có thể biên dịch bằng XeLaTeX của TeX Live, MiKTeX hoặc Overleaf (chọn trình biên dịch XeLaTeX) với cùng các file nguồn.

## Chương 1. Cài đặt Eclat

[Thuật toán, giao diện dòng lệnh và kiểm thử](chapter1.md).

## Chương 2. Thực nghiệm và đánh giá

Phần runtime và số lượng itemset: [runtime_benchmarks.md](runtime_benchmarks.md).

Scalability và độ dài giao dịch: [scalability.md](scalability.md).

Correctness trên 5 CSDL benchmark so với SPMF: [correctness_benchmarks.md](correctness_benchmarks.md).

Bộ nhớ baseline và bitset trên dữ liệu thật: [memory_benchmarks.md](memory_benchmarks.md).

Điểm mạnh/yếu so với SPMF, hai hướng tối ưu và kết luận Chương 2: [chapter2_evaluation.md](chapter2_evaluation.md).

## Chương 3. Ứng dụng thực tế

[Phân tích giỏ hàng trên UCI Online Retail](market_basket.md).
