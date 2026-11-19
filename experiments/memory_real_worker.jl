# One memory observation on a real dataset: one fresh process, one miner, one call.
# Prints a single line: MEMORY_RESULT rss_before peak_before_mining peak_rss itemsets seconds vertical_bytes estimate_bytes
using EclatMining

"Current resident set size in bytes (not the peak)."
function current_rss()::Int
    if Sys.iswindows()
        # PROCESS_MEMORY_COUNTERS: cb + PageFaultCount (2 DWORD), then 8 SIZE_T fields.
        buf = zeros(UInt64, 9)
        buf[1] = sizeof(buf)
        process = ccall((:GetCurrentProcess, "kernel32"), Ptr{Cvoid}, ())
        ok = ccall((:K32GetProcessMemoryInfo, "kernel32"), Int32,
                   (Ptr{Cvoid}, Ptr{UInt64}, UInt32), process, buf, sizeof(buf))
        ok != 0 || error("GetProcessMemoryInfo failed")
        return Int(buf[3])          # WorkingSetSize
    elseif Sys.islinux()
        pages = parse(Int, split(read("/proc/self/statm", String))[2])
        return pages * 4096
    end
    error("current RSS unsupported on this platform")
end

# Rebuild the vertical structure the miner builds for single frequent items.
# The core does not expose it and must not be edited, so this is an independent
# reconstruction. Only the item vectors are summed (no Dict, no recursion).
# Returns (measured, estimate). Estimate by formula: bitset = items × ceil(N/64) × 8 bytes,
# TID-list = total support × 8 bytes, a lower bound: lists are grown by push!, and summarysize counts
# the spare capacity Julia 1.11 allocates (a few % for long lists, up to ~3× for lists of ~100 entries).
# The 3× ceiling is empirical (observed 1.7–1.9× on the benchmark cases); a much lower minsup may need it
# raised. Bitset must lie in [estimate, estimate + 64 bytes per item]; the 64-byte header per item is
# what Julia 1.11 uses and may differ in other versions. Anything outside the range stops the run.
function vertical_bytes(db::Vector{Vector{Int}}, threshold::Int, name::String)::Tuple{Int,Int}
    counts = Dict{Int,Int}()
    for transaction in db, item in transaction
        counts[item] = get(counts, item, 0) + 1
    end
    total = 0
    frequent = [c for c in values(counts) if c >= threshold]
    estimate = name == "baseline" ? 8 * sum(frequent; init=0) : length(frequent) * cld(length(db), 64) * 8
    if name == "baseline"
        lists = Dict{Int,Vector{Int}}(item => Int[] for (item, c) in counts if c >= threshold)
        for (tid, transaction) in enumerate(db), item in transaction
            list = get(lists, item, nothing)
            list === nothing || push!(list, tid)
        end
        for list in values(lists)
            total += Base.summarysize(list)
        end
    else
        masks = Dict{Int,BitVector}(item => falses(length(db)) for (item, c) in counts if c >= threshold)
        for (tid, transaction) in enumerate(db), item in transaction
            mask = get(masks, item, nothing)
            mask === nothing || (mask[tid] = true)
        end
        for mask in values(masks)
            total += Base.summarysize(mask)
        end
    end
    upper = (name == "baseline" ? 3 * estimate : estimate) + 64 * length(frequent)
    estimate <= total <= upper ||
        error("summarysize ", total, " disagrees with formula estimate ", estimate, " (", name, ")")
    return total, estimate
end

"Stop early if the size measurement disagrees with the formula on a database with known answer."
function self_check()
    # 130 transactions: item 1 in all, item 2 in 65, item 3 in 2 (infrequent at threshold 3).
    db = [t <= 2 ? [1, 2, 3] : iseven(t) ? [1, 2] : [1] for t in 1:130]
    bits, bits_formula = vertical_bytes(db, 3, "bitset")
    tids, tids_formula = vertical_bytes(db, 3, "baseline")
    bits_formula == 2 * 3 * 8 && tids_formula == (130 + 66) * 8 || error("self-check: formula wrong")
    return (; bits, bits_formula, tids, tids_formula)
end

function worker_main(args)
    length(args) == 3 || error("Expected input, minsup, miner")
    input, support, name = args
    miner = name == "baseline" ? eclat_baseline : name == "bitset" ? eclat_bitset : error("unknown miner")
    miner([[1, 2], [1], Int[]], 1)          # compile on a tiny input, never on the measured data
    db = read_spmf(input)
    threshold = minsup_abs(support, length(db))
    GC.gc()
    before = current_rss()
    peak_before = Sys.maxrss()   # process peak so far (startup, JIT, loading)
    start = time_ns()
    result = miner(db, threshold)
    seconds = (time_ns() - start) / 1e9
    peak = Sys.maxrss()
    peak > 0 || error("peak RSS unsupported; refusing to report zero")
    bytes, estimate = vertical_bytes(db, threshold, name)   # after the peak is read
    println("MEMORY_RESULT ", before, ' ', peak_before, ' ', peak, ' ', length(result), ' ', seconds, ' ', bytes, ' ', estimate)
end

abspath(PROGRAM_FILE) == (@__FILE__) && worker_main(ARGS)
