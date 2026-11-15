# Output tham chiếu của SPMF

Sinh bằng `scripts/run_spmf.ps1`: SPMF Eclat v2.65 (`tools/spmf.jar`, JDK 25), lệnh
`java -jar tools/spmf.jar run Eclat data/toy/<tên>.txt test/expected/<tên>_<p>.txt <p>%`.
Tên file `<tên>_<p>.txt` ứng với input `data/toy/<tên>.txt` ở minsup `p%`.
Các file ở đây là output nguyên bản của SPMF, không chỉnh tay.

## Hai input SPMF không chạy được (quan sát ngày 16/11/2026, chạy hộp đen)

- `empty.txt`: SPMF từ chối với `IllegalArgumentException: The input file is empty`.
- `dup_items_comments.txt` (file bẩn): `NumberFormatException: For input string: ""`.
  Vì vậy file bẩn được đối chiếu qua bản đã làm sạch `dup_items_comments_clean.txt`.

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
| Dòng chỉ có dấu cách | **tính là một giao dịch rỗng** (số giao dịch +1, làm đổi minsup tuyệt đối) | bỏ qua như dòng trống |

Điểm cuối là chỗ duy nhất hai bên cùng chạy được mà cho kết quả khác nhau.
