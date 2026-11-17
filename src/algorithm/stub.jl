# STUB TẠM của B, để CLI và test chạy được từ đầu đến cuối khi Eclat thật chưa có.
#
# Khi A cài hàm thật trong baseline.jl / optimized.jl: xóa file này và dòng
# `include("algorithm/stub.jl")` trong EclatMining.jl. CLI và test không cần sửa gì.
#
# Chữ ký thống nhất giữa A và B:
#
#     eclat_baseline(db::Vector{Vector{Int}}, minsup_abs::Int)::Vector{Pair{Vector{Int},Int}}
#     eclat_bitset(db::Vector{Vector{Int}},   minsup_abs::Int)::Vector{Pair{Vector{Int},Int}}
#     eclat(db, minsup_abs) = eclat_bitset(db, minsup_abs)
#
# Hợp đồng:
#   - `db`: mỗi phần tử là một giao dịch, item nguyên không âm, ĐÃ sort tăng dần và KHÔNG trùng
#     (read_spmf bảo đảm). Giao dịch trùng nhau, giao dịch rỗng vẫn có mặt và được tính vào |DB|.
#   - `minsup_abs`: ngưỡng support tuyệt đối, đã quy đổi bằng ceil. Luôn ≥ 1 khi `db` khác rỗng;
#     chỉ bằng 0 khi `db` rỗng (khi đó trả về vector rỗng).
#   - Trả về MỌI itemset khác rỗng có support ≥ minsup_abs, mỗi itemset đúng một lần, dạng
#     `itemset => support tuyệt đối`, item trong itemset tăng dần. Thứ tự các itemset tùy ý.

# Tạm mượn bộ brute-force của test làm lõi.
include(joinpath(@__DIR__, "..", "..", "test", "reference_miner.jl"))

function stub_mine(db::Vector{Vector{Int}}, minsup_abs::Int)::Vector{Pair{Vector{Int},Int}}
    @warn "STUB: chưa có Eclat của A — đang dùng brute-force (chỉ chạy được với ≤ $REFERENCE_MAX_ITEMS item)" maxlog = 1
    return reference_mine(db, minsup_abs)
end

eclat_baseline(db::Vector{Vector{Int}}, minsup_abs::Int)::Vector{Pair{Vector{Int},Int}} =
    stub_mine(db, minsup_abs)
eclat_bitset(db::Vector{Vector{Int}}, minsup_abs::Int)::Vector{Pair{Vector{Int},Int}} =
    stub_mine(db, minsup_abs)

eclat(db::Vector{Vector{Int}}, minsup_abs::Int)::Vector{Pair{Vector{Int},Int}} =
    eclat_bitset(db, minsup_abs)
