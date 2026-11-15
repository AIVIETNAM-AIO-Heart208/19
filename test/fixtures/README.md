# Dữ liệu kiểm thử

- `transactions/`: các CSDL nhỏ dùng cho unit test (sinh bằng `scripts/gen_toy.jl`, seed 42; `toy.txt` là toy contextPasquier99 viết tay).
- `spmf_expected/`: output thật của SPMF, tên `<tên>_<p>.txt` ứng với `transactions/<tên>.txt` ở minsup `p%`.
- `cases.toml`: danh sách case (input, minsup, file expected, phiên bản SPMF, lệnh chạy), do `experiments/spmf/run_reference.jl` ghi.

Output trong `spmf_expected/` là nguyên bản của SPMF Eclat v2.65 (`tools/spmf.jar`, JDK 25+), không chỉnh tay.
Sinh lại toàn bộ bằng `julia --project experiments/spmf/run_reference.jl`; lệnh tương đương cho một case:
`java -jar tools/spmf.jar run Eclat test/fixtures/transactions/<tên>.txt test/fixtures/spmf_expected/<tên>_<p>.txt <p>%`.

## Input SPMF không chạy được (quan sát ngày 16/11/2026, chạy hộp đen)

- `empty.txt`: SPMF từ chối với `IllegalArgumentException: The input file is empty`.
- `dup_items_comments.txt` (file bẩn): SPMF crash (`NumberFormatException: For input string: ""`).
  File bẩn được đối chiếu qua bản đã làm sạch `dup_items_comments_clean.txt`, do `clean_spmf` sinh ra
  (xem `test/test_io.jl`).

Thử riêng từng loại "bẩn" trên một CSDL 4 giao dịch, minsup 50%:

| Loại dòng | SPMF v2.65 | `read_spmf` của nhóm |
|---|---|---|
| Dòng `@`, `#`, `%` | bỏ qua, kết quả như bản sạch | bỏ qua |
| Dòng trống hoàn toàn | bỏ qua | bỏ qua |
| CRLF, thiếu newline cuối file | như bản sạch | như bản sạch |
| Dấu cách cuối dòng | như bản sạch | strip |
| Item chưa sort trong dòng | như bản sạch | sort |
| Dấu cách đầu dòng, hai dấu cách liền nhau | crash `NumberFormatException` | strip / tách theo khoảng trắng |
| Item trùng trong dòng | crash `ArrayIndexOutOfBoundsException`, để lại file output rỗng | bỏ item trùng |
| Dòng chỉ có dấu cách | **tính là một giao dịch rỗng** (số giao dịch +1, làm đổi minsup tuyệt đối) | một giao dịch rỗng (giống SPMF) |

Vì vậy benchmark thật phải đi qua `clean_spmf` trước; SPMF và code nhóm cùng đọc file đã làm sạch.
