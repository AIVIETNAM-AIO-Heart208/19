# Run after runtime and memory scripts. No measurements are taken here.
include("goal2_common.jl")
using .Goal2, TOML
function main()
    dir = joinpath(Goal2.ROOT, "results", "metrics")
    config = Goal2.validate_runs(dir)
    runtime = [split(l, ',') for l in readlines(joinpath(dir, "goal2_runtime_summary.csv"))[2:end]]
    raw = [split(l, ',') for l in readlines(joinpath(dir, "goal2_runtime_raw.csv"))[2:end]]
    memory = [split(l, ',') for l in readlines(joinpath(dir, "goal2_memory_raw.csv"))[2:end]]
    open(joinpath(dir, "goal2_comparison.csv"), "w") do io
        println(io, "case_id,dataset,n,items,mean_length,minsup,itemsets,baseline_seconds,bitset_seconds,speedup,baseline_allocated_bytes,bitset_allocated_bytes,baseline_peak_rss_bytes,bitset_peak_rss_bytes")
        for id in eachindex(config["case"])
            getrow(name) = only(filter(r -> parse(Int, r[1]) == id && r[2] == name, runtime))
            a, b = getrow("baseline"), getrow("bitset")
            example = first(filter(r -> parse(Int, r[1]) == id, raw))
            peak(name) = Goal2.percentile([parse(Float64, r[4]) for r in memory
                                          if parse(Int, r[1]) == id && r[2] == name], .5)
            for name in ("baseline", "bitset")
                group = filter(r -> parse(Int, r[1]) == id && r[2] == name, memory)
                @assert length(group) == config["memory_repeats"]
                @assert all(r[5] == example[12] for r in group)
            end
            println(io, join((id, example[2:6]..., example[12], a[3], b[3],
                              parse(Float64, a[3]) / parse(Float64, b[3]),
                              a[5], b[5], peak("baseline"), peak("bitset")), ','))
        end
    end
end
abspath(PROGRAM_FILE) == (@__FILE__) && main()
