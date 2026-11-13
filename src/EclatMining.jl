module EclatMining

include("algorithm/baseline.jl")
include("algorithm/optimized.jl")
include("io.jl")
include("applications/association_rules.jl")
include("applications/market_basket.jl")
include("applications/biology.jl")

# TODO: Chốt API chung, quy ước minsup và kiểu đầu ra trước khi triển khai.

end

