# TODO: Kiểm tra tính đúng đắn các chỉ số luật và bước chuyển đổi dữ liệu.

# Ứng dụng phân tích DNA quanh vị trí cắt nối (splice junction): đọc dữ liệu UCI, làm sạch,
# mã hóa thành giao dịch, khai thác theo lớp bằng Eclat của nhóm và các thống kê đi kèm.
# Chạy qua test/runtests.jl (file đó định nghĩa reference_mine, toy()).

using Test
using Random
using EclatMining

# Nhãn item -> id, viết test cho dễ đọc.
ids(enc, labels...) = [item_id(enc, l) for l in labels]

@testset "Splice: đọc dữ liệu" begin
    recs = read_splice(IOBuffer("EI, A-DONOR-1,  CAGGTA\r\nN,  B-NEG-2, ACGTNN\n\n"); window=6)
    @test length(recs) == 2
    @test recs[1] == SpliceRecord("EI", "A-DONOR-1", "CAGGTA")
    @test recs[2] == SpliceRecord("N", "B-NEG-2", "ACGTNN")
    @test read_splice(IOBuffer("IE, x, acgtac"); window=6)[1].seq == "ACGTAC"   # chữ thường -> hoa
    # Đọc từ đường dẫn file cho cùng kết quả như đọc từ IO.
    mktempdir() do dir
        path = joinpath(dir, "mini.data")
        write(path, "EI, A-DONOR-1,  CAGGTA\r\nN,  B-NEG-2, ACGTNN\n")
        @test read_splice(path; window=6) == recs
    end

    @test_throws ArgumentError read_splice(IOBuffer("XX, a, ACGTAC"); window=6)   # lớp lạ
    @test_throws ArgumentError read_splice(IOBuffer("EI, a, ACGTA"); window=6)    # sai độ dài
    @test_throws ArgumentError read_splice(IOBuffer("EI, a, ACGTAZ"); window=6)   # không phải mã IUPAC
    @test_throws ArgumentError read_splice(IOBuffer("EI, ACGTAC"); window=6)      # thiếu trường
    @test_throws ArgumentError read_splice(IOBuffer("EI, a, ACGTA"); window=5)    # cửa sổ lẻ
end

@testset "Splice: vị trí và nhãn item" begin
    # Cửa sổ 60: ký tự 1..30 là vị trí -30..-1 (phía trước ranh giới), 31..60 là +1..+30.
    @test EclatMining.position_offset(1, 60) == -30
    @test EclatMining.position_offset(30, 60) == -1
    @test EclatMining.position_offset(31, 60) == 1
    @test EclatMining.position_offset(60, 60) == 30

    nt = NucleotideEncoding(60)
    @test n_items(nt) == 240
    @test item_label(nt, 1) == "-30A"
    @test item_label(nt, 30 * 4 + 3) == "+1G"
    @test item_label(nt, 240) == "+30T"
    @test all(item_id(nt, item_label(nt, i)) == i for i in 1:240)
    @test_throws ArgumentError item_label(nt, 0)
    @test_throws ArgumentError item_label(nt, 241)
    @test_throws ArgumentError item_id(nt, "0A")     # không có vị trí 0
    @test_throws ArgumentError item_id(nt, "+31A")   # ngoài cửa sổ
    @test_throws ArgumentError item_id(nt, "+1R")    # R không phải nucleotide đơn

    ry = PurinePyrimidineEncoding(60)
    @test n_items(ry) == 120
    @test item_label(ry, 1) == "-30R"
    @test item_label(ry, 120) == "+30Y"
    @test all(item_id(ry, item_label(ry, i)) == i for i in 1:120)
end

@testset "Splice: mã hóa giao dịch" begin
    nt = NucleotideEncoding(6)   # vị trí -3 -2 -1 +1 +2 +3
    t = encode(nt, "CAGGTA")
    @test t == ids(nt, "-3C", "-2A", "-1G", "+1G", "+2T", "+3A")
    @test issorted(t)
    # Ký tự mơ hồ (N, R, ...) không sinh item: không đoán base.
    @test encode(nt, "CAGNTR") == ids(nt, "-3C", "-2A", "-1G", "+2T")
    @test_throws ArgumentError encode(nt, "CAGGT")

    ry = PurinePyrimidineEncoding(6)
    @test encode(ry, "CAGGTA") == ids(ry, "-3Y", "-2R", "-1R", "+1R", "+2Y", "+3R")
    # R (A hoặc G) chắc chắn là purin, Y (C hoặc T) chắc chắn là pyrimidin; N, S, D thì không biết.
    @test encode(ry, "RYNSDA") == ids(ry, "-3R", "-2Y", "+3R")
end

@testset "Splice: làm sạch" begin
    recs = [SpliceRecord("EI", "a", "CAGGTA"), SpliceRecord("EI", "b", "CAGGTA"),   # trùng, cùng lớp
            SpliceRecord("IE", "c", "TTAGGC"), SpliceRecord("N", "d", "TTAGGC"),    # cùng chuỗi, khác lớp
            SpliceRecord("N", "e", "ACGTAC"), SpliceRecord("IE", "f", "TTAGGC")]
    c = clean_splice(recs)
    @test [r.name for r in c.records] == ["a", "e"]          # giữ bản đầu tiên, giữ thứ tự gốc
    @test c.n_input == 6
    @test c.n_duplicates == 1
    @test [r.name for r in c.conflicting] == ["c", "d", "f"]  # nhãn mâu thuẫn: loại mọi bản
    @test class_counts(c.records) == Dict("EI" => 1, "IE" => 0, "N" => 1)
end

@testset "Splice: khai thác theo lớp bằng Eclat của nhóm" begin
    # Cửa sổ 4 -> 16 item, đủ nhỏ cho oracle brute-force (≤ 20 item).
    data = """
    EI, d1, AGGT
    EI, d2, AGGT
    EI, d3, CGGT
    EI, d4, AGGA
    IE, a1, AGGC
    IE, a2, TAGG
    N,  n1, ACGT
    N,  n2, TTCA
    N,  n3, GGTC
    """
    recs = read_splice(IOBuffer(data); window=4)
    nt = NucleotideEncoding(4)
    db_ei = class_transactions(recs, "EI", nt)
    @test length(db_ei) == 4
    @test db_ei[1] == ids(nt, "-2A", "-1G", "+1G", "+2T")
    for cls in ("EI", "IE", "N"), ms in (1 // 4, 1 // 2, 3 // 4)
        db = class_transactions(recs, cls, nt)
        got = mine_class(db, ms)
        @test EclatMining.itemset_dict(got) == EclatMining.itemset_dict(reference_mine(db, minsup_abs(ms, length(db))))
    end
    # minsup dạng chuỗi đi qua parse_minsup: "75%" và "0.75" giống 3//4.
    @test mine_class(db_ei, "75%") == mine_class(db_ei, 3 // 4)
    @test mine_class(db_ei, "0.75") == mine_class(db_ei, 3 // 4)
    @test EclatMining.itemset_dict(mine_class(db_ei, 3 // 4)) == Dict(
        ids(nt, "-2A") => 3, ids(nt, "-1G") => 4, ids(nt, "+1G") => 4, ids(nt, "+2T") => 3,
        ids(nt, "-2A", "-1G") => 3, ids(nt, "-2A", "+1G") => 3, ids(nt, "-1G", "+1G") => 4,
        ids(nt, "-1G", "+2T") => 3, ids(nt, "+1G", "+2T") => 3,
        ids(nt, "-2A", "-1G", "+1G") => 3, ids(nt, "-1G", "+1G", "+2T") => 3)
end

@testset "maximal_itemsets" begin
    db = read_spmf(toy("toy.txt"))
    @test maximal_itemsets(eclat(db, 2)) == [[1, 2, 3, 5] => 2]
    @test sort(first.(maximal_itemsets(eclat(db, 3)))) == [[1, 3], [2, 3, 5]]
    @test isempty(maximal_itemsets(Pair{Vector{Int},Int}[]))

    # Đối chiếu định nghĩa: tối đại khi không có itemset phổ biến nào chứa nó thật sự.
    rng = MersenneTwister(42)
    for _ in 1:20
        rdb = [sort!(unique(rand(rng, 1:8, rand(rng, 1:6)))) for _ in 1:15]
        res = eclat(rdb, 3)
        sets = first.(res)
        brute = [p for p in res if !any(Y -> length(Y) > length(first(p)) && issubset(first(p), Y), sets)]
        @test sort(maximal_itemsets(res)) == sort(brute)
    end
end

@testset "support_count" begin
    bits = transaction_bits([[1, 2, 3], [2, 3], [1, 3], Int[]], 3)
    @test support_count(bits, [1, 3]) == 2
    @test support_count(bits, [2]) == 2
    @test support_count(bits, [1, 2, 3]) == 1
    @test support_count(bits, Int[]) == 4
    @test_throws ArgumentError transaction_bits([[4]], 3)
end

@testset "Thống kê so sánh lớp" begin
    # X có mặt ở 8/10 chuỗi EI, 1/10 IE, 2/20 N.
    r = class_contrast(8, Dict("EI" => 8, "IE" => 1, "N" => 2), Dict("EI" => 10, "IE" => 10, "N" => 20), "EI")
    @test r.freq ≈ 0.8
    @test r.freq_n ≈ 0.1
    @test r.growth_vs_n ≈ 8.0
    @test r.confidence ≈ 8 / 11          # P(EI | X) trên toàn bộ dữ liệu đã làm sạch
    @test r.lift ≈ (8 / 11) / (10 / 40)  # chia cho tỉ lệ lớp EI
    # Không gặp ở lớp N: tỉ số tăng là vô hạn, không chia cho 0.
    r0 = class_contrast(5, Dict("EI" => 5, "IE" => 0, "N" => 0), Dict("EI" => 10, "IE" => 10, "N" => 20), "EI")
    @test r0.growth_vs_n == Inf
    @test r0.confidence ≈ 1.0
    @test_throws ArgumentError class_contrast(8, Dict("EI" => 7, "IE" => 1, "N" => 2),
                                              Dict("EI" => 10, "IE" => 10, "N" => 20), "EI")
end

@testset "Phụ thuộc giữa hai vị trí" begin
    # n = 10, sup(a) = 6, sup(b) = 5, sup(ab) = 2 -> bảng 2x2 [2 4; 3 1].
    d = pair_dependence(2, 6, 5, 10)
    @test d.lift ≈ 10 * 2 / (6 * 5)
    @test d.chi2 ≈ 10 * (2 * 1 - 4 * 3)^2 / (6 * 4 * 5 * 5)
    # Kỳ vọng các ô khi độc lập: 6·5/10 = 3, 6·5/10 = 3, 4·5/10 = 2, 4·5/10 = 2.
    @test d.min_expected ≈ 2.0
    # Gần như mọi chuỗi có cả a lẫn b: ô "không a, không b" kỳ vọng rất nhỏ, χ² không dùng được.
    @test pair_dependence(671, 677, 671, 679).min_expected < 5
    @test pair_dependence(3, 6, 5, 10).lift ≈ 1.0                    # độc lập đúng kỳ vọng
    @test pair_dependence(3, 6, 5, 10).chi2 ≈ 0.0
    @test isnan(pair_dependence(5, 10, 5, 10).chi2)                  # a có ở mọi chuỗi: χ² không xác định
    @test_throws ArgumentError pair_dependence(6, 5, 7, 10)          # sup(ab) > sup(a)

    nt = NucleotideEncoding(4)
    rows = pair_table(mine_class(class_transactions(read_splice(IOBuffer(
        "EI, a, AGGT\nEI, b, AGGT\nEI, c, CGGA\nEI, d, AGTA\n"); window=4), "EI", nt), 1 // 2), 4)
    ag = only(r for r in rows if r.a == item_id(nt, "-2A") && r.b == item_id(nt, "+2T"))
    @test (ag.sup_ab, ag.sup_a, ag.sup_b) == (2, 3, 2)
    @test ag.lift ≈ 4 * 2 / (3 * 2)
end

@testset "Chuỗi minh họa mẫu và khớp IUPAC" begin
    nt = NucleotideEncoding(60)
    X = ids(nt, "-1G", "+1G", "+2T", "+4A", "+5G")
    @test pattern_string(nt, X; from=-3, to=6) == "..G|GT.AG."
    ry = PurinePyrimidineEncoding(60)
    @test pattern_string(ry, ids(ry, "-3Y", "-2R", "-1R"); from=-3, to=1) == "YRR|."
    @test_throws ArgumentError pattern_string(nt, X; from=0, to=3)

    # Mẫu chuẩn donor trong tài liệu dữ liệu: MAGGTRAGT bắt đầu tại -3 (M = A/C, R = A/G).
    seq = "A"^27 * "CAGGTAAGT" * "A"^24
    @test matches_consensus(seq, "MAGGTRAGT", -3)
    @test !matches_consensus("A"^27 * "CAGGTAAGA" * "A"^24, "MAGGTRAGT", -3)
    @test !matches_consensus("A"^27 * "CAGNTAAGT" * "A"^24, "MAGGTRAGT", -3)   # N không khớp G
    @test matches_consensus("A"^30 * "G" * "A"^29, "G", 1)
    @test_throws ArgumentError matches_consensus(seq, "MAGGTRAGT", 28)         # vượt cửa sổ
end
