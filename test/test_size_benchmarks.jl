include(joinpath(@__DIR__,"..","experiments","size_benchmarks.jl"))
@testset "Size experiment data contracts" begin
    S = SizeBenchmarks
    @test_throws Exception S.main("unknown",String[])
    @test basename(S.config_path("scalability",String[])) == "scalability.toml"
    @test basename(S.config_path("scalability",["--dataset=retail"])) == "scalability.toml"
    @test basename(S.config_path("scalability",["--dataset=accidents"])) == "scalability_accidents.toml"
    @test_throws Exception S.config_path("scalability",["--dataset=unknown"])
    @test_throws Exception S.config_path("transaction_length",["--dataset=accidents"])
    @test_throws Exception S.config_path("scalability",["--dataset=retail","--dataset=accidents"])
    indices = S.sample_indices(101,[10,25,50,75,100],42)
    @test length.(indices) == [10,25,50,75,101]
    @test indices == S.sample_indices(101,[10,25,50,75,100],42)
    @test indices[end] == collect(1:101)
    @test all(allunique,indices)
    @test all(issubset(indices[i],indices[i+1]) for i in 1:4)
    @test_throws Exception S.sample_indices(1,[10,100],42)
    @test_throws Exception S.sample_indices(10,[100,10],42)
    data = S.length_databases(30,8,[2,4,6],42)
    @test data == S.length_databases(30,8,[2,4,6],42)
    @test all(length(db)==30 for db in data)
    @test all(all(length(tx)==l && issorted(tx) && allunique(tx) && all(x->1<=x<=8,tx) for tx in db) for (db,l) in zip(data,[2,4,6]))
    @test all(issubset(data[i][t],data[i+1][t]) for i in 1:2 for t in 1:30)
    @test_throws Exception S.length_databases(0,8,[2],42)
    @test_throws Exception S.length_databases(10,8,[9],42)
    previous = Dict{Vector{Int},Int}()
    for db in data
        before = deepcopy(db)
        result = eclat_bitset(db,3)
        @test db == before
        @test is_exact_match(compare_itemsets(result,reference_mine(db,3)))
        current = Dict(result)
        @test all(get(current,p,0)>=s for (p,s) in previous)
        previous = current
    end
    mktempdir() do dir
        path = joinpath(dir,"duplicate transactions.txt")
        S.write_transactions(path,[[1],[1],[2]])
        @test read_spmf(path) == [[1],[1],[2]]
    end
end
