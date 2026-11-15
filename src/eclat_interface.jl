# INTERFACE THỐNG NHẤT GIỮA A (lõi Eclat) VÀ B (I/O, CLI, test) — FILE NÀY LÀ STUB TẠM.
#
# A cần định nghĩa trong module EclatMining đúng chữ ký sau:
#
#     eclat(db::Vector{Vector{Int}}, minsup_abs::Int)::Vector{Pair{Vector{Int},Int}}
#
# Hợp đồng:
#   - `db`: mỗi phần tử là một giao dịch, item nguyên không âm, ĐÃ sort tăng dần và KHÔNG trùng
#     (read_spmf bảo đảm). Giao dịch trùng nhau vẫn có mặt và mỗi cái được tính một lần.
#   - `minsup_abs`: ngưỡng support tuyệt đối, đã quy đổi bằng ceil. Luôn ≥ 1 khi `db` khác rỗng;
#     chỉ bằng 0 khi `db` rỗng (khi đó trả về vector rỗng).
#   - Trả về MỌI itemset khác rỗng có support ≥ minsup_abs, mỗi itemset đúng một lần, dạng
#     `itemset => support tuyệt đối`, item trong itemset tăng dần. Thứ tự các itemset tùy ý.
#
# Khi A đã có `eclat` thật: xóa file này và dòng include tương ứng trong EclatMining.jl.
# CLI (src/main.jl) và test (test/runtests.jl) không cần sửa gì.

# Tạm mượn bộ brute-force của test để CLI và test chạy được từ đầu đến cuối.
include(joinpath(@__DIR__, "..", "test", "reference_miner.jl"))

function eclat(db::Vector{Vector{Int}}, minsup_abs::Int)::Vector{Pair{Vector{Int},Int}}
    @warn "STUB: chưa có Eclat của A — đang dùng brute-force (chỉ chạy được với ≤ $REFERENCE_MAX_ITEMS item)" maxlog = 1
    return reference_mine(db, minsup_abs)
end
