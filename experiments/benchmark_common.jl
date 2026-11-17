# Shared helpers for optimization benchmarks; no external dependencies.
module BenchmarkSupport
using EclatMining, Random, TOML, SHA
const ROOT = normpath(joinpath(@__DIR__, ".."))
const CONFIG = joinpath(@__DIR__, "configs", "optimization.toml")
miner(name) = name == "baseline" ? eclat_baseline : name == "bitset" ? eclat_bitset : error("unknown miner")
function database(c, seed)
    rng = MersenneTwister(seed)
    return [Int[i for i in 1:c["items"] if rand(rng) < c["probability"]] for _ in 1:c["n"]]
end
const METRICS = joinpath(ROOT, "results", "metrics")
filehash(path) = bytes2hex(open(sha256, path))
function snapshot()
    paths = ["Project.toml", "experiments/configs/optimization.toml", "experiments/benchmark_common.jl",
             "experiments/run_runtime.jl", "experiments/run_memory.jl", "experiments/summarize_optimization.jl"]
    for (root, _, files) in walkdir(joinpath(ROOT, "src")), file in files
        endswith(file, ".jl") && push!(paths, relpath(joinpath(root, file), ROOT))
    end
    return Dict("files" => Dict(p => filehash(joinpath(ROOT, p)) for p in paths),
                "julia" => string(VERSION), "os" => string(Sys.KERNEL),
                "cpu" => Sys.CPU_NAME, "threads" => Threads.nthreads())
end
artifacts(kind) = kind == "runtime" ? ("optimization_runtime_raw.csv", "optimization_runtime_summary.csv") :
                   kind == "memory" ? ("optimization_memory_raw.csv",) : error("unknown measurement kind")
function begin_run(kind)
    Threads.nthreads() == 1 || error("Run benchmarks with --threads=1")
    mkpath(METRICS)
    rm(joinpath(METRICS, "optimization_$(kind)_environment.toml"); force=true)
    rm(joinpath(METRICS, "optimization_comparison.csv"); force=true)
    return snapshot()
end
function metadata(kind, config, initial; dir=METRICS)
    initial == snapshot() || error("Code/config/environment changed during measurement; rerun")
    config == TOML.parsefile(CONFIG) || error("Config changed during measurement")
    info = Dict("provenance" => initial, "config" => config,
                "commit" => strip(read(`git -C $ROOT rev-parse HEAD`, String)),
                "dirty" => !isempty(read(`git -C $ROOT status --porcelain`, String)),
                "artifacts" => Dict(p => filehash(joinpath(dir, p)) for p in artifacts(kind)))
    target = joinpath(dir, "optimization_$(kind)_environment.toml")
    open(target * ".tmp", "w") do io
        TOML.print(io, info)
    end
    mv(target * ".tmp", target; force=true)
end
# Validate provenance and file integrity BEFORE the summary opens its output.
function validate_runs(dir=METRICS)
    expected = snapshot()
    config = TOML.parsefile(CONFIG)
    for kind in ("runtime", "memory")
        path = joinpath(dir, "optimization_$(kind)_environment.toml")
        isfile(path) || error("Missing completed $kind run; rerun measurements")
        info = TOML.parsefile(path)
        info["provenance"] == expected || error("Incompatible $kind code/config/environment; rerun both measurements")
        info["config"] == config || error("Incompatible $kind configuration")
        for file in artifacts(kind)
            path = joinpath(dir, file)
            isfile(path) && filehash(path) == get(info["artifacts"], file, "") ||
                error("Incomplete or modified $kind artifact: $file")
        end
    end
    return config
end
function percentile(values, q)
    v = sort(values)
    pos = 1 + (length(v) - 1) * q
    lo, hi = floor(Int, pos), ceil(Int, pos)
    return v[lo] + (v[hi] - v[lo]) * (pos - lo)
end
end
