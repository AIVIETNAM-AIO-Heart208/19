module EclatMining

export eclat, eclat_baseline, eclat_bitset
export read_spmf, write_spmf, read_spmf_output, clean_spmf, parse_minsup, minsup_abs
export CompareResult, compare_itemsets, match_ratio, is_exact_match, print_compare

include("algorithm/baseline.jl")
include("algorithm/optimized.jl")
include("io.jl")

"Default public miner; baseline remains available for comparisons."
eclat(db::Vector{Vector{Int}}, minsup_abs::Int) = eclat_bitset(db, minsup_abs)
include("applications/association_rules.jl")
include("applications/market_basket.jl")
include("applications/biology.jl")

# API và hợp đồng dữ liệu: docs/algorithm_notes.md.

end
