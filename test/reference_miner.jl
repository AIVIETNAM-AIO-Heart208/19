# BỘ ĐẾM THAM CHIẾU (ORACLE) CHO TEST — KHÔNG PHẢI THUẬT TOÁN NỘP BÀI.
#
# Brute-force: liệt kê MỌI tập con khác rỗng của các item phổ biến và đếm support bằng
# cách quét thẳng toàn bộ CSDL. Không có tid-set, không có lớp tương đương, không tỉa nhánh:
# nó cố ý không giống Eclat để làm bên kiểm chứng độc lập cho Eclat và cho output của SPMF.
# Độ phức tạp O(2^k · |DB|) với k = số item phổ biến, nên chỉ dùng cho CSDL nhỏ (≤ 20 item).

const REFERENCE_MAX_ITEMS = 20

"""
    reference_mine(db, minsup_abs) -> Vector{Pair{Vector{Int},Int}}

Trả về mọi itemset khác rỗng có support ≥ `minsup_abs`, cùng chữ ký với `eclat`.
"""
function reference_mine(db::Vector{Vector{Int}}, minsup_abs::Int)::Vector{Pair{Vector{Int},Int}}
    result = Pair{Vector{Int},Int}[]
    isempty(db) && return result
    minsup_abs >= 1 || throw(ArgumentError("minsup_abs phải ≥ 1 khi CSDL khác rỗng"))

    # Support của từng item đơn (mỗi giao dịch chỉ tính một lần cho mỗi item).
    counts = Dict{Int,Int}()
    for t in db, i in unique(t)
        counts[i] = get(counts, i, 0) + 1
    end
    @assert length(counts) <= REFERENCE_MAX_ITEMS "oracle brute-force chỉ dùng cho ≤ $REFERENCE_MAX_ITEMS item phân biệt"

    # Chỉ giữ item phổ biến: tập chứa item không phổ biến thì chắc chắn không phổ biến.
    items = sort!([i for (i, c) in counts if c >= minsup_abs])
    k = length(items)
    bit = Dict{Int,UInt32}(items[j] => UInt32(1) << (j - 1) for j in 1:k)

    # Mỗi giao dịch thành một mặt nạ bit trên k item phổ biến.
    masks = UInt32[reduce(|, (get(bit, i, UInt32(0)) for i in t); init=UInt32(0)) for t in db]

    # Mỗi số 1 .. 2^k - 1 là một tập con; tập con X nằm trong giao dịch T khi T & X == X.
    for subset in UInt32(1):((UInt32(1) << k) - UInt32(1))
        sup = 0
        for m in masks
            sup += (m & subset) == subset
        end
        if sup >= minsup_abs
            push!(result, [items[j] for j in 1:k if (subset >> (j - 1)) & UInt32(1) == UInt32(1)] => sup)
        end
    end
    return result
end
