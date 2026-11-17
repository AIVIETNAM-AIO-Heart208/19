# Dữ liệu

- raw/: dữ liệu gốc tải về, không commit.
- processed/: transaction sau chuyển đổi, không commit.
- datasets.toml: ghi URL, phiên bản, giấy phép và SHA-256.
- Dữ liệu nhỏ để unit test đặt trong test/fixtures/transactions/.

Ưu tiên benchmark công khai trên Hugging Face hoặc Kaggle theo đề. Code chuẩn bị dữ liệu phải gọi được từ notebook Colab.


Dữ liệu benchmark thật phải đi qua `EclatMining.clean_spmf(in, out)` trước (bỏ dấu cách thừa, item trùng
trong dòng; không đổi số giao dịch), vì SPMF crash với các lỗi đó. Cả SPMF và code nhóm cùng đọc file đã làm sạch.
