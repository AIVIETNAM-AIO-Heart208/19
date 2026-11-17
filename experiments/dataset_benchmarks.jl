module DatasetBenchmarks
using EclatMining, TOML, SHA, Dates, Statistics

const ROOT = normpath(joinpath(@__DIR__, ".."))
const CONFIG = joinpath(@__DIR__, "configs", "benchmarks.toml")
filehash(path) = bytes2hex(open(sha256, path))

function levels(values, n)
    ratios = parse_minsup.(values)
    thresholds = minsup_abs.(ratios, n)
    all(endswith(v, "%") for v in values) || error("Use explicit percentage strings")
    # SPMF parses percentages as binary64. Reject grids whose boundary rounding
    # would differ from our exact rational conversion; never adjust with epsilon.
    floating_thresholds = [ceil(Int, parse(Float64, chop(v)) / 100 * n) for v in values]
    thresholds == floating_thresholds || error("SPMF floating-point threshold differs")
    5 <= length(values) <= 7 || error("Expected 5–7 support levels")
    all(diff(ratios) .< 0) || error("Support levels must strictly decrease")
    allunique(thresholds) || error("Duplicate absolute thresholds")
    return thresholds
end

"Run one direct child; timeout includes startup and leaves no running worker."
function timed_process(cmd, logpath, timeout)
    timeout > 0 || error("Timeout must be positive")
    open(logpath, "w") do log
        start = time_ns()
        process = run(pipeline(ignorestatus(cmd); stdout=log, stderr=log); wait=false)
        expired = false
        try
            while process_running(process)
                if (time_ns() - start) / 1e9 >= timeout
                    expired = true
                    kill(process)
                    break
                end
                sleep(0.01)
            end
            wait(process)
        finally
            if process_running(process)
                kill(process)
                wait(process)
            end
        end
        seconds = (time_ns() - start) / 1e9
        status = expired ? "timeout" : success(process) ? "success" : "process_error"
        return (; status, seconds=expired ? missing : seconds)
    end
end

function output_count(path)
    isfile(path) || error("Missing output: $path")
    n = 0
    for line in eachline(path)
        s = strip(line)
        isempty(s) && continue
        first(s) in ('@', '#', '%') && continue
        occursin(r"^\d+(?: \d+)*\s+#SUP: \d+$", s) || error("Malformed output: $path")
        n += 1
    end
    return n
end

function exact_outputs(a, b)
    return is_exact_match(compare_itemsets(read_spmf_output(a), read_spmf_output(b)))
end

function source_snapshot()
    paths = ["experiments/configs/benchmarks.toml", "data/datasets.toml", "Project.toml",
             "experiments/dataset_benchmarks.jl", "experiments/run_benchmarks.jl",
             "experiments/benchmark_worker.jl"]
    for (dir, _, files) in walkdir(joinpath(ROOT, "src")), file in files
        endswith(file, ".jl") && push!(paths, relpath(joinpath(dir, file), ROOT))
    end
    return Dict(path => filehash(joinpath(ROOT, path)) for path in paths)
end

csvcell(x) = ismissing(x) ? "" : "\"" * replace(string(x), "\"" => "\"\"") * "\""
csvrow(io, xs) = (println(io, join(csvcell.(xs), ',')); flush(io))

function summarize(samples, expected)
    length(samples) == expected || error("Incomplete repeats")
    all(x -> !ismissing(x) && isfinite(x) && x >= 0, samples) || error("Invalid sample")
    q1, med, q3 = quantile(Float64.(samples), [0.25, 0.5, 0.75])
    return (; median=med, q1, q3, iqr=q3-q1)
end

function command(miner, java, jar, input, output, support, flags)
    if miner == "julia"
        worker = joinpath(@__DIR__, "benchmark_worker.jl")
        return `$(Base.julia_cmd()) --startup-file=no --threads=1 --project=$ROOT $worker $input $output $support`
    end
    return Cmd(vcat([java], flags, ["-jar", jar, "run", "Eclat", input, output, support]))
end

function run_case(dir, dataset, support, threshold, config, java, jar, pilot, raw, summary, commands)
    id = dataset["id"]
    input = joinpath(ROOT, dataset["processed_path"])
    times = Dict(m => Float64[] for m in ("julia", "spmf"))
    expected = nothing
    previous_hash = Dict{String,String}()
    repeats = pilot ? 1 : config["repeats"]
    # Repeat zero is a preliminary run, separate from official samples.
    for rep in (pilot ? (1:1) : (0:repeats))
        outputs = Dict{String,String}()
        valid = true
        counts = Dict{String,Int}()
        order = isodd(rep) ? ("julia", "spmf") : ("spmf", "julia")
        for (position, miner) in enumerate(order)
            stem = "$(id)_$(threshold)_$(rep)_$(miner)"
            output, log = joinpath(dir, stem * ".txt"), joinpath(dir, stem * ".log")
            cmd = command(miner, java, jar, input, output, support, config["jvm_flags"])
            commands[stem] = string(cmd)
            sample = timed_process(cmd, log, config["timeout_seconds"])
            status = sample.status
            count = missing
            if status == "success"
                message = read(log, String)
                marker = miner == "julia" ? "BENCHMARK_COMPLETE" : "Frequent itemsets count"
                if !isfile(output) || !occursin(marker, message)
                    status = "validation_failed"
                else
                    count = output_count(output)
                    outputs[miner] = output
                    counts[miner] = count
                end
            end
            csvrow(raw, (basename(dir), id, dataset["processed_sha256"], support, threshold,
                         miner, rep, position, "end_to_end", status,
                         sample.seconds, count, relpath(log, ROOT)))
            valid &= status == "success"
            if status == "success" && (pilot || rep > 0)
                push!(times[miner], sample.seconds)
            end
        end
        valid || return false
        counts["julia"] == counts["spmf"] || return false
        expected === nothing && (expected = counts["julia"])
        all(==(expected), values(counts)) || return false
        # Compare every itemset/support once; subsequent deterministic files must
        # match each miner's validated bytes, avoiding repeated large Dict copies.
        if isempty(previous_hash)
            exact_outputs(outputs["julia"], outputs["spmf"]) || return false
            for miner in order
                previous_hash[miner] = filehash(outputs[miner])
            end
        else
            all(filehash(outputs[m]) == previous_hash[m] for m in order) || return false
        end
    end
    for miner in ("julia", "spmf")
        stats = summarize(times[miner], repeats)
        csvrow(summary, (id, support, threshold, miner, expected, "exact_match", repeats,
                         stats.median, stats.q1, stats.q3, stats.iqr))
    end
    println(id, " ", support, ": ", expected, " patterns; exact match")
    return expected
end

function main(args)
    pilot = "--pilot" in args
    ids = filter(!=("--pilot"), args)
    config = TOML.parsefile(CONFIG)
    config["repeats"] >= 5 || error("At least five official repeats required")
    config["timeout_seconds"] > 0 || error("Invalid timeout")
    manifest = TOML.parsefile(joinpath(ROOT, config["dataset_manifest"]))["dataset"]
    known = config["dataset_ids"]
    all(in(known), ids) || error("Unknown dataset ID")
    datasets = filter(d -> d["id"] in (isempty(ids) ? known : ids), manifest)
    length(datasets) == length(isempty(ids) ? known : unique(ids)) || error("Missing manifest dataset")
    for d in datasets
        levels(config["minsup"][d["id"]], d["transactions"])
        path = joinpath(ROOT, d["processed_path"])
        filehash(path) == d["processed_sha256"] || error("Dataset checksum mismatch")
        countlines(path) == d["transactions"] || error("Transaction count mismatch")
    end
    java = get(ENV, "JAVA", "java")
    jar = abspath(get(ENV, "SPMF_JAR", joinpath(ROOT, "tools", "spmf.jar")))
    isfile(jar) || error("Missing SPMF jar; see experiments/spmf/README.md")
    initial = source_snapshot()
    runid = (pilot ? "pilot_" : "runtime_") * Dates.format(now(UTC), "yyyymmddTHHMMSSsss")
    dir = joinpath(ROOT, "results", "metrics", "benchmark_runs", runid)
    mkpath(dir)
    metadata = Dict{String,Any}("complete" => false, "pilot" => pilot,
        "config" => config, "sources" => initial, "jar_sha256" => filehash(jar),
        "julia" => string(VERSION), "java" => java_version(java),
        "cpu" => Sys.cpu_info()[1].model, "os" => string(Sys.KERNEL),
        "ram_bytes" => Sys.total_memory(), "threads" => 1,
        "commit" => strip(read(`git -C $ROOT rev-parse HEAD`, String)),
        "dirty" => !isempty(read(`git -C $ROOT status --porcelain`, String)),
        "invocation" => join(args, " "), "commands" => Dict{String,String}())
    save() = open(io -> TOML.print(io, metadata), joinpath(dir, "environment.toml"), "w")
    save()
    # Genuine reference smoke test, outside measured cases.
    smoke = joinpath(ROOT, "test", "fixtures", "transactions", "toy.txt")
    smokeout = joinpath(dir, "smoke.txt")
    for percentage in (20, 21, 39, 40)
        cmd = command("spmf", java, jar, smoke, smokeout, "$percentage%", config["jvm_flags"])
        result = timed_process(cmd, joinpath(dir, "smoke_$percentage.log"), config["timeout_seconds"])
        result.status == "success" && exact_outputs(smokeout,
            joinpath(ROOT, "test", "fixtures", "spmf_expected", "toy_$percentage.txt")) || error("SPMF smoke failed: $dir")
    end
    complete = true
    open(joinpath(dir, "raw.csv"), "w") do raw
        open(joinpath(dir, "summary.csv"), "w") do summary
            csvrow(raw, ("run_id", "dataset", "input_sha256", "minsup", "threshold", "miner", "repeat",
                         "order", "scope", "status", "seconds", "itemsets", "log"))
            csvrow(summary, ("dataset", "minsup", "threshold", "miner", "itemsets", "validation", "repeats",
                             "median_seconds", "q1_seconds", "q3_seconds", "iqr_seconds"))
            for d in datasets
                previous_count = -1
                for s in config["minsup"][d["id"]]
                    t = minsup_abs(s, d["transactions"])
                    count = run_case(dir, d, s, t, config, java, jar, pilot, raw, summary, metadata["commands"])
                    ok = count !== false && count >= previous_count
                    complete &= ok
                    if !ok
                        println(stderr, "Failed case: ", d["id"], " ", s, "; see ", dir)
                        break
                    end
                    previous_count = count
                end
            end
        end
    end
    inputs_unchanged = all(filehash(joinpath(ROOT, d["processed_path"])) == d["processed_sha256"] for d in datasets)
    metadata["complete"] = complete && inputs_unchanged && initial == source_snapshot() && metadata["jar_sha256"] == filehash(jar)
    metadata["artifacts"] = Dict(f => filehash(joinpath(dir, f)) for f in ("raw.csv", "summary.csv"))
    save()
    println("Artifacts: ", dir)
    metadata["complete"] || error("Incomplete benchmark run")
    return dir
end

function java_version(java)
    buffer = IOBuffer()
    run(pipeline(`$java -version`; stdout=buffer, stderr=buffer))
    return String(take!(buffer))
end
end
