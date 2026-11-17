# Optimization comparison: each observation uses a fresh worker, one miner and one large call.
include("benchmark_common.jl")
using .BenchmarkSupport, EclatMining, TOML
function worker(id, name)
    config = TOML.parsefile(BenchmarkSupport.CONFIG)
    c = config["case"][id]
    f = BenchmarkSupport.miner(name)
    # Compile the same API on a tiny input, never warm up on the measured database.
    f([[1, 2], [1], Int[]], 1)
    db = BenchmarkSupport.database(c, config["seed"])
    threshold = minsup_abs(c["minsup"], length(db))
    GC.gc()
    result = f(db, threshold)
    peak = Sys.maxrss()
    peak > 0 || error("peak RSS unsupported; refusing to report zero")
    println(peak, ',', length(result))
end
function main(args)
    if !isempty(args) && args[1] == "--worker"
        worker(parse(Int, args[2]), args[3])
        return
    end
    config = TOML.parsefile(BenchmarkSupport.CONFIG)
    initial = BenchmarkSupport.begin_run("memory")
    open(joinpath(BenchmarkSupport.ROOT, "results", "metrics", "optimization_memory_raw.csv"), "w") do io
        println(io, "case_id,miner,repeat,peak_process_rss_bytes,itemsets")
        for id in eachindex(config["case"]), rep in 1:config["memory_repeats"]
            order = isodd(rep) ? ("baseline", "bitset") : ("bitset", "baseline")
            for name in order
                cmd = `$(Base.julia_cmd()) --startup-file=no --threads=1 --project=$(BenchmarkSupport.ROOT) $(@__FILE__) --worker $id $name`
                output = strip(read(cmd, String))
                println(io, id, ',', name, ',', rep, ',', output)
                flush(io)
                println("Measured peak RSS case ", id, " ", name, " repeat ", rep)
            end
        end
    end
    BenchmarkSupport.metadata("memory", config, initial)
end
abspath(PROGRAM_FILE) == (@__FILE__) && main(ARGS)
