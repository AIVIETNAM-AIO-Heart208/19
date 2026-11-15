module EclatMining

export eclat
export read_spmf, write_spmf, read_spmf_output, parse_minsup, minsup_abs
export CompareResult, compare_itemsets, match_ratio, is_exact_match, print_compare

include("algorithm/baseline.jl")
include("algorithm/optimized.jl")
include("io.jl")
include("utils.jl")
include("applications/association_rules.jl")
include("applications/market_basket.jl")
include("applications/biology.jl")

# TODO: Chốt API chung, quy ước minsup và kiểu đầu ra trước khi triển khai.

end
