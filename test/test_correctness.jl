# Kiểm thử tính đúng đắn: so khớp itemset, toy 15 itemset, edge case, đối chiếu output thật của SPMF.
# Chạy qua test/runtests.jl (file đó định nghĩa TOY_DIR, EXPECTED_DIR, TOY_40, toy() và reference_mine).

using Test
using EclatMining

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

    # File bẩn SPMF không đọc được: nhóm đọc file bẩn, SPMF đọc bản clean_spmf của nó (8 giao dịch, có giao dịch rỗng).
    dirty = read_spmf(toy("dup_items_comments.txt"))
    @test length(dirty) == 8
    @testset "dup_items_comments (bẩn) @ $pct%" for pct in (20, 40, 60)
        spmf = read_spmf_output(joinpath(EXPECTED_DIR, "dup_items_comments_cleaned_$pct.txt"))
        @test is_exact_match(compare_itemsets(eclat(dirty, minsup_abs(pct // 100, length(dirty))), spmf))
    end
end
