# CHECKLIST & PHÂN CÔNG ĐỒ ÁN ECLAT — NHÓM 2 NGƯỜI

**Nguồn yêu cầu:** `itemset.md` (đề đồ án Khai thác tập phổ biến, HCMUS)  
**Thuật toán nhóm đã chọn:** Eclat  
**Thời lượng:** 3 tuần, mỗi tuần hoàn thành một chương  
**Thành viên:** Người A và Người B (thay bằng tên thật khi phân công)  
**Nguyên tắc:** Mỗi goal có **một người chịu trách nhiệm chính**, người còn lại kiểm tra chéo; không chia đôi một goal gây khó tích hợp.

> **Phương án kỹ thuật đề xuất:** Julia (được ưu tiên trong đề), Eclat dùng TID-set làm baseline và thử tối ưu bằng bitset/BitArray. Đây là đề xuất triển khai, không phải yêu cầu bắt buộc chọn đúng kỹ thuật này.  
> **Phương án ứng dụng đề xuất:** Ứng dụng 1 = Market Basket Analysis; Ứng dụng 2 = phân tích dữ liệu sinh học (genome/protein). Nhóm có thể thay bằng hướng còn lại được đề cho phép, nhưng phải giữ đủ **hai ứng dụng**.

---

## TUẦN 1 — CHƯƠNG 1: CÀI ĐẶT ECLAT (25–30%)

### Người A — Thuật toán và tối ưu

**Goal 1. Eclat baseline hoạt động đúng**
- [x] Đọc và ghi chú bài báo gốc của Eclat; giải thích TID-set, phép giao, tính support, quy trình tìm kiếm và độ phức tạp.
- [x] Thiết kế cấu trúc dữ liệu cho TID-set / frequent itemset.
- [x] Tự cài đặt Eclat baseline từ đầu, trả về **đầy đủ frequent itemset và support**.
- [x] Bàn giao API/hàm gọi thống nhất để Người B tích hợp CLI và kiểm thử.

**Goal 2. Eclat optimized và đo cải thiện**
- [x] Cài đặt **ít nhất một kỹ thuật tối ưu** phù hợp (đề xuất: bitset/BitArray cho TID-set).
- [x] Giữ baseline và optimized để chạy trên cùng đầu vào, cùng minsup.
- [x] Đo thời gian chạy và bộ nhớ; ghi bảng chênh lệch (bao gồm trường hợp tối ưu không hiệu quả).
- [x] Viết phần giải thích thuật toán và tối ưu của Chương 1.

### Người B — I/O, kiểm thử và đối chiếu SPMF

**Goal 3. Input/output chuẩn và CLI**
- [x] Viết hàm đọc file `.txt` giao dịch theo định dạng SPMF.
- [x] Viết hàm xuất frequent itemset kèm support theo định dạng SPMF.
- [x] Làm CLI nhận **đường dẫn file** và **minsup**, kết nối với Eclat của Người A.

**Goal 4. Unit tests và correctness**
- [x] Chuẩn bị **ít nhất 5 CSDL kiểm thử khác nhau**, gồm cả tình huống biên hợp lý.
- [x] Lấy kết quả chuẩn từ **SPMF** trên cùng dữ liệu và minsup.
- [x] Viết unit tests tự động so sánh **từng itemset và support**, không chỉ tổng số itemset.
- [x] Báo cáo tỉ lệ khớp; phối hợp Người A sửa các trường hợp sai đến khi kết quả khớp hoàn toàn.
- [x] Đảm bảo lệnh chạy test (`julia --project test/runtests.jl` nếu dùng Julia, hoặc `pytest` nếu dùng Python) pass.
- [x] Viết phần kiểm thử, I/O và CLI của Chương 1.

**Nghiệm thu cuối tuần 1**
- [x] Eclat baseline + optimized chạy được và có kết quả đúng so với SPMF.
- [x] Đủ 5 CSDL unit test; CLI và I/O hoạt động.
- [x] Có số liệu chứng minh mức thay đổi thời gian/bộ nhớ giữa hai bản.
- [x] Phần Chương 1 của báo cáo đã có nội dung nháp.

---

## TUẦN 2 — CHƯƠNG 2: THỰC NGHIỆM & ĐÁNH GIÁ (20%)

### Người A — Hiệu năng và khả năng mở rộng

**Goal 5. Runtime và số lượng itemset theo minsup**
- [x] Chạy Eclat và SPMF trên **ít nhất 4 benchmark datasets** do Người B chuẩn bị.
- [x] Với **mỗi dataset**, đo runtime tại **ít nhất 5–7 mức minsup** từ cao xuống thấp.
- [x] Vẽ biểu đồ so sánh runtime **Eclat và SPMF trên cùng đồ thị**.
- [x] Vẽ biểu đồ **số lượng frequent itemset theo minsup**; phân tích khác biệt giữa dữ liệu dense và sparse.

**Goal 6. Scalability và ảnh hưởng độ dài giao dịch**
- [x] Chọn dataset lớn (ví dụ Retail hoặc Accidents); tạo các mức **10%, 25%, 50%, 75%, 100%** giao dịch.
- [x] Đo và vẽ runtime theo kích thước dữ liệu; nhận xét tuyến tính / phi tuyến.
- [x] Nếu Eclat bị ảnh hưởng bởi độ dài giao dịch trung bình, tạo dữ liệu tổng hợp có độ dài tăng dần và đo ảnh hưởng.
- [x] Viết phần phương pháp đo và phân tích runtime / scalability của Chương 2.

### Người B — Benchmark, correctness và bộ nhớ

**Goal 7. Bộ benchmark chuẩn và kiểm tra correctness**
- [x] Chuẩn bị **ít nhất 4 datasets** (gợi ý: Chess, Mushroom, Retail, T10I4D100K), lưu hoặc liên kết dữ liệu để tái chạy.
- [x] Kiểm tra định dạng, số giao dịch và cách đọc dữ liệu; thống nhất các minsup với Người A.
- [x] Với **mỗi dataset**, đối chiếu số lượng frequent itemset, từng itemset và support với SPMF; ghi **tỉ lệ khớp**.
- [x] Ghi nhận và giải thích mọi sai lệch nếu có.

**Goal 8. Peak memory và tổng hợp đánh giá**
- [x] Đo **peak RAM** trên mỗi benchmark ở một mức minsup trung bình.
- [x] So sánh bộ nhớ giữa **baseline và optimized**, lập bảng / biểu đồ.
- [x] Tổng hợp các biểu đồ và số liệu từ Người A để viết nhận xét điểm mạnh / yếu của Eclat so với SPMF.
- [x] Đề xuất **ít nhất 2 hướng tối ưu hóa tiếp theo** có lý do kỹ thuật.
- [x] Viết phần correctness, bộ nhớ và kết luận Chương 2.

**Nghiệm thu cuối tuần 2**
- [x] Có kết quả trên ít nhất 4 benchmark, correctness theo từng itemset và support.
- [x] Đủ biểu đồ runtime–minsup, số itemset–minsup, peak RAM và scalability.
- [x] Có thực nghiệm độ dài giao dịch nếu phù hợp.
- [x] Chương 2 có phân tích số liệu và ít nhất 2 đề xuất tối ưu.
- [x] **Cả hai người đã chốt dataset và thử chuyển đổi dữ liệu cho ứng dụng mình phụ trách ở tuần 3.**

---

## TUẦN 3 — CHƯƠNG 3: HAI ỨNG DỤNG THỰC TẾ (50%)

### Người A — Ứng dụng 1 và demo

**Goal 9. Ứng dụng 1 (25%) — ưu tiên Market Basket Analysis**
- [x] Chọn **Market Basket Analysis** với [UCI Online Retail](https://archive.ics.uci.edu/dataset/352/online%2Bretail). Mỗi hóa đơn (`InvoiceNo`) là một giỏ; mỗi mã hàng (`StockCode`) xuất hiện tối đa một lần trong giỏ.
- [x] Chuyển dữ liệu gốc thành transaction trong [notebook](../notebooks/demo.ipynb).
- [x] Khai phá toàn bộ giỏ hợp lệ bằng Eclat của nhóm.
- [x] Sinh luật theo minsup và minconf, trình bày [top-10 theo lift](../results/metrics/online_retail_rules.md) và giải thích ý nghĩa kinh doanh.
- Không áp dụng hướng Event Log vì nhóm đã chọn Market Basket Analysis.
- [x] Viết [báo cáo ứng dụng 1](report/market_basket.md) kèm dữ liệu, bảng và nhận xét.

**Goal 10. Demo Colab, README và tích hợp repository**
- [ ] Tạo/tích hợp notebook demo trên **Google Colab**: chạy Eclat và tái tạo kết quả **cả hai ứng dụng**.
- [ ] Viết README: thành viên, hướng dẫn cài đặt/chạy, ví dụ, link Colab, link dataset, lệnh kiểm thử.
- [ ] Đảm bảo repo GitHub **public**, cấu trúc rõ ràng, giữ lịch sử commit minh bạch.
- [ ] Nếu dữ liệu lớn, host trên **Hugging Face hoặc Kaggle** và gắn link công khai trong README.
- [ ] Gắn output của **lần chạy test cuối** vào README; kiểm tra notebook chạy sạch.

### Người B — Ứng dụng 2 và báo cáo tổng

**Goal 11. Ứng dụng 2 (25%) — ưu tiên dữ liệu sinh học**
- [ ] Chọn một trong hai hướng của đề: **genome/protein** hoặc **visual patterns trên ảnh**.
- [ ] Chọn dataset phù hợp; viết code **chuyển dữ liệu thành transaction trong notebook**.
- [ ] Dùng **Eclat của nhóm** khai thác frequent itemset trên dữ liệu đã chuyển.
- [ ] **Nếu sinh học:** giải thích ý nghĩa sinh học của các pattern; tránh diễn giải vượt quá khả năng dữ liệu.
- [ ] **Nếu hình ảnh:** dùng biểu diễn như bag of visual words (descriptors → codebook k-means → transaction) và phân tích ý nghĩa các mẫu trực quan.
- [ ] Viết nội dung báo cáo về Ứng dụng 2, kèm dữ liệu, kết quả và nhận xét.

**Goal 12. Hoàn thiện báo cáo và kiểm tra nộp bài**
- [ ] Ghép nội dung Chương 1–3 từ hai thành viên vào báo cáo tiếng Việt **10–15 trang** theo **IEEE conference format** (không tính tài liệu tham khảo/phụ lục).
- [ ] Bổ sung công thức với giải thích ký hiệu, caption và tham chiếu hình/bảng.
- [ ] Trích dẫn **bài báo gốc Eclat và ít nhất 3 tài liệu liên quan khác**.
- [ ] Xuất đúng file **`docs/Report.pdf`**.
- [ ] Kiểm tra sự khớp nhau giữa báo cáo, code, kết quả đo và demo.

**Nghiệm thu cuối tuần 3 / trước khi nộp**
- [ ] Ứng dụng 1 **và** Ứng dụng 2 đều chạy bằng Eclat của nhóm, có diễn giải kết quả.
- [ ] Notebook Colab public chạy lại được từ đầu; seed ngẫu nhiên được cố định khi có bước ngẫu nhiên.
- [ ] README đầy đủ; toàn bộ unit tests pass; `docs/Report.pdf` đúng yêu cầu.
- [ ] **Người A kiểm tra chéo Goal 11–12; Người B kiểm tra chéo Goal 9–10.**
- [ ] Cả hai đều giải thích được thuật toán, phần tối ưu và ứng dụng để chuẩn bị vấn đáp.
- [ ] **Nộp duy nhất link GitHub public lên Moodle.**

---

## BẢNG PHÂN CÔNG NHANH

| Tuần | Goal | Người chịu trách nhiệm chính | Sản phẩm bàn giao |
|---|---|---|---|
| 1 | G1 — Eclat baseline | **A** | Thuật toán chạy đúng, trả về itemset/support |
| 1 | G2 — Eclat optimized | **A** | Bản tối ưu + bảng so sánh baseline |
| 1 | G3 — SPMF I/O và CLI | **B** | Parser, writer, CLI |
| 1 | G4 — Unit tests / SPMF correctness | **B** | ≥5 CSDL test + báo cáo tỉ lệ khớp |
| 2 | G5 — Runtime và itemset theo minsup | **A** | Số liệu và biểu đồ trên 4 datasets |
| 2 | G6 — Scalability / transaction length | **A** | Biểu đồ scalability + phân tích |
| 2 | G7 — Chuẩn bị benchmark / correctness | **B** | ≥4 datasets + đối chiếu SPMF |
| 2 | G8 — Peak RAM / tổng hợp đánh giá | **B** | Số liệu RAM + nhận xét + 2 hướng tối ưu |
| 3 | G9 — Ứng dụng 1 | **A** | Pipeline, kết quả, diễn giải |
| 3 | G10 — Colab / README / GitHub | **A** | Repo và demo công khai, chạy sạch |
| 3 | G11 — Ứng dụng 2 | **B** | Pipeline, kết quả, diễn giải |
| 3 | G12 — Report.pdf / soát nộp | **B** | Báo cáo IEEE hoàn chỉnh |

## Quy tắc phối hợp tối thiểu

1. **Đầu tuần 1:** Người A thống nhất chữ ký hàm và kiểu đầu ra của Eclat với Người B; Người B không tự sửa thuật toán lõi mà báo lỗi bằng test case.
2. **Đầu tuần 2:** Người B bàn giao 4 datasets + kết quả tham chiếu; hai người thống nhất minsup và môi trường chạy để so sánh công bằng.
3. **Cuối tuần 2:** Mỗi người chọn xong hướng + dataset cho ứng dụng mình phụ trách, có ít nhất một mẫu transaction chạy thử.
4. **Tuần 3:** Mỗi người bàn giao notebook/đoạn chạy ứng dụng của mình; Người A tích hợp demo, Người B tích hợp báo cáo.
5. **Trước khi nộp:** Hai người cùng kiểm tra bản cuối và cùng chuẩn bị trả lời vấn đáp; đây là trách nhiệm chung, không giao riêng.

> **Lưu ý từ đề:** Cần tự hiện thực từ bài báo gốc. Đề cho phép dùng AI hỗ trợ viết code nhưng quy định sao chép mã nguồn từ SPMF, GitHub, ChatGPT hoặc nguồn khác có thể bị điểm 0 toàn bộ đồ án.
