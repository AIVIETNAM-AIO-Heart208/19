# Optimization comparison: complete public API calls, warmed JIT, alternating paired order.
include("benchmark_common.jl")
using .BenchmarkSupport, EclatMining, TOML
function measure(f, db, threshold)
    GC.gc()
    sample = @timed f(db, threshold)
    return sample.time, sample.bytes, length(sample.value)
end
function main()
    config = TOML.parsefile(BenchmarkSupport.CONFIG)
    initial = BenchmarkSupport.begin_run("runtime")
    path = joinpath(BenchmarkSupport.ROOT, "results", "metrics", "optimization_runtime_raw.csv")
    open(path, "w") do io
        println(io, "case_id,dataset,n,items,mean_length,minsup,threshold,miner,repeat,seconds,allocated_bytes,itemsets")
        for (id, c) in enumerate(config["case"])
            db = BenchmarkSupport.database(c, config["seed"])
            threshold = minsup_abs(c["minsup"], length(db))
            a, b = eclat_baseline(db, threshold), eclat_bitset(db, threshold)
            @assert is_exact_match(compare_itemsets(a, b))
            expected = length(a)
            a = b = nothing
            width = sum(length, db) / length(db)
            for rep in 1:config["repeats"]
                order = isodd(rep) ? ("baseline", "bitset") : ("bitset", "baseline")
                for name in order
                    seconds, bytes, count = measure(BenchmarkSupport.miner(name), db, threshold)
                    @assert count == expected
                    println(io, join((id, c["name"], length(db), c["items"], width,
                                      c["minsup"], threshold, name, rep, seconds, bytes, count), ','))
                end
            end
            println("Measured runtime case ", id, ": ", expected, " patterns; exact agreement")
        end
    end
    # Summarize each case without introducing a Statistics package dependency.
    rows = [split(line, ',') for line in readlines(path)[2:end]]
    open(joinpath(dirname(path), "optimization_runtime_summary.csv"), "w") do io
        println(io, "case_id,miner,median_seconds,iqr_seconds,median_allocated_bytes")
        for id in eachindex(config["case"]), name in ("baseline", "bitset")
            group = filter(r -> parse(Int, r[1]) == id && r[8] == name, rows)
            times = [parse(Float64, r[10]) for r in group]
            bytes = [parse(Float64, r[11]) for r in group]
            println(io, join((id, name, BenchmarkSupport.percentile(times, .5),
                              BenchmarkSupport.percentile(times, .75) - BenchmarkSupport.percentile(times, .25),
                              BenchmarkSupport.percentile(bytes, .5)), ','))
        end
    end
    BenchmarkSupport.metadata("runtime", config, initial)
end
abspath(PROGRAM_FILE) == (@__FILE__) && main()
