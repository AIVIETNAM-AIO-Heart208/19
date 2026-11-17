"""
    eclat_baseline(db::Vector{Vector{Int}}, minsup_abs::Int)

Mine all nonempty frequent itemsets using sorted TID lists and prefix DFS.
Transactions must contain strictly increasing, nonnegative items. Input is never
modified. Return independent `itemset => absolute_support` pairs in lexical DFS order.
An empty database accepts any nonnegative threshold; otherwise the threshold must
be positive. Thresholds above the transaction count produce no patterns.
"""
function eclat_baseline(db::Vector{Vector{Int}}, minsup_abs::Int)::Vector{Pair{Vector{Int},Int}}
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

    vertical = Dict{Int,Vector{Int}}()
    for (tid, transaction) in enumerate(db), item in transaction
        push!(get!(Vector{Int}, vertical, item), tid)
    end
    extensions = Pair{Int,Vector{Int}}[
        item => tids for (item, tids) in vertical if length(tids) >= minsup_abs
    ]
    sort!(extensions; by=first)
    _baseline_dfs!(result, Int[], extensions, minsup_abs)
    return result
end

# Both inputs contain strictly increasing transaction identifiers.
function _intersect_tids(a::Vector{Int}, b::Vector{Int})::Vector{Int}
    common = Int[]
    i, j = 1, 1
    while i <= length(a) && j <= length(b)
        if a[i] == b[j]
            push!(common, a[i])
            i += 1
            j += 1
        elseif a[i] < b[j]
            i += 1
        else
            j += 1
        end
    end
    return common
end

# Invariant: each entry x => tids describes T(prefix ∪ {x}), already frequent.
function _baseline_dfs!(result::Vector{Pair{Vector{Int},Int}}, prefix::Vector{Int},
                        extensions::Vector{Pair{Int,Vector{Int}}}, threshold::Int)::Nothing
    for i in eachindex(extensions)
        item, tids = extensions[i]
        push!(prefix, item)
        push!(result, copy(prefix) => length(tids))
        children = Pair{Int,Vector{Int}}[]
        for j in (i + 1):length(extensions)
            next_item, next_tids = extensions[j]
            common = _intersect_tids(tids, next_tids)
            length(common) >= threshold && push!(children, next_item => common)
        end
        isempty(children) || _baseline_dfs!(result, prefix, children, threshold)
        pop!(prefix)
    end
    return nothing
end

