# Ứng dụng sinh học: khai thác motif quanh vị trí cắt nối DNA

Ghi chú thiết kế cho hướng "phân tích dữ liệu sinh học" của Chương 3 (đề: `docs/itemset.md:142–144,
158–160`). Mỗi quyết định ghi theo mẫu **chọn gì · phương án khác · vì sao không chọn phương án khác ·
bằng chứng**. Mọi con số dưới đây lấy từ lần chạy đã commit trong `results/applications/splice/`
(`run_info.toml` ghi commit và `dirty = false`; các phép đếm trên dữ liệu gốc chưa làm sạch nằm trong
`raw_checks.csv`, `non_canonical.csv`) và hình trong `results/figures/splice/`. Câu trích từ hai file mô
tả `splice.names`, `splice.theory` ghi kèm số dòng; script tải hai file này về `data/raw/` cùng dữ liệu
và kiểm SHA-256.

| Thành phần | Đường dẫn |
|---|---|
| Đọc, làm sạch, mã hóa, thống kê | `src/applications/biology.jl` |
| Chạy toàn bộ phân tích | `julia --project scripts/splice_patterns.jl` |
| Vẽ hình | `python scripts/plot_splice_patterns.py` |
| Test | `test/test_applications.jl`, `test/test_splice_figures.py` |

Mọi itemset đều do `eclat` của nhóm sinh ra (qua `mine_class`). Các bước khác chỉ đọc dữ liệu, mã hóa,
đếm lại và tính chỉ số trên kết quả đó; không dùng thư viện FIM.

## 1. Bộ dữ liệu

**Chọn:** UCI *Molecular Biology (Splice-junction Gene Sequences)*: 3190 đoạn DNA linh trưởng, mỗi đoạn
60 nucleotide quanh một vị trí, nhãn EI (ranh giới exon → intron, còn gọi donor), IE (intron → exon,
acceptor) hoặc N (không phải vị trí cắt nối). Giấy phép CC BY 4.0, DOI 10.24432/C5M888.

**Phương án khác:** domain protein Pfam đi cùng nhau trong một protein; tập k-mer của chuỗi protein.

**Vì sao:** bộ splice có "đáp án" sinh học để đối chiếu: quy tắc GT-AG và các mẫu chuẩn ghi trong file
`splice.theory` kèm bộ dữ liệu. Nhờ vậy kiểm được Eclat có tìm ra đúng điều đã biết không, thay vì chỉ
liệt kê mẫu. File nhỏ (319 KB), tải trong notebook được; cả script (gồm khởi động Julia) chạy khoảng
13 s khi dữ liệu đã có sẵn, 16 s khi phải tải về, trên laptop Windows của nhóm (đo 21/11/2026). Pfam phải
tải và lọc dữ liệu lớn qua API, diễn giải phải tra từng domain. Tập k-mer của protein không có đáp án
để đối chiếu.

**Bằng chứng:** 759/767 chuỗi EI có GT ngay sau ranh giới, 764/768 chuỗi IE có AG ngay trước ranh giới
(dữ liệu gốc, `raw_checks.csv`).

**Lưu ý về tài liệu dữ liệu:** `splice.names` tự mâu thuẫn. Dòng 40–41 (mục 3(b)) ghi
`a) "intron -> exon" boundary (ie) [These are sometimes called "donors"]` và
`b) "exon -> intron" boundary (ei) [These are sometimes called "acceptors"]`, còn dòng 57–58 (mục 4) ghi
"IE borders are referred to a ``acceptors'' while EI borders are referred to as ``donors''". Mục 4 đúng với
sinh học (donor là đầu 5' của intron, tức ranh giới exon → intron) và đúng với tên mẫu: cả 767 mẫu EI có
tên chứa `DONOR`, cả 768 mẫu IE có tên chứa `ACCEPTOR` (`raw_checks.csv`). Ghi chú này theo mục 4.

## 2. Mã hóa: item = (vị trí, nucleotide)

**Chọn:** mỗi chuỗi là một giao dịch; item là cặp (vị trí, base), ví dụ `+1G` là "G ngay sau ranh giới".
Vị trí đánh số -30..-1, +1..+30, không có 0, theo đúng quy ước của `splice.theory`. Có 240 item; mỗi
giao dịch có đúng 60 item (trừ chỗ có ký tự mơ hồ, xem mục 8).

**Phương án khác:** (a) tập k-mer không gắn vị trí (chuỗi có chứa "GT" ở đâu đó không); (b) gộp nhãn
lớp vào làm một item rồi khai thác một lần (xem mục 4).

**Vì sao không chọn (a):** tín hiệu cắt nối nằm ở vị trí cố định so với ranh giới. Bỏ vị trí thì mẫu mất
nghĩa: trên dữ liệu gốc, 1541/1655 chuỗi N (93%) có "GT" ở đâu đó, gần bằng EI (765/767;
`raw_checks.csv`, dòng `gt_anywhere`). Ngược lại,
"GT đúng tại +1,+2" có ở 98,8% chuỗi EI nhưng chỉ 5,9% chuỗi N (dữ liệu đã làm sạch, `consensus.csv`).

**Vì sao hợp với Eclat:** TID-set của item (p, b) là tập chuỗi có base b tại vị trí p. Giao các TID-set
cho ra tập chuỗi khớp mọi vị trí của mẫu, nên một itemset phổ biến chính là một motif có khoảng trống
(các vị trí không cần liền nhau). Dữ liệu dày, mỗi giao dịch dài cố định 60, giống Chess: đây là loại dữ
liệu mà bản bitset của nhóm chạy tốt nhất (Chương 2).

## 3. Thêm mã hóa purin/pyrimidin (R/Y)

**Chọn:** chạy thêm một mã hóa thứ hai, item = (vị trí, R hoặc Y), với R = A/G (purin), Y = C/T
(pyrimidin); 120 item. Hai mã hóa dùng song song, không thay nhau.

**Phương án khác:** chỉ dùng mã hóa nucleotide; hoặc thêm item Y vào chung mã hóa nucleotide.

**Vì sao:** trước acceptor có một vùng giàu pyrimidin, nhưng ở từng vị trí base có thể là C hoặc T, nên
mỗi item C hoặc T ở -15..-5 đạt minsup chỉ chiếm 33,8–46,1% chuỗi IE (item đơn trong `patterns.csv`)
và tổ hợp của chúng hiếm khi đạt minsup. Gộp C/T thành Y
làm tín hiệu lộ ra: `-7Y -6Y -5Y -3Y -2R -1R` có ở 64,6% chuỗi IE, 1,4% chuỗi N. Không gộp chung item Y
với item nucleotide, vì "C tại p" luôn kéo theo "Y tại p": số itemset sẽ phình ra bởi các tổ hợp hiển
nhiên. Không bỏ mã hóa nucleotide, vì R/Y làm mất phân biệt A với G (GT thành RY).

## 4. Khai thác riêng từng lớp; lớp N là đối chứng

**Chọn:** ba CSDL riêng (EI, IE, N), cùng mã hóa, cùng minsup tương đối trong lớp.

**Phương án khác:** gộp nhãn lớp làm một item và khai thác toàn bộ dữ liệu một lần (luật kết hợp có vế
phải là lớp).

**Vì sao:** với một ngưỡng chung trên toàn dữ liệu, ngưỡng thực tế trong mỗi lớp khác nhau vì các lớp
có kích thước khác nhau (EI 22,6%, IE 22,4%, N 55,0% của 3004 chuỗi), nên so sánh giữa lớp không công
bằng. Khai thác riêng thì minsup có nghĩa trực tiếp ("có ở ≥ 30% vị trí donor"), và lớp N được xử lý y
hệt nên là nhóm đối chứng. Thông tin của cách gộp không mất: confidence và lift của luật
"mẫu → lớp" vẫn tính được bằng cách đếm lại (mục 9).

## 5. minsup: 30% cho nucleotide, 60% cho R/Y

**Chọn:** minsup chính 30% (nucleotide) và 60% (R/Y). Bảng số itemset vẫn chạy cả dải 90%→20%
(nucleotide) và 90%→50% (R/Y) (`itemset_counts.csv`, hình `itemset_counts`).

**Quy tắc:** minsup phải cao hơn **mức nền ngẫu nhiên**. Ở một vị trí bất kỳ, mỗi base chiếm khoảng 1/4
số chuỗi (R hoặc Y chiếm khoảng 1/2). Một item chỉ phổ biến ở mức nền thì không nói lên điều gì.

**Bằng chứng:**
- Lớp N: ở 20% có đủ 240 item đơn phổ biến, ở 25% còn 115, ở 30% còn 0. Với R/Y: ở 50% có 59, ở 60%
  còn 0. Vậy 30% và 60% là mức đầu tiên của dải mà lớp đối chứng hoàn toàn trống.
- Không chọn 40%: mất hẳn vị trí -3 của mẫu chuẩn donor (`-3C` có ở 39,0% chuỗi EI, `-3A` 31,7%), và EI
  chỉ còn 63 itemset.
- Không chọn 20–25%: số itemset của EI tăng lên 866 (25%) và 2324 (20%), trong khi ngưỡng đã chạm mức
  nền nên phần tăng thêm không còn phân biệt được với nhiễu.
- Không chọn 50% cho R/Y: IE có 3632 itemset, quá nhiều để đọc; 70% thì mẫu dài nhất của IE chỉ còn 5 item.

## 6. Bỏ chuỗi trùng trong cùng lớp

**Chọn:** cùng chuỗi, cùng lớp thì giữ một bản. Bỏ 184 bản (EI 767→679, IE 768→673 trước bước 7,
N 1655→1654 trước bước 7).

**Phương án khác:** giữ nguyên dữ liệu gốc như các bài học máy dùng bộ này.

**Vì sao:** support nên đếm số vị trí cắt nối khác nhau. 107/124 nhóm trùng gồm các locus GenBank khác
nhau (`run_info.toml`, mục `cleaning`), ví dụ `BABAPOE`/`HUMAPOE4`, `HUMHBBGG`/`GIBHBGGL`/`ORAHBG2F`: thường là cùng một gen ở nhiều loài
linh trưởng hoặc các bản sao gen (suy từ tên locus). Giữ cả thì gen nào được giải trình tự ở nhiều loài
sẽ được đếm nhiều lần.

**Bằng chứng không làm lệch kết luận:** khai thác lại trên dữ liệu gốc ở cùng minsup, tập itemset gần như
trùng (Jaccard nucleotide EI 0,93, IE 0,91; R/Y EI 1,00, IE 0,89; `cleaning_sensitivity.csv`).

## 7. Bỏ chuỗi mang hai nhãn mâu thuẫn

**Chọn:** bỏ cả hai bản của chuỗi duy nhất mang hai nhãn: `HUMCYPIIE-ACCEPTOR-12121` (IE) và
`HUMCYPIIE-NEG-12121` (N), cùng gen, cùng vị trí.

**Phương án khác:** giữ bản IE vì chuỗi có AG trước ranh giới.

**Vì sao:** dùng chính quy tắc AG để chọn nhãn rồi lại "phát hiện" quy tắc AG là lập luận vòng tròn. Chỉ
mất 2/3190 chuỗi.

## 8. Ký tự mơ hồ (N, D, R, S)

**Chọn:** vị trí có ký tự mơ hồ không sinh item; chuỗi vẫn được giữ (15 chuỗi). Riêng mã hóa R/Y, ký
tự R và Y có nghĩa xác định (R = A/G là purin) nên vẫn sinh item.

**Phương án khác:** bỏ cả chuỗi; hoặc đoán base (ví dụ base hay gặp nhất).

**Vì sao:** đoán base thì tạo ra item không có thật. Bỏ item chỉ có thể làm support giảm, không bao giờ tạo
ra mẫu giả. Bỏ cả chuỗi cũng đúng nhưng mất dữ liệu không cần thiết. Ảnh hưởng tối đa: 15/3004 chuỗi.

## 9. Tra support ở lớp khác bằng cách đếm lại

**Chọn:** với mỗi mẫu khai thác được ở một lớp, đếm số chuỗi chứa nó ở cả ba lớp (`support_count`, mỗi
giao dịch là một BitVector).

**Phương án khác:** khai thác lại lớp kia ở ngưỡng thấp hơn.

**Vì sao:** một mẫu donor thường có rất ít trong N (ví dụ 0/1653), thấp hơn mọi minsup hợp lý, nên khai thác
N không trả về nó. Đếm trực tiếp cho số chính xác. Ở chính lớp đã khai thác, số đếm lại phải bằng support
của Eclat, nếu khác thì `class_contrast` báo lỗi. Như vậy mọi support trong bảng đều được kiểm hai lần
bằng hai cách khác nhau.

## 10. Chỉ số so sánh lớp

- `growth_vs_n` = tỉ lệ trong lớp / tỉ lệ trong N: mẫu phổ biến ở lớp này gấp bao nhiêu lần ở đối chứng.
- `confidence` = P(lớp | mẫu) và `lift` = confidence / P(lớp): luật "mẫu → lớp".

**Giới hạn:** confidence và lift phụ thuộc tỉ lệ lớp do người dựng bộ dữ liệu chọn (N chiếm khoảng một nửa),
không phải tỉ lệ trong genome thật, nên không đọc chúng như độ chính xác khi quét genome. `growth_vs_n`
không phụ thuộc tỉ lệ lớp nên dùng để xếp hạng.

## 11. Phụ thuộc giữa hai vị trí

**Chọn:** với mỗi 2-itemset phổ biến, tính lift và χ² của bảng 2×2. Chỉ đọc những cặp có mọi ô kỳ vọng
≥ 5 (quy tắc Cochran). Ngưỡng χ² > 15,14 tương ứng p < 10⁻⁴ (1 bậc tự do).

**Phương án khác:** xem lift là đủ; hoặc dùng ngưỡng p < 0,05 cho từng cặp.

**Vì sao:** lift không cho biết độ lệch có vượt dao động ngẫu nhiên không. Cặp như `+1G,+2T` có mặt ở gần
mọi chuỗi EI: ô "không có cả hai" kỳ vọng chưa tới 1 chuỗi, nên χ² ra 168 dù lift = 1,003; đó là ảo giác
của phép xấp xỉ, nên bị loại. Kiểm nhiều cặp cùng lúc thì phải hiệu chỉnh. Tổng số cặp đủ điều kiện ở mọi
lớp và mã hóa là 133, nên với ngưỡng 10⁻⁴, theo Bonferroni, xác suất có ít nhất một kết luận sai
≤ 133 × 10⁻⁴ ≈ 1,3%.

**Kết quả (nucleotide, EI):** 105 cặp, 23 cặp đủ điều kiện, 8 cặp vượt ngưỡng. Sáu cặp lift < 1: năm cặp
nối một vị trí phía exon (-2A, -1G) với một vị trí phía intron (+4A, +5G, +6T), ví dụ `-1G,+6T` (lift
0,87, χ² 44,4); cặp thứ sáu là `+3A,+5G` (lift 0,91). Hai cặp lift > 1 đều đi với `+3G` (`+3G,+5G` 1,09;
`+3G,+4A` 1,12). Diễn giải thận trọng: một vị trí donor khớp mẫu chuẩn ở phía này thường không cần khớp
đủ ở phía kia. Điều này phù hợp với nhận
xét rằng các vị trí của tín hiệu donor phụ thuộc nhau (Burge & Karlin 1997), nhưng dữ liệu này không cho
biết cơ chế.

## 12. Trình bày bằng itemset tối đại

**Chọn:** bảng trong báo cáo dùng itemset tối đại (không nằm trong itemset phổ biến nào lớn hơn), sắp
theo độ dài rồi support; file `patterns.csv` vẫn giữ mọi itemset phổ biến và cột `maximal`.

**Vì sao:** ở 30%, EI có 286 itemset nhưng chỉ 49 itemset tối đại. Mọi itemset khác là tập con của chúng
nên không thêm thông tin về motif. Lọc tối đại là bước hậu xử lý trên kết quả Eclat, không phải khai thác lại.

## 13. Lấy dữ liệu: tải và ghim SHA-256

**Chọn:** script tải `splice.data`, `splice.names`, `splice.theory` từ UCI vào `data/raw/` (đã bị
`.gitignore`), dừng nếu SHA-256 của file nào khác bản đã ghim. Đây cũng là cách
`scripts/prepare_benchmarks.jl` làm với dữ liệu benchmark.

**Phương án khác:** commit file vào repo (giấy phép CC BY 4.0 cho phép, file chỉ 319 KB).

**Vì sao:** giữ một quy ước cho mọi dữ liệu của dự án. Link tải trực tiếp là đường dẫn cũ `/ml/` của UCI;
ngày 21/11/2026 đã kiểm cả ba file tải từ đó có cùng SHA-256 với file trong bản zip chính thức. Nếu link
này hỏng trước khi nộp, phương án dự phòng là commit file.

## 14. Chỗ đặt code

**Chọn:** hàm ở `src/applications/biology.jl` (file đã có sẵn trong khung repo), script ở `scripts/`.
Đề cho phép mã chuẩn bị dữ liệu "viết trực tiếp hoặc import từ file phụ trợ trong repo"
(`docs/itemset.md:227–228`), nên notebook có thể gọi script và hàm ở đây.

**Chưa làm:** phần notebook. Đề yêu cầu phần chuyển đổi dữ liệu nằm trong notebook
(`docs/itemset.md:142–144`), và rubric mức Xuất sắc đòi "kết quả tái thực hiện được qua notebook demo"
(`docs/itemset.md:284–286`). Notebook phải tải dữ liệu, chạy `scripts/splice_patterns.jl`, cho xem một
chuỗi được mã hóa thành giao dịch thế nào, rồi hiển thị bảng và hình.

**Còn chờ:** trưởng nhóm chọn để ứng dụng trong `applications/` hay trong notebook. Cách đặt hiện tại dùng
được với cả hai.

## Kết quả chính

| Quan sát | Số liệu |
|---|---|
| Motif donor 5 item có support cao nhất ở 30% (EI có 7 itemset 5 item, không có itemset dài hơn) | `-1G +1G +2T +4A +5G`: 318/679 chuỗi EI (46,8%), 0/1653 chuỗi N |
| Mười item đơn của EI có tỉ lệ ≥ 1,5 lần so với N | đều nằm trong -3..+6, khớp mẫu chuẩn `MAG\|GTRAGT` (hình `position_enrichment`) |
| Chỉ GT chưa đủ | `+1G +2T → EI`: confidence 0,77; `-1G +1G +2T +4A +5G → EI`: confidence 0,98 |
| Mẫu chuẩn đầy đủ hiếm gặp | `MAGGTRAGT` từ -3 khớp 27/679 chuỗi EI (4,0%); gần với câu ở `splice.theory` dòng 66–67: "If exact matches are required, then this set of rules correctly identifies 40% of the IE examples, 4% of the EI examples" (luật đó còn thêm điều kiện không có codon dừng, tính trên dữ liệu gốc) |
| Lõi acceptor | `-3C -2A -1G`: 78,0% chuỗi IE, 2,2% chuỗi N |
| Vùng giàu pyrimidin (R/Y) | `-7Y -6Y -5Y -3Y -2R -1R`: 64,6% chuỗi IE, 1,4% chuỗi N |
| Đối chứng N | 0 itemset từ 2 item trở lên ở mọi minsup đã chạy, cả hai mã hóa |
| Ngoại lệ GT | 8/767 donor không có GT; 4 trong số đó là GC (`+1G +2C`): HUMAPRTA, HUMFVII, HUMKER18, HUMTHB (`non_canonical.csv`) |

Ý nghĩa khi đọc: mẫu chuẩn kiểu `MAG|GTRAGT` là hình mẫu lý tưởng, còn vị trí cắt nối thật chỉ khớp
từng phần. Eclat cho biết những tổ hợp nào của mẫu chuẩn thực sự hay đi cùng nhau và với tần suất bao
nhiêu, điều mà một chuỗi đồng thuận không cho biết. Điều này hợp với nhận xét rằng vị trí donor ở người rất
đa dạng và phần lớn được nhận ra nhờ bắt cặp base với U1 snRNA (Roca và cộng sự 2013).

## Không kết luận được

- Đồng xuất hiện không chứng minh cơ chế: dữ liệu không cho biết vì sao các vị trí phụ thuộc nhau.
- Dữ liệu chỉ gồm linh trưởng, lấy từ GenBank 64.1 (`splice.names` dòng 7: "all examples taken from
  Genbank 64.1"; bộ dữ liệu được tặng năm 1991), chỉ cửa sổ 60 nucleotide: không thấy được điểm nhánh
  (branch point) nằm xa hơn, không đại diện cho genome hiện nay.
- Confidence và lift theo tỉ lệ lớp của bộ dữ liệu, không theo genome thật (mục 10).
- 2 trong 4 chuỗi IE không có AG lại có AG ngay sau ranh giới (`HUMAK1-ACCEPTOR-3918`,
  `HUMAK1-ACCEPTOR-10488`; cột `ag_at_+1` trong `non_canonical.csv`); có thể ranh giới bị ghi lệch, nhưng
  đây chỉ là giả thuyết, chưa kiểm.

## Nguồn đã kiểm chứng

- Bộ dữ liệu: UCI Machine Learning Repository, *Molecular Biology (Splice-junction Gene Sequences)*, 1991,
  DOI 10.24432/C5M888, CC BY 4.0 (trang dataset, đọc 21/11/2026).
- M. O. Noordewier, G. G. Towell, J. W. Shavlik, "Training Knowledge-Based Neural Networks to Recognize
  Genes in DNA Sequences", *Advances in Neural Information Processing Systems 3* (NIPS 1990), Morgan
  Kaufmann (trang NeurIPS proceedings, đọc 21/11/2026; `splice.names` ghi năm 1991).
- C. Burge, S. Karlin, "Prediction of complete gene structures in human genomic DNA", *J. Mol. Biol.*
  268(1):78–94, 1997, DOI 10.1006/jmbi.1997.0951. Tóm tắt: "new models of the donor and acceptor splice
  signals are described which capture potentially important dependencies between signal positions"
  (Europe PMC, đọc 21/11/2026).
- X. Roca, A. R. Krainer, I. C. Eperon, "Pick one, but be quick: 5' splice sites and the problems of too
  many choices", *Genes Dev.* 27(2):129–144, 2013, DOI 10.1101/gad.209759.112. Tóm tắt: "Most 5'ss are
  recognized by base-pairing with the 5' end of the U1 small nuclear RNA (snRNA)" (Europe PMC, đọc
  21/11/2026).
