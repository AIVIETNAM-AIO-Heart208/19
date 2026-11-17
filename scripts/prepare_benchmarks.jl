# Download pinned transaction datasets and prepare the common input for all miners.
# Usage: julia --project=. scripts/prepare_benchmarks.jl [dataset_id ...]
using EclatMining, Downloads, SHA, TOML

const DATA_ROOT = normpath(joinpath(@__DIR__, ".."))
file_sha256(path) = bytes2hex(open(sha256, path))

function prepare_dataset(dataset)
    raw = joinpath(DATA_ROOT, dataset["raw_path"])
    processed = joinpath(DATA_ROOT, dataset["processed_path"])
    mkpath(dirname(raw))
    mkpath(dirname(processed))
    if !isfile(raw)
        mktemp(dirname(raw)) do temporary, io
            close(io)
            Downloads.download(dataset["source_url"], temporary)
            file_sha256(temporary) == dataset["raw_sha256"] ||
                error("Source checksum mismatch for $(dataset["id"]); download not installed")
            mv(temporary, raw)
        end
    end
    file_sha256(raw) == dataset["raw_sha256"] ||
        error("Raw checksum mismatch for $(dataset["id"]); original file preserved")

    if !isfile(processed) || file_sha256(processed) != dataset["processed_sha256"]
        mktemp(dirname(processed)) do temporary, io
            close(io)
            n = clean_spmf(raw, temporary)
            n == dataset["transactions"] || error("Transaction count mismatch")
            file_sha256(temporary) == dataset["processed_sha256"] ||
                error("Processed checksum mismatch; destination not replaced")
            mv(temporary, processed; force=true)
        end
    end

    # Stream statistics instead of retaining several copies of the large database.
    items = Set{Int}()
    n, total, min_length, max_length = 0, 0, typemax(Int), 0
    for line in eachline(processed)
        transaction = parse.(Int, split(line))
        issorted(transaction) && allunique(transaction) || error("Invalid processed transaction")
        n += 1
        total += length(transaction)
        min_length = min(min_length, length(transaction))
        max_length = max(max_length, length(transaction))
        union!(items, transaction)
    end
    n == dataset["transactions"] || error("Transaction count mismatch")
    length(items) == dataset["item_count"] || error("Item count mismatch")
    isapprox(total / n, dataset["mean_transaction_length"]; rtol=1e-12) || error("Mean length mismatch")
    (min_length, max_length) == (dataset["min_transaction_length"], dataset["max_transaction_length"]) ||
        error("Transaction length range mismatch")
    println(dataset["name"], ": ", n, " transactions, ", length(items),
            " items; raw/processed SHA-256 verified")
    return nothing
end

function main(args)
    datasets = TOML.parsefile(joinpath(DATA_ROOT, "data", "datasets.toml"))["dataset"]
    known = Set(dataset["id"] for dataset in datasets)
    all(id -> id in known, args) || error("Unknown dataset ID; choose from $(join(sort!(collect(known)), ", "))")
    for dataset in datasets
        (isempty(args) || dataset["id"] in args) && prepare_dataset(dataset)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end
