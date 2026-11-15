# Kiểm thử I/O: parser, writer, quy đổi minsup, round-trip, clean_spmf.
# Chạy qua test/runtests.jl (file đó định nghĩa TOY_DIR, EXPECTED_DIR, TOY_40, toy()).

using Test
using EclatMining

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
