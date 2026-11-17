# Chạy: julia --project test/runtests.jl
# Đối chiếu ba bên: Eclat — fixture SPMF (test/fixtures/spmf_expected) — oracle brute-force.
# Thư mục test/ chứa bộ kiểm thử tự động; runtests.jl là điểm vào chung.

using Test
using EclatMining

include(joinpath(@__DIR__, "reference_miner.jl"))   # reference_mine: oracle độc lập, chỉ dùng trong kiểm thử

const FIXTURES = joinpath(@__DIR__, "fixtures")
const TOY_DIR = joinpath(FIXTURES, "transactions")
const EXPECTED_DIR = joinpath(FIXTURES, "spmf_expected")
toy(name::String) = joinpath(TOY_DIR, name)

# Kết quả toy ở minsup 40% (= 2), đối chiếu fixture SPMF.
const TOY_40 = Dict{Vector{Int},Int}(
    [1] => 3, [2] => 4, [3] => 4, [5] => 4,
    [1, 2] => 2, [1, 3] => 3, [1, 5] => 2, [2, 3] => 3, [2, 5] => 4, [3, 5] => 3,
    [1, 2, 3] => 2, [1, 2, 5] => 2, [1, 3, 5] => 2, [2, 3, 5] => 3,
    [1, 2, 3, 5] => 2,
)

@testset "EclatMining" begin
    include("test_io.jl")
    include("test_correctness.jl")
    include("test_benchmark_provenance.jl")
    # Kiểm thử ứng dụng chưa triển khai; bổ sung test_applications.jl khi có test thực tế.
end
