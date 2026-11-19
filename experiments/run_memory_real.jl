# Memory of baseline vs bitset on the real benchmark datasets.
# Every observation is a fresh Julia process (memory_real_worker.jl); never warmed on the measured data.
# Usage: julia --project experiments/run_memory_real.jl
include("dataset_benchmarks.jl")
include("memory_real_worker.jl")   # for self_check only; the worker itself runs in fresh processes
using .DatasetBenchmarks, EclatMining, TOML, Dates, Statistics

const D = DatasetBenchmarks
const CONFIG = joinpath(@__DIR__, "configs", "memory_real.toml")
const WORKER = joinpath(@__DIR__, "memory_real_worker.jl")
const MINERS = ("baseline", "bitset")

function parse_result(log)
    for line in reverse(readlines(log))
        startswith(line, "MEMORY_RESULT ") || continue
        f = split(line)[2:end]
        return (; before=parse(Int, f[1]), peak_before=parse(Int, f[2]), peak=parse(Int, f[3]),
                  itemsets=parse(Int, f[4]), seconds=parse(Float64, f[5]), bytes=parse(Int, f[6]), estimate=parse(Int, f[7]))
    end
    return nothing
end

function main()
    check = self_check()
    println("Self-check ok: bitset ", check.bits, " vs formula ", check.bits_formula,
            "; TID-list ", check.tids, " vs formula ", check.tids_formula)
    config = TOML.parsefile(CONFIG)
    grid = TOML.parsefile(D.CONFIG)["minsup"]
    manifest = Dict(d["id"] => d for d in TOML.parsefile(joinpath(D.ROOT, "data", "datasets.toml"))["dataset"])
    for c in config["case"]
        haskey(manifest, c["dataset"]) || error("Unknown dataset: ", c["dataset"])
        c["minsup"] in grid[c["dataset"]] || error("minsup ", c["minsup"], " is not in the runtime grid of ", c["dataset"])
        d = manifest[c["dataset"]]
        D.filehash(joinpath(D.ROOT, d["processed_path"])) == d["processed_sha256"] || error("Dataset checksum mismatch: ", c["dataset"])
    end
    runid = "memory_real_" * Dates.format(now(UTC), "yyyymmddTHHMMSS")
    dir = joinpath(D.ROOT, "results", "metrics", "benchmark_runs", runid)
    mkpath(dir)
    rows = NamedTuple[]
    open(joinpath(dir, "raw.csv"), "w") do raw
        D.csvrow(raw, ("dataset", "minsup", "threshold", "miner", "repeat", "status", "rss_before_bytes",
                       "peak_rss_before_mining_bytes", "peak_rss_bytes", "delta_peak_rss_bytes", "delta_status", "vertical_summarysize_bytes", "vertical_estimate_bytes",
                       "seconds", "itemsets", "log"))
        for c in config["case"]
            d = manifest[c["dataset"]]
            input = joinpath(D.ROOT, d["processed_path"])
            threshold = minsup_abs(c["minsup"], d["transactions"])
            for rep in 1:config["repeats"], miner in (isodd(rep) ? MINERS : reverse(MINERS))
                log = joinpath(dir, "$(c["dataset"])_$(threshold)_$(miner)_$(rep).log")
                cmd = `$(Base.julia_cmd()) --startup-file=no --threads=1 --project=$(D.ROOT) $WORKER $input $(c["minsup"]) $miner`
                sample = D.timed_process(cmd, log, config["timeout_seconds"])
                status = sample.status
                r = status == "success" ? parse_result(log) : nothing
                status == "success" && r === nothing && (status = "validation_failed")
                status == "timeout" && println("TIMEOUT: ", c["dataset"], " ", c["minsup"], " ", miner,
                                               " exceeded ", config["timeout_seconds"], " s")
                # The process peak may already have been reached before mining (startup, JIT, loading).
                # Only a peak that grew during mining gives a real delta; otherwise it is not measurable.
                grew = r !== nothing && r.peak > r.peak_before
                delta = grew ? r.peak - r.before : missing
                dstatus = r === nothing ? missing : grew ? "measured" : "below_process_peak"
                D.csvrow(raw, (c["dataset"], c["minsup"], threshold, miner, rep, status,
                               r === nothing ? missing : r.before, r === nothing ? missing : r.peak_before,
                               r === nothing ? missing : r.peak, delta, dstatus,
                               r === nothing ? missing : r.bytes, r === nothing ? missing : r.estimate, r === nothing ? missing : r.seconds,
                               r === nothing ? missing : r.itemsets, relpath(log, D.ROOT)))
                push!(rows, (; dataset=c["dataset"], minsup=c["minsup"], threshold, miner, status, r, delta, dstatus))
                println(c["dataset"], " ", c["minsup"], " ", miner, " #", rep, ": ", status)
            end
        end
    end
    # Summary: median over successful repeats; itemset counts of baseline and bitset must agree.
    mismatches = String[]
    open(joinpath(dir, "summary.csv"), "w") do io
        D.csvrow(io, ("dataset", "minsup", "threshold", "miner", "status", "repeats_ok", "median_delta_peak_rss_bytes", "delta_measured_repeats",
                      "vertical_summarysize_bytes", "vertical_estimate_bytes", "median_seconds", "itemsets"))
        for c in config["case"]
            counts = Set{Int}()
            for miner in MINERS
                sel = filter(x -> x.dataset == c["dataset"] && x.minsup == c["minsup"] && x.miner == miner, rows)
                ok = filter(x -> x.status == "success", sel)
                status = length(ok) == length(sel) ? "success" : any(x -> x.status == "timeout", sel) ? "timeout" : "failed"
                if isempty(ok)
                    D.csvrow(io, (c["dataset"], c["minsup"], sel[1].threshold, miner, status, 0, missing, 0, missing, missing, missing, missing))
                    println("NOT COMPARABLE: ", c["dataset"], " ", c["minsup"], " ", miner, " has no successful run")
                    continue
                end
                deltas = [x.delta for x in ok if x.dstatus == "measured"]
                union!(counts, (x.r.itemsets for x in ok))
                D.csvrow(io, (c["dataset"], c["minsup"], sel[1].threshold, miner, status, length(ok),
                              isempty(deltas) ? missing : round(Int, median(deltas)), length(deltas), first(ok).r.bytes, first(ok).r.estimate,
                              median(x.r.seconds for x in ok), first(ok).r.itemsets))
            end
            length(counts) <= 1 || push!(mismatches, c["dataset"] * " " * c["minsup"] * ": " * string(sort!(collect(counts))))
        end
    end
    open(io -> TOML.print(io, Dict("config" => config, "julia" => string(VERSION), "os" => string(Sys.KERNEL),
            "cpu" => Sys.cpu_info()[1].model, "ram_bytes" => Sys.total_memory(),
            "commit" => strip(read(`git -C $(D.ROOT) rev-parse HEAD`, String)),
            "dirty" => !isempty(read(`git -C $(D.ROOT) status --porcelain`, String)),
            "artifacts" => Dict(f => D.filehash(joinpath(dir, f)) for f in ("raw.csv", "summary.csv")))),
         joinpath(dir, "environment.toml"), "w")
    println("Artifacts: ", dir)
    isempty(mismatches) || error("Itemset counts differ between baseline and bitset (or between repeats): ", join(mismatches, "; "))
    return dir
end

abspath(PROGRAM_FILE) == (@__FILE__) && main()
