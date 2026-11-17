module SizeBenchmarks
using EclatMining, Random, TOML, SHA, Dates, Statistics
include("dataset_benchmarks.jl")
const ROOT = normpath(joinpath(@__DIR__, ".."))
hashfile(p) = bytes2hex(open(sha256,p))

function sample_indices(n, percentages, seed)
    n > 0 || error("Empty source")
    issorted(percentages) && allunique(percentages) && all(p -> 0 < p <= 100,percentages) || error("Invalid percentages")
    order = randperm(MersenneTwister(seed),n)
    groups = [sort(order[1:fld(p*n,100)]) for p in percentages]
    all(x -> !isempty(x),groups) && allunique(length.(groups)) || error("Invalid subset sizes")
    return groups
end

function length_databases(n,u,lengths,seed)
    n > 0 && u > 0 || error("Invalid N/U")
    issorted(lengths) && allunique(lengths) && all(l -> 0 < l <= u,lengths) || error("Invalid lengths")
    rng = MersenneTwister(seed)
    orders = [randperm(rng,u) for _ in 1:n]
    return [[sort(order[1:l]) for order in orders] for l in lengths]
end

function write_transactions(path,db)
    open(path,"w") do io
        for tx in db
            join(io,tx,' '); println(io)
        end
    end
end

function fingerprint(result)
    io = IOBuffer()
    for (items,support) in result
        join(io,items,' '); println(io," #SUP: ",support)
    end
    return bytes2hex(sha256(take!(io)))
end

function worker(args)
    input,reference,support,repeats_text,destination = args
    db = read_spmf(input); before = deepcopy(db)
    threshold = minsup_abs(support,length(db))
    result = eclat_bitset(db,threshold) # Full-case warm-up outside timer.
    is_exact_match(compare_itemsets(result,read_spmf_output(reference))) || error("Reference mismatch")
    expected = fingerprint(result)
    count_patterns = length(result)
    singles = count(p -> length(first(p)) == 1,result)
    longest = isempty(result) ? 0 : maximum(p -> length(first(p)),result)
    result = nothing
    times = Float64[]
    for rep in 1:parse(Int,repeats_text)
        GC.gc()
        measurement = @timed eclat_bitset(db,threshold)
        push!(times,measurement.time)
        fingerprint(measurement.value) == expected || error("Changed result")
        measurement = nothing
        db == before || error("Input mutated")
    end
    info = Dict("times"=>times,"itemsets"=>count_patterns,"singletons"=>singles,
        "max_length"=>longest,"result_sha256"=>expected,"validation"=>"exact_match")
    open(io -> TOML.print(io,info),destination,"w")
end

function config_path(kind,args)
    datasets = [split(a,'=';limit=2)[2] for a in args if startswith(a,"--dataset=")]
    length(datasets) <= 1 || error("Duplicate dataset option")
    if !isempty(datasets)
        kind == "scalability" || error("Dataset option only applies to scalability")
        only(datasets) in ("retail","accidents") || error("Choose retail or accidents")
    end
    filename = !isempty(datasets) && only(datasets) == "accidents" ? "scalability_accidents.toml" : kind*".toml"
    return joinpath(ROOT,"experiments/configs",filename)
end

function snapshot(kind; configpath=joinpath(ROOT,"experiments/configs",kind*".toml"))
    paths = ["experiments/size_benchmarks.jl","experiments/size_worker.jl",
        "experiments/run_$(kind).jl",relpath(configpath,ROOT),
        "experiments/dataset_benchmarks.jl","Project.toml","data/datasets.toml"]
    for (dir,_,files) in walkdir(joinpath(ROOT,"src")), f in files
        endswith(f,".jl") && push!(paths,relpath(joinpath(dir,f),ROOT))
    end
    return Dict(p=>hashfile(joinpath(ROOT,p)) for p in paths)
end

function main(kind,args)
    kind in ("scalability","transaction_length") || error("Unknown experiment kind")
    all(a -> a == "--pilot" || startswith(a,"--case=") || startswith(a,"--dataset="),args) || error("Use --pilot, --case=N or --dataset=retail|accidents")
    pilot = "--pilot" in args
    selected = [parse(Int,split(a,'=')[2]) for a in args if startswith(a,"--case=")]
    # Capture configuration/source before preparation, which may be lengthy.
    configpath = config_path(kind,args)
    initial = snapshot(kind;configpath)
    c = TOML.parsefile(configpath)
    c["repeats"] >= 5 && c["timeout_seconds"] > 0 || error("Invalid measurement config")
    parse_minsup(c["minsup"])
    sourcepath = ""
    indices = Vector{Int}[]
    source = Dict{String,Any}()
    db = Vector{Int}[]
    if kind == "scalability"
        c["percentages"] == [10,25,50,75,100] || error("Required sampling grid")
        source = only(filter(d -> d["id"] == c["dataset"], TOML.parsefile(joinpath(ROOT,"data/datasets.toml"))["dataset"]))
        sourcepath = joinpath(ROOT,source["processed_path"])
        hashfile(sourcepath) == source["processed_sha256"] || error("Source checksum")
        db = read_spmf(sourcepath)
        length(db) == source["transactions"] || error("Source N mismatch")
        indices = sample_indices(length(db),c["percentages"],c["seed"])
        databases = [db[index] for index in indices]
        values = c["percentages"]
    else
        length(c["lengths"]) >= 5 || error("Need at least five lengths")
        databases = length_databases(c["n"],c["items"],c["lengths"],c["seed"])
        values = c["lengths"]
    end
    all(i -> i in eachindex(databases),selected) || error("Invalid case selection")
    initial == snapshot(kind;configpath) && c == TOML.parsefile(configpath) || error("Code/config changed during preparation")
    label = kind == "scalability" ? kind*"_"*c["dataset"] : kind
    runid = label * (pilot ? "_pilot_" : "_") * Dates.format(now(UTC),"yyyymmddTHHMMSSsss")
    dir = joinpath(ROOT,"results/metrics/size_runs",runid); mkpath(dir)
    java = get(ENV,"JAVA","java")
    jar = abspath(get(ENV,"SPMF_JAR",joinpath(ROOT,"tools/spmf.jar")))
    isfile(jar) || error("Missing SPMF jar")
    info = Dict{String,Any}("complete"=>false,"kind"=>kind,"pilot"=>pilot,"config"=>c,
        "sources"=>initial,"julia"=>string(VERSION),"rng"=>"MersenneTwister",
        "java"=>DatasetBenchmarks.java_version(java),"jar_sha256"=>hashfile(jar),
        "cpu"=>Sys.cpu_info()[1].model,"os"=>string(Sys.KERNEL),"ram_bytes"=>Sys.total_memory(),
        "threads"=>1,"scope"=>"warmed_api","timeout_scope"=>"each reference process and whole worker",
        "commit"=>strip(read(`git -C $ROOT rev-parse HEAD`,String)),
        "dirty"=>!isempty(read(`git -C $ROOT status --porcelain`,String)),"arguments"=>args,
        "commands"=>Dict{String,String}(),"cases"=>Any[])
    save() = open(io -> TOML.print(io,info),joinpath(dir,"environment.toml"),"w")
    save()
    all_ok = true
    previous = Dict{Vector{Int},Int}()
    open(joinpath(dir,"raw.csv"),"w") do raw
        open(joinpath(dir,"summary.csv"),"w") do summary
            DatasetBenchmarks.csvrow(raw,("case_id","repeat","seconds","scope","validation","itemsets"))
            DatasetBenchmarks.csvrow(summary,("case_id","level","n","items","total_items","mean_length","threshold","minsup","seed","input_sha256","miner","scope","validation","repeats","itemsets","singletons","max_length","median_seconds","q1_seconds","q3_seconds","iqr_seconds"))
            for i in eachindex(databases)
                !isempty(selected) && !(i in selected) && continue
                database = databases[i]
                input = kind == "scalability" && values[i] == 100 ? sourcepath : joinpath(dir,"input_$i.txt")
                input == sourcepath || write_transactions(input,database)
                threshold = minsup_abs(c["minsup"],length(database))
                ceil(Int,parse(Float64,chop(c["minsup"]))/100*length(database)) == threshold || error("SPMF threshold rounding mismatch")
                case = Dict{String,Any}("case_id"=>i,"input"=>relpath(input,ROOT),"sha256"=>hashfile(input),"level"=>values[i],"n"=>length(database),"threshold"=>threshold,"status"=>"pending")
                if kind == "scalability"
                    case["indices_sha256"] = bytes2hex(sha256(join(indices[i],',')))
                    case["actual_fraction"] = length(database)/length(db)
                    case["source_sha256"] = source["processed_sha256"]
                end
                push!(info["cases"],case); save()
                reference = joinpath(dir,"reference_$i.txt")
                cmd = Cmd([java,"-Xmx2g","-XX:ActiveProcessorCount=1","-jar",jar,"run","Eclat",input,reference,c["minsup"]])
                info["commands"]["reference_$i"] = string(cmd)
                state = DatasetBenchmarks.timed_process(cmd,joinpath(dir,"reference_$i.log"),c["timeout_seconds"])
                if state.status == "success" && isfile(reference) && occursin("Frequent itemsets count",read(joinpath(dir,"reference_$i.log"),String))
                    if kind == "transaction_length"
                        current = read_spmf_output(reference)
                        all(get(current,p,0) >= s for (p,s) in previous) || error("Nonmonotonic support")
                        previous = current
                    end
                    target = joinpath(dir,"worker_$i.toml")
                    repeats = pilot ? 1 : c["repeats"]
                    workerpath = joinpath(@__DIR__,"size_worker.jl")
                    cmd = `$(Base.julia_cmd()) --startup-file=no --threads=1 --project=$ROOT $workerpath $input $reference $(c["minsup"]) $repeats $target`
                    info["commands"]["worker_$i"] = string(cmd)
                    state = DatasetBenchmarks.timed_process(cmd,joinpath(dir,"worker_$i.log"),c["timeout_seconds"])
                    if state.status == "success" && isfile(target)
                        result = TOML.parsefile(target)
                        length(result["times"]) == repeats || error("Missing samples")
                        stats = DatasetBenchmarks.summarize(result["times"],repeats)
                        for (rep,seconds) in enumerate(result["times"])
                            DatasetBenchmarks.csvrow(raw,(i,rep,seconds,"warmed_api","exact_match",result["itemsets"]))
                        end
                        total = sum(length,database); u = length(Set(Iterators.flatten(database)))
                        DatasetBenchmarks.csvrow(summary,(i,values[i],length(database),u,total,total/length(database),threshold,c["minsup"],c["seed"],case["sha256"],"julia_bitset","warmed_api","exact_match",repeats,result["itemsets"],result["singletons"],result["max_length"],stats.median,stats.q1,stats.q3,stats.iqr))
                        case["status"] = "exact_match"
                        println(kind," case ",i,": ",result["itemsets"]," patterns; ",stats.median," s")
                    else
                        case["status"] = state.status == "success" ? "validation_failed" : state.status
                    end
                else
                    case["status"] = state.status == "success" ? "validation_failed" : state.status
                end
                all_ok &= case["status"] == "exact_match"
                case["reason"] = case["status"] == "exact_match" ? "" : "See process log; validation incomplete"
                save()
            end
        end
    end
    info["complete"] = all_ok && initial == snapshot(kind;configpath) && hashfile(jar) == info["jar_sha256"] && all(hashfile(joinpath(ROOT,x["input"])) == x["sha256"] for x in info["cases"])
    info["artifacts"] = Dict(f=>hashfile(joinpath(dir,f)) for f in ("raw.csv","summary.csv"))
    save(); println("Artifacts: ",dir)
    info["complete"] || error("Incomplete run: $dir")
end
end
