# Kiểm thử tính đúng đắn: so khớp itemset, toy 15 itemset, edge case, đối chiếu output thật của SPMF.
# Chạy qua test/runtests.jl (file đó định nghĩa TOY_DIR, EXPECTED_DIR, TOY_40, toy() và reference_mine).

using Test
using TOML
using EclatMining
using Random

# Both production implementations must pass every shared test.
const IMPLEMENTED_MINERS = (eclat_baseline, eclat_bitset)

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

@testset "toy (contextPasquier99) — $miner" for miner in IMPLEMENTED_MINERS
    db = read_spmf(toy("toy.txt"))
    r40 = miner(db, minsup_abs(parse_minsup("40%"), length(db)))
    @test length(r40) == 15
    @test is_exact_match(compare_itemsets(r40, TOY_40))
    @test length(miner(db, 1)) == 19
    @test length(miner(db, 3)) == 9
    @test all(issorted(first(p)) && allunique(first(p)) for p in r40)
end

@testset "edge cases — $miner" for miner in IMPLEMENTED_MINERS
    # CSDL rỗng.
    @test isempty(miner(Vector{Int}[], 0))
    @test isempty(reference_mine(Vector{Int}[], 0))

    # minsup 100%: chỉ còn itemset có mặt trong mọi giao dịch.
    db = [[1, 2], [1, 2, 3], [1]]
    full = minsup_abs(parse_minsup("100%"), length(db))
    @test full == 3
    @test is_exact_match(compare_itemsets(miner(db, full), Dict([1] => 3)))
    toy_db = read_spmf(toy("toy.txt"))
    @test isempty(miner(toy_db, minsup_abs(parse_minsup("100%"), length(toy_db))))

    # Giao dịch trùng: mỗi bản sao được tính một lần vào support.
    @test is_exact_match(compare_itemsets(miner([[1, 2], [1, 2], [1, 2]], 3),
                                          Dict([1] => 3, [2] => 3, [1, 2] => 3)))

    # Item trùng trong dòng không được làm tăng support.
    dirty = read_spmf(toy("dup_items_comments.txt"))
    got = Dict(miner(dirty, 1))
    @test got[[5]] == 4          # dòng "5 5 5" chỉ tính một lần
    @test got[[2, 4]] == 2
end

# Danh sách case lấy từ cases.toml (do experiments/spmf/run_reference.jl ghi khi chạy SPMF thật),
# không lấy từ những file đang có trong thư mục: mất fixture nào thì case đó fail, không bị bỏ qua.
const SPMF_CASES = TOML.parsefile(joinpath(FIXTURES, "cases.toml"))["case"]

@testset "khớp SPMF — $miner" for miner in IMPLEMENTED_MINERS
    @test !isempty(SPMF_CASES)
    datasets = Set{String}()
    n_run = 0
    n_itemsets = 0
    @testset "$(splitext(basename(case["expected"]))[1])" for case in SPMF_CASES
        input = joinpath(FIXTURES, case["input"])
        expected = joinpath(FIXTURES, case["expected"])
        pct = case["minsup_percent"]::Int
        has_input, has_expected = isfile(input), isfile(expected)
        @test has_input
        @test has_expected
        if !(has_input && has_expected)
            @error "Thiếu fixture cho case $(case["expected"])" input has_input expected has_expected
        else
            db = read_spmf(input)
            threshold = minsup_abs(pct // 100, length(db))
            spmf = read_spmf_output(expected)
            @test length(spmf) == case["n_itemsets"]      # expected khớp số itemset SPMF báo lúc sinh
            push!(datasets, case["input"])
            n_itemsets += length(spmf)

            ours = compare_itemsets(miner(db, threshold), spmf)
            @test is_exact_match(ours)
            @test match_ratio(ours) == 1.0

            oracle = compare_itemsets(reference_mine(db, threshold), spmf)
            @test is_exact_match(oracle)
            n_run += 1
        end
    end
    @test n_run == length(SPMF_CASES)    # đủ mọi case đã khai báo đều chạy so khớp
    @test length(datasets) >= 5          # nhóm quy định so khớp SPMF trên ít nhất 5 CSDL khác nhau
    println("Khớp SPMF: ", n_run, "/", length(SPMF_CASES), " case, ", length(datasets),
            " CSDL, tổng ", n_itemsets, " itemset tham chiếu")

    # File bẩn SPMF không đọc được: nhóm đọc file bẩn, SPMF đọc bản clean_spmf của nó (8 giao dịch, có giao dịch rỗng).
    dirty = read_spmf(toy("dup_items_comments.txt"))
    @test length(dirty) == 8
    @testset "dup_items_comments (bẩn) @ $pct%" for pct in (20, 40, 60)
        spmf = read_spmf_output(joinpath(EXPECTED_DIR, "dup_items_comments_cleaned_$pct.txt"))
        @test is_exact_match(compare_itemsets(miner(dirty, minsup_abs(pct // 100, length(dirty))), spmf))
    end
end


@testset "API, invariants and oracle — $miner" for miner in IMPLEMENTED_MINERS
    @test isempty(miner(Vector{Int}[], 3))
    @test isempty(miner([Int[], Int[]], 1))
    @test isempty(miner([[1]], 2))
    @test miner([[0]], 1) == [[0] => 1]
    @test_throws ArgumentError miner(Vector{Int}[], -1)
    @test_throws ArgumentError miner([[1]], 0)
    for bad in ([[-1]], [[2, 1]], [[1, 1]])
        @test_throws ArgumentError miner(bad, 1)
        @test_throws ArgumentError miner(bad, 100)
    end
    db = [[0, 17, 1000], Int[], [0, 17, 1000], [17]]
    before = deepcopy(db)
    result = @inferred miner(db, 2)
    @test is_exact_match(compare_itemsets(result, reference_mine(db, 2)))
    @test result == miner(db, 2)
    @test eclat(db, 2) == result
    @test db == before
    @test all(allunique(first(p)) && issorted(first(p)) for p in result)
    # Changing one returned vector must not affect any other result or input.
    snapshot = deepcopy(result)
    push!(first(result[1]), 9999)
    @test result[2:end] == snapshot[2:end]
    @test db == before

    # More than 20 distinct items, but only the singleton {0} is frequent.
    large_universe = [[0, i] for i in 1:30]
    @test miner(large_universe, 2) == [[0] => 30]

    rng = MersenneTwister(20261117)
    for trial in 1:40
        random_db = [Int[i for i in 0:6 if rand(rng) < 0.4] for _ in 1:rand(rng, 1:12)]
        for threshold in unique([1, length(random_db), rand(rng, 1:length(random_db))])
            actual = miner(random_db, threshold)
            @test is_exact_match(compare_itemsets(actual, reference_mine(random_db, threshold)))
        end
    end

    # Exhaust all 3-transaction databases over three items, including extreme IDs.
    # This covers every pattern of empty/repeated/disjoint transactions and ties.
    universe = [0, 7, typemax(Int)]
    transactions = [Int[universe[j] for j in 1:3 if (mask >> (j - 1)) & 1 == 1]
                    for mask in 0:7]
    for a in transactions, b in transactions, c in transactions
        small_db = [a, b, c]
        for threshold in 1:3
            @test is_exact_match(compare_itemsets(miner(small_db, threshold),
                                                 reference_mine(small_db, threshold)))
        end
    end
end

@testset "packed mask boundaries" begin
    for n in (1, 63, 64, 65, 127, 128, 129)
        db = [Int[] for _ in 1:n]
        for tid in 1:n
            push!(db[tid], 0)
            tid in (1, 63, 64, 65, 127, 128, n) && push!(db[tid], 7)
            iseven(tid) && push!(db[tid], typemax(Int))
        end
        for threshold in unique([1, n, max(1, n ÷ 2)])
            @test is_exact_match(compare_itemsets(eclat_bitset(db, threshold),
                                                 eclat_baseline(db, threshold)))
        end
    end
end
