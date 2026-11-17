"""
    eclat_bitset(db::Vector{Vector{Int}}, minsup_abs::Int)

Eclat with independent packed BitVector TID sets. Same contract as baseline.
Intersections allocate new masks; neither inputs nor ancestor masks are mutated.
"""
function eclat_bitset(db::Vector{Vector{Int}}, minsup_abs::Int)::Vector{Pair{Vector{Int},Int}}
    minsup_abs >= 0 || throw(ArgumentError("minsup_abs phải không âm"))
    !isempty(db) && minsup_abs == 0 &&
        throw(ArgumentError("minsup_abs phải ≥ 1 khi CSDL khác rỗng"))
    # Validate even when the threshold exceeds |DB|, so invalid input is not hidden.
    for (tid, transaction) in enumerate(db)
        previous = -1
        for item in transaction
            item >= 0 && item > previous ||
                throw(ArgumentError("giao dịch $tid phải chứa item không âm, tăng nghiêm ngặt"))
            previous = item
        end
    end
    result = Pair{Vector{Int},Int}[]
    (isempty(db) || minsup_abs > length(db)) && return result
    counts = Dict{Int,Int}()
    for transaction in db, item in transaction
        counts[item] = get(counts, item, 0) + 1
    end
    masks = Dict{Int,BitVector}(item => falses(length(db))
                              for (item, support) in counts if support >= minsup_abs)
    for (tid, transaction) in enumerate(db), item in transaction
        mask = get(masks, item, nothing)
        mask === nothing || (mask[tid] = true)
    end
    extensions = sort!(collect(masks); by=first)
    _bitset_dfs!(result, Int[], extensions, minsup_abs)
    return result
end

# Every mask represents T(prefix ∪ {item}) and is already frequent.
function _bitset_dfs!(result::Vector{Pair{Vector{Int},Int}}, prefix::Vector{Int},
                      extensions::Vector{Pair{Int,BitVector}}, threshold::Int)::Nothing
    for i in eachindex(extensions)
        item, mask = extensions[i]
        push!(prefix, item)
        push!(result, copy(prefix) => count(mask))
        children = Pair{Int,BitVector}[]
        for j in (i + 1):length(extensions)
            next_item, next_mask = extensions[j]
            common = mask .& next_mask
            count(common) >= threshold && push!(children, next_item => common)
        end
        isempty(children) || _bitset_dfs!(result, prefix, children, threshold)
        pop!(prefix)
    end
    return nothing
end
