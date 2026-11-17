# Chạy: julia --project test/runtests.jl
# Đối chiếu ba bên: eclat (của nhóm) — output thật của SPMF (test/fixtures/spmf_expected) — oracle brute-force.
# Ghi chú: đề ghi thư mục `tests/`, nhưng lệnh chạy trong đề là `julia --project test/runtests.jl`
# và khung repo của A dùng `test/`, nên repo dùng `test/`.

using Test
using EclatMining

include(joinpath(@__DIR__, "reference_miner.jl"))   # reference_mine: oracle, không phải bài nộp

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
    include("test_goal2_provenance.jl")
    # test_applications.jl của A mới là placeholder (chỉ có comment, không có test).
    # Không include để khỏi lẫn vào kết quả; thêm dòng include khi A viết test ứng dụng.
end
