module EclatMining

export eclat, eclat_baseline, eclat_bitset
export read_spmf, write_spmf, read_spmf_output, clean_spmf, parse_minsup, minsup_abs
export CompareResult, compare_itemsets, match_ratio, is_exact_match, print_compare

include("algorithm/baseline.jl")
include("algorithm/optimized.jl")
include("io.jl")
include("algorithm/stub.jl")   # STUB của B: xóa dòng này (và stub.jl) khi A đã cài hàm thật
include("applications/association_rules.jl")
include("applications/market_basket.jl")
include("applications/biology.jl")

# TODO: Chốt API chung, quy ước minsup và kiểu đầu ra trước khi triển khai.

end
