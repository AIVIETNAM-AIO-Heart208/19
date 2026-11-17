# Goal 2: each observation uses a fresh worker, one miner and one large call.
include("goal2_common.jl")
using .Goal2, EclatMining, TOML
function worker(id, name)
    config = TOML.parsefile(Goal2.CONFIG)
    c = config["case"][id]
    f = Goal2.miner(name)
    # Compile the same API on a tiny input, never warm up on the measured database.
    f([[1, 2], [1], Int[]], 1)
    db = Goal2.database(c, config["seed"])
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
    config = TOML.parsefile(Goal2.CONFIG)
    initial = Goal2.begin_run("memory")
    open(joinpath(Goal2.ROOT, "results", "metrics", "goal2_memory_raw.csv"), "w") do io
        println(io, "case_id,miner,repeat,peak_process_rss_bytes,itemsets")
        for id in eachindex(config["case"]), rep in 1:config["memory_repeats"]
            order = isodd(rep) ? ("baseline", "bitset") : ("bitset", "baseline")
            for name in order
                cmd = `$(Base.julia_cmd()) --startup-file=no --threads=1 --project=$(Goal2.ROOT) $(@__FILE__) --worker $id $name`
                output = strip(read(cmd, String))
                println(io, id, ',', name, ',', rep, ',', output)
                flush(io)
                println("Measured peak RSS case ", id, " ", name, " repeat ", rep)
            end
        end
    end
    Goal2.metadata("memory", config, initial)
end
abspath(PROGRAM_FILE) == (@__FILE__) && main(ARGS)
