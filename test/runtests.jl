# Chạy: julia --project test/runtests.jl
# Đối chiếu ba bên: eclat (của nhóm) — output thật của SPMF (test/expected) — oracle brute-force.

using Test
using EclatMining

include(joinpath(@__DIR__, "reference_miner.jl"))   # reference_mine: oracle, không phải bài nộp

const ROOT = normpath(joinpath(@__DIR__, ".."))
const TOY_DIR = joinpath(ROOT, "data", "toy")
const EXPECTED_DIR = joinpath(ROOT, "test", "expected")
toy(name::String) = joinpath(TOY_DIR, name)

# Kết quả toy ở minsup 40% (= 2), theo CLAUDE.md mục 4.
const TOY_40 = Dict{Vector{Int},Int}(
    [1] => 3, [2] => 4, [3] => 4, [5] => 4,
    [1, 2] => 2, [1, 3] => 3, [1, 5] => 2, [2, 3] => 3, [2, 5] => 4, [3, 5] => 3,
    [1, 2, 3] => 2, [1, 2, 5] => 2, [1, 3, 5] => 2, [2, 3, 5] => 3,
    [1, 2, 3, 5] => 2,
)

@testset "EclatMining" begin

    @testset "read_spmf" begin
        db = read_spmf(toy("toy.txt"))
        @test db == [[1, 3, 4], [2, 3, 5], [1, 2, 3, 5], [2, 5], [1, 2, 3, 5]]
        @test length(db) == 5

        # Giao dịch trùng nhau phải được giữ nguyên.
        dup = read_spmf(toy("dup_tx.txt"))
        @test length(dup) == 10
        @test count(==([1, 2, 3]), dup) == 3

        # Dòng trống, dòng @ # %, dấu cách thừa, item chưa sort, item trùng trong dòng.
        dirty = read_spmf(toy("dup_items_comments.txt"))
        @test dirty == [[1, 2, 3], [1, 2, 3, 5], [5], [1, 2, 4], [2, 4], [1, 3, 5], [1, 2, 3, 5]]
        @test dirty == read_spmf(toy("dup_items_comments_clean.txt"))

        @test isempty(read_spmf(toy("empty.txt")))

        # Đọc từ IOBuffer: CRLF, BOM, tab, thiếu newline cuối file.
        io = IOBuffer("﻿3 1\r\n\r\n#x\r\n2\t2  1")
        @test EclatMining.read_transactions(io) == [[1, 3], [1, 2]]

        @test_throws ArgumentError EclatMining.read_transactions(IOBuffer("1 a 3\n"))
        @test_throws ArgumentError EclatMining.read_transactions(IOBuffer("1 -2 3\n"))

        @test (@inferred read_spmf(toy("toy.txt"))) isa Vector{Vector{Int}}
    end

    @testset "parse_minsup / minsup_abs" begin
        @test parse_minsup("40%") == 2 // 5
        @test parse_minsup("0.4") == 2 // 5
        @test parse_minsup(" .5 ") == 1 // 2
        @test parse_minsup("1") == 1
        @test parse_minsup("1.0") == 1
        @test parse_minsup("100%") == 1
        @test parse_minsup("0.5%") == 1 // 200

        @test minsup_abs(parse_minsup("40%"), 5) == 2     # 2.0 đúng số nguyên
        @test minsup_abs(parse_minsup("0.4"), 5) == 2
        @test minsup_abs(parse_minsup("21%"), 5) == 2     # 1.05 -> 2
        @test minsup_abs(parse_minsup("39%"), 5) == 2     # 1.95 -> 2
        @test minsup_abs(parse_minsup("7%"), 100) == 7    # bẫy float: ceil(0.07*100) == 8
        @test ceil(Int, 0.07 * 100) == 8                  # chứng minh cái bẫy là có thật
        @test minsup_abs(parse_minsup("100%"), 5) == 5
        @test minsup_abs(parse_minsup("100%"), 88162) == 88162
        @test minsup_abs(parse_minsup("0.1%"), 5) == 1    # minsup rất nhỏ vẫn ≥ 1
        @test minsup_abs(parse_minsup("40%"), 0) == 0     # CSDL rỗng
        @test minsup_abs("40%", 5) == 2                   # phiên bản nhận thẳng chuỗi

        for bad in ("0", "0%", "0.0", "1.01", "101%", "-0.4", "abc", "", "%", ".", "4e-1", "40 %%")
            @test_throws ArgumentError parse_minsup(bad)
        end

        @test (@inferred parse_minsup("40%")) isa Rational{Int}
        @test (@inferred minsup_abs(2 // 5, 5)) isa Int
    end

    @testset "write_spmf / read_spmf_output" begin
        mktempdir() do dir
            path = joinpath(dir, "out.txt")

            # Định dạng từng dòng; itemset chưa sort phải được ghi tăng dần.
            @test write_spmf(path, [[3, 1] => 2, [2] => 4]) == 2
            @test readlines(path) == ["2 #SUP: 4", "1 3 #SUP: 2"]

            # Round-trip từ Vector các Pair.
            result = eclat(read_spmf(toy("toy.txt")), 2)
            write_spmf(path, result)
            @test read_spmf_output(path) == TOY_40
            @test length(readlines(path)) == 15

            # Round-trip từ Dict.
            write_spmf(path, TOY_40)
            @test read_spmf_output(path) == TOY_40

            # Kết quả rỗng.
            @test write_spmf(path, Pair{Vector{Int},Int}[]) == 0
            @test isempty(read_spmf_output(path))
        end

        # Output thật của SPMF có 2 dòng header bắt đầu bằng @.
        spmf = read_spmf_output(joinpath(EXPECTED_DIR, "toy_40.txt"))
        @test spmf == TOY_40

        @test_throws ArgumentError EclatMining.read_itemsets(IOBuffer("1 2 3\n"))
        @test_throws ArgumentError EclatMining.read_itemsets(IOBuffer("1 2 #SUP: x\n"))
        @test_throws ArgumentError EclatMining.read_itemsets(IOBuffer("1 2 #SUP: 2\n2 1 #SUP: 2\n"))
        @test (@inferred read_spmf_output(joinpath(EXPECTED_DIR, "toy_40.txt"))) isa Dict{Vector{Int},Int}
    end

    @testset "compare_itemsets" begin
        same = compare_itemsets(TOY_40, copy(TOY_40))
        @test is_exact_match(same)
        @test match_ratio(same) == 1.0
        @test same.n_match == 15

        ours = Dict([1] => 3, [2] => 4, [1, 2] => 1, [9] => 7)   # sai support {1,2}, thừa {9}
        ref = Dict([1] => 3, [2] => 4, [1, 2] => 2, [3] => 4)    # nhóm thiếu {3}
        r = compare_itemsets(ours, ref)
        @test !is_exact_match(r)
        @test (r.n_ours, r.n_ref, r.n_match) == (4, 4, 2)
        @test r.missing_sets == [[3] => 4]
        @test r.extra_sets == [[9] => 7]
        @test r.wrong_support == [([1, 2], 1, 2)]
        @test match_ratio(r) == 2 / 5

        # Nhận cả Vector các Pair, không phụ thuộc thứ tự dòng hay thứ tự item.
        @test is_exact_match(compare_itemsets([[2, 1] => 2, [1] => 3], Dict([1] => 3, [1, 2] => 2)))
        @test_throws ArgumentError compare_itemsets([[1] => 3, [1] => 3], Dict([1] => 3))

        empty_result = compare_itemsets(Dict{Vector{Int},Int}(), Dict{Vector{Int},Int}())
        @test is_exact_match(empty_result) && match_ratio(empty_result) == 1.0
    end

    @testset "toy (contextPasquier99)" begin
        db = read_spmf(toy("toy.txt"))
        r40 = eclat(db, minsup_abs(parse_minsup("40%"), length(db)))
        @test length(r40) == 15
        @test is_exact_match(compare_itemsets(r40, TOY_40))
        @test length(eclat(db, 1)) == 19
        @test length(eclat(db, 3)) == 9
        @test all(issorted(first(p)) && allunique(first(p)) for p in r40)
    end

    @testset "edge cases" begin
        # CSDL rỗng.
        @test isempty(eclat(Vector{Int}[], 0))
        @test isempty(reference_mine(Vector{Int}[], 0))

        # minsup 100%: chỉ còn itemset có mặt trong mọi giao dịch.
        db = [[1, 2], [1, 2, 3], [1]]
        full = minsup_abs(parse_minsup("100%"), length(db))
        @test full == 3
        @test is_exact_match(compare_itemsets(eclat(db, full), Dict([1] => 3)))
        toy_db = read_spmf(toy("toy.txt"))
        @test isempty(eclat(toy_db, minsup_abs(parse_minsup("100%"), length(toy_db))))

        # Giao dịch trùng: mỗi bản sao được tính một lần vào support.
        @test is_exact_match(compare_itemsets(eclat([[1, 2], [1, 2], [1, 2]], 3),
                                              Dict([1] => 3, [2] => 3, [1, 2] => 3)))

        # Item trùng trong dòng không được làm tăng support.
        dirty = read_spmf(toy("dup_items_comments.txt"))
        got = Dict(eclat(dirty, 1))
        @test got[[5]] == 4          # dòng "5 5 5" chỉ tính một lần
        @test got[[2, 4]] == 2
    end

    # Mọi file output thật của SPMF: eclat của nhóm và oracle brute-force đều phải khớp 100%.
    @testset "khớp SPMF" begin
        files = sort(filter(f -> endswith(f, ".txt"), readdir(EXPECTED_DIR)))
        @test length(files) >= 15
        datasets = Set{String}()
        n_itemsets = 0
        @testset "$file" for file in files
            m = match(r"^(.+)_(\d+)\.txt$", file)
            @test m !== nothing
            name, pct = String(m.captures[1]), parse(Int, m.captures[2])
            push!(datasets, name)

            db = read_spmf(toy(name * ".txt"))
            threshold = minsup_abs(pct // 100, length(db))
            spmf = read_spmf_output(joinpath(EXPECTED_DIR, file))
            n_itemsets += length(spmf)

            ours = compare_itemsets(eclat(db, threshold), spmf)
            @test is_exact_match(ours)
            @test match_ratio(ours) == 1.0

            oracle = compare_itemsets(reference_mine(db, threshold), spmf)
            @test is_exact_match(oracle)
        end
        @test length(datasets) >= 5          # đề yêu cầu ít nhất 5 CSDL khác nhau
        println("Khớp SPMF: ", length(files), " file output, ", length(datasets),
                " CSDL, tổng ", n_itemsets, " itemset tham chiếu")

        # File bẩn SPMF không đọc được: đối chiếu qua output SPMF của bản đã làm sạch.
        dirty = read_spmf(toy("dup_items_comments.txt"))
        @testset "dup_items_comments (bẩn) @ $pct%" for pct in (20, 40, 60)
            spmf = read_spmf_output(joinpath(EXPECTED_DIR, "dup_items_comments_clean_$pct.txt"))
            @test is_exact_match(compare_itemsets(eclat(dirty, minsup_abs(pct // 100, length(dirty))), spmf))
        end
    end
end
