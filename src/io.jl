# Tiện ích đọc/ghi định dạng SPMF, quy đổi minsup và so khớp kết quả.
#
# Quy ước chung:
#   - CSDL giao dịch:  Vector{Vector{Int}}, mỗi giao dịch đã sort tăng dần, không item trùng.
#   - Kết quả khai thác: các cặp `itemset => support tuyệt đối`, itemset sort tăng dần.
# Mọi hàm đều trả về kiểu cụ thể (type-stable), không dùng global không định kiểu.

# ---------------------------------------------------------------------------
# Đọc CSDL giao dịch
# ---------------------------------------------------------------------------

"Ký tự mở đầu dòng metadata/comment mà SPMF bỏ qua."
is_comment_char(c::Char)::Bool = c == '@' || c == '#' || c == '%'

# Tách một dòng thành các item nguyên, sort tăng dần và bỏ item trùng.
# `lineno` chỉ dùng để báo lỗi cho dễ tìm.
function parse_items(line::AbstractString, lineno::Int)::Vector{Int}
    items = Int[]
    for tok in eachsplit(line)            # tách theo khoảng trắng, tự bỏ dấu cách thừa
        v = tryparse(Int, tok)
        if v === nothing || v < 0
            throw(ArgumentError("dòng $lineno: item không hợp lệ \"$tok\" (cần số nguyên không âm)"))
        end
        push!(items, v)
    end
    sort!(items)
    unique!(items)                        # sau khi sort, unique! bỏ các item trùng kề nhau
    return items
end

# Đọc giao dịch từ một IO bất kỳ (file hoặc IOBuffer trong test).
function read_transactions(io::IO)::Vector{Vector{Int}}
    db = Vector{Int}[]
    for (lineno, raw) in enumerate(eachline(io))
        raw = lstrip(raw, '﻿')                 # bỏ BOM (file do Windows tạo)
        isempty(raw) && continue                    # dòng trống hẳn: bỏ
        line = strip(raw)
        # Dòng chỉ có khoảng trắng: SPMF tính là một giao dịch rỗng (|DB| tăng 1), nhóm làm giống SPMF.
        isempty(line) && (push!(db, Int[]); continue)
        is_comment_char(first(line)) && continue    # dòng @ # %
        push!(db, parse_items(line, lineno))
    end
    return db
end

"""
    read_spmf(path) -> Vector{Vector{Int}}

Đọc CSDL giao dịch định dạng SPMF: mỗi dòng một giao dịch, item cách nhau khoảng trắng.
Bỏ dòng trống hẳn và dòng bắt đầu bằng `@`, `#`, `%`. Dòng chỉ có khoảng trắng là một giao dịch rỗng
(giống SPMF, làm |DB| và minsup tuyệt đối đổi). Mỗi giao dịch được sort và bỏ item trùng.
Các giao dịch trùng nhau được GIỮ NGUYÊN vì chúng vẫn được tính vào support.
"""
read_spmf(path::AbstractString)::Vector{Vector{Int}} = open(read_transactions, path)

# Làm sạch một CSDL giao dịch để SPMF đọc được mà không đổi số giao dịch (xem `clean_spmf`).
function clean_transactions(input::IO, output::IO)::Int
    n = 0
    for (lineno, raw) in enumerate(eachline(input))
        raw = lstrip(raw, '﻿')
        isempty(raw) && continue                    # dòng trống hẳn: SPMF cũng bỏ, không phải giao dịch
        line = strip(raw)
        if isempty(line)
            print(output, " \n")                    # giao dịch rỗng: đúng một dấu cách (SPMF đọc ra giao dịch rỗng)
        else
            is_comment_char(first(line)) && continue
            join(output, parse_items(line, lineno), ' ')   # sort + bỏ item trùng, các item cách nhau đúng một dấu cách
            print(output, '\n')
        end
        n += 1
    end
    return n
end

# Compare filesystem identity before opening an output in truncating mode.
# Existing paths also cover hard links, symbolic links and Windows case aliases.
function same_file(a::AbstractString, b::AbstractString)::Bool
    if ispath(a) && ispath(b)
        return samefile(a, b)
    end
    key(p) = Sys.iswindows() ? lowercase(abspath(p)) : abspath(p)
    return key(a) == key(b)
end

"""
    clean_spmf(in, out) -> Int

Ghi vào `out` bản làm sạch của file giao dịch `in`, trả về số giao dịch đã ghi. Bản sạch có mỗi dòng một
giao dịch, không dấu cách đầu/cuối, các item cách nhau đúng một dấu cách, item sort tăng dần và không trùng,
nên SPMF (vốn crash với dấu cách đầu dòng, dấu cách liền nhau, item trùng) đọc được.

Không đổi số giao dịch: dòng chỉ có khoảng trắng (một giao dịch rỗng) được ghi thành một dòng gồm đúng
một dấu cách, đã kiểm thử hộp đen là SPMF vẫn đọc ra một giao dịch rỗng. Chỉ bỏ những dòng không phải giao dịch:
dòng trống hẳn và dòng bắt đầu bằng `@`, `#`, `%`. Benchmark thật phải đi qua hàm này trước khi đưa cho SPMF.
"""
function clean_spmf(input::AbstractString, output::AbstractString)::Int
    same_file(input, output) && throw(ArgumentError("input và output phải là hai file khác nhau"))
    return open(in_io -> open(out_io -> clean_transactions(in_io, out_io), output, "w"), input)
end

# ---------------------------------------------------------------------------
# Ghi / đọc kết quả `i1 i2 ... #SUP: n`
# ---------------------------------------------------------------------------

function write_itemsets(io::IO, rows::Vector{Pair{Vector{Int},Int}})::Nothing
    for (items, sup) in rows
        join(io, issorted(items) ? items : sort(items), ' ')
        print(io, " #SUP: ", sup, '\n')
    end
    return nothing
end

"""
    write_spmf(path, itemsets; sorted=true) -> Int

Ghi kết quả theo định dạng output của SPMF, mỗi dòng `i1 i2 ... #SUP: n` với item tăng dần.
`itemsets` là bất kỳ tập hợp nào duyệt ra `Vector{Int} => Int` (Vector các Pair hoặc Dict).
`sorted=true` sắp các dòng theo (độ dài, thứ tự từ điển) để file ổn định giữa các lần chạy;
SPMF không quy định thứ tự dòng nên việc này không ảnh hưởng tính đúng. Trả về số dòng đã ghi.
"""
function write_spmf(path::AbstractString, itemsets; sorted::Bool=true)::Int
    rows = collect(Pair{Vector{Int},Int}, itemsets)
    sorted && sort!(rows; by = p -> (length(first(p)), first(p)))
    open(io -> write_itemsets(io, rows), path, "w")
    return length(rows)
end

function read_itemsets(io::IO)::Dict{Vector{Int},Int}
    out = Dict{Vector{Int},Int}()
    for (lineno, raw) in enumerate(eachline(io))
        line = strip(lstrip(raw, '﻿'))
        isempty(line) && continue
        is_comment_char(first(line)) && continue    # SPMF ghi 2 dòng đầu @FILETYPE, @SOURCE
        r = findfirst("#SUP:", line)
        r === nothing && throw(ArgumentError("dòng $lineno: thiếu \"#SUP:\""))
        items = parse_items(SubString(line, firstindex(line), prevind(line, first(r))), lineno)
        isempty(items) && throw(ArgumentError("dòng $lineno: itemset rỗng"))
        sup = tryparse(Int, strip(SubString(line, nextind(line, last(r)))))
        sup === nothing && throw(ArgumentError("dòng $lineno: support không hợp lệ"))
        haskey(out, items) && throw(ArgumentError("dòng $lineno: itemset $items xuất hiện hai lần"))
        out[items] = sup
    end
    return out
end

"""
    read_spmf_output(path) -> Dict{Vector{Int},Int}

Đọc file kết quả (của SPMF hoặc của nhóm) thành `itemset đã sort => support`.
Bỏ dòng trống và dòng bắt đầu bằng `@`, `#`, `%` (SPMF v2.65 ghi 2 dòng header `@...` ở đầu file).
Dùng Dict vì thứ tự dòng trong output không cố định; báo lỗi nếu một itemset lặp lại.
"""
read_spmf_output(path::AbstractString)::Dict{Vector{Int},Int} = open(read_itemsets, path)

# ---------------------------------------------------------------------------
# minsup
# ---------------------------------------------------------------------------

function parse_decimal_ratio(s::AbstractString, name::AbstractString)::Rational{Int}
    str = String(strip(s))
    m = match(r"^(\d*)(?:\.(\d*))?(%?)$", str)
    m === nothing && throw(ArgumentError("$name không hợp lệ: \"$s\" (ví dụ đúng: 0.4 hoặc 40%)"))
    int_part = something(m.captures[1], "")
    frac_part = something(m.captures[2], "")
    ndigits = length(int_part) + length(frac_part)
    ndigits == 0 && throw(ArgumentError("$name không hợp lệ: \"$s\""))
    ndigits > 15 && throw(ArgumentError("$name quá nhiều chữ số: \"$s\""))
    num = parse(Int, string(int_part, frac_part))   # "0.4" -> 04 = 4
    den = 10^length(frac_part)                      #          10^1
    m.captures[3] == "%" && (den *= 100)
    return num // den
end

"""
    parse_minsup(s) -> Rational{Int}

Nhận `"0.4"` (tỉ lệ) hoặc `"40%"` (phần trăm) và trả về số hữu tỉ chính xác.
Chuỗi thập phân được đổi thẳng thành tử/mẫu, KHÔNG đi qua Float64, nên `"7%"` là đúng 7//100
(với Float64 thì 0.07*100 = 7.000000000000001 và ceil sẽ ra 8). Báo lỗi nếu minsup ≤ 0 hoặc > 1.
"""
function parse_minsup(s::AbstractString)::Rational{Int}
    r = parse_decimal_ratio(s, "minsup")
    (0 < r <= 1) || throw(ArgumentError("minsup phải thuộc (0, 1] hay (0%, 100%], nhận được \"$s\""))
    return r
end

"""Đọc minconf dưới dạng tỉ lệ hoặc phần trăm, trả về số hữu tỉ thuộc [0, 1]."""
function parse_minconf(s::AbstractString)::Rational{Int}
    r = parse_decimal_ratio(s, "minconf")
    0 <= r <= 1 || throw(ArgumentError("minconf phải thuộc [0, 1], nhận được \"$s\""))
    return r
end

"""
    minsup_abs(r, n) -> Int

Ngưỡng support tuyệt đối `ceil(r × n)` như SPMF, tính bằng phép chia nguyên làm tròn lên
(`cld`) trên tử và mẫu nên không có sai số dấu phẩy động. Tích tử × n tính bằng `widemul` (Int128)
để không tràn Int64 khi minsup có 15 chữ số; kết quả ≤ n nên luôn vừa Int.
"""
minsup_abs(r::Rational{Int}, n::Int)::Int = Int(cld(widemul(numerator(r), n), denominator(r)))   # nhân Int128 để không tràn Int64
minsup_abs(s::AbstractString, n::Int)::Int = minsup_abs(parse_minsup(s), n)

# ---------------------------------------------------------------------------
# So khớp hai tập kết quả
# ---------------------------------------------------------------------------

"Kết quả so khớp giữa output của nhóm (`ours`) và output tham chiếu (`ref`, thường là SPMF)."
struct CompareResult
    n_ours::Int
    n_ref::Int
    n_match::Int                                        # cùng itemset và cùng support
    missing_sets::Vector{Pair{Vector{Int},Int}}         # có ở ref, không có ở ours (kèm support ref)
    extra_sets::Vector{Pair{Vector{Int},Int}}           # có ở ours, không có ở ref (kèm support ours)
    wrong_support::Vector{Tuple{Vector{Int},Int,Int}}   # (itemset, support ours, support ref)
end

# Chuẩn hóa về Dict `itemset đã sort => support`; multiple dispatch chọn đúng phiên bản.
itemset_dict(d::Dict{Vector{Int},Int})::Dict{Vector{Int},Int} = d
function itemset_dict(v::AbstractVector{Pair{Vector{Int},Int}})::Dict{Vector{Int},Int}
    d = Dict{Vector{Int},Int}()
    sizehint!(d, length(v))
    for (items, sup) in v
        key = issorted(items) ? items : sort(items)
        haskey(d, key) && throw(ArgumentError("itemset $key xuất hiện hai lần trong kết quả"))
        d[key] = sup
    end
    return d
end

"""
    compare_itemsets(ours, ref) -> CompareResult

So hai kết quả dưới dạng tập `{(itemset đã sort, support)}`, không phụ thuộc thứ tự dòng.
Mỗi tham số là `Dict{Vector{Int},Int}` hoặc `Vector{Pair{Vector{Int},Int}}`.
"""
function compare_itemsets(ours::Dict{Vector{Int},Int}, ref::Dict{Vector{Int},Int})::CompareResult
    n_match = 0
    missing_sets = Pair{Vector{Int},Int}[]
    extra_sets = Pair{Vector{Int},Int}[]
    wrong = Tuple{Vector{Int},Int,Int}[]
    for (items, sup_ref) in ref
        sup_ours = get(ours, items, -1)
        if sup_ours == -1
            push!(missing_sets, items => sup_ref)
        elseif sup_ours == sup_ref
            n_match += 1
        else
            push!(wrong, (items, sup_ours, sup_ref))
        end
    end
    for (items, sup_ours) in ours
        haskey(ref, items) || push!(extra_sets, items => sup_ours)
    end
    by_itemset = p -> (length(first(p)), first(p))
    sort!(missing_sets; by = by_itemset)
    sort!(extra_sets; by = by_itemset)
    sort!(wrong; by = by_itemset)
    return CompareResult(length(ours), length(ref), n_match, missing_sets, extra_sets, wrong)
end
compare_itemsets(ours, ref)::CompareResult = compare_itemsets(itemset_dict(ours), itemset_dict(ref))

"Tỉ lệ itemset khớp hoàn toàn trên hợp của hai tập (1.0 khi cả hai cùng rỗng)."
function match_ratio(r::CompareResult)::Float64
    total = r.n_match + length(r.missing_sets) + length(r.extra_sets) + length(r.wrong_support)
    return total == 0 ? 1.0 : r.n_match / total
end

"`true` khi hai kết quả giống hệt nhau (khớp 100%)."
is_exact_match(r::CompareResult)::Bool =
    isempty(r.missing_sets) && isempty(r.extra_sets) && isempty(r.wrong_support)

"In báo cáo so khớp; mỗi nhóm sai lệch in tối đa `limit` dòng."
function print_compare(io::IO, r::CompareResult; limit::Int=20)::Nothing
    println(io, "Số itemset của nhóm : ", r.n_ours)
    println(io, "Số itemset tham chiếu: ", r.n_ref)
    println(io, "Khớp hoàn toàn      : ", r.n_match, " (", round(100 * match_ratio(r); digits=2), "%)")
    println(io, "Thiếu / Thừa / Sai support: ", length(r.missing_sets), " / ",
            length(r.extra_sets), " / ", length(r.wrong_support))
    for (title, rows) in (("THIẾU (có ở tham chiếu)", r.missing_sets), ("THỪA (chỉ có ở nhóm)", r.extra_sets))
        isempty(rows) && continue
        println(io, title, ":")
        for (items, sup) in Iterators.take(rows, limit)
            println(io, "  ", join(items, ' '), " #SUP: ", sup)
        end
        length(rows) > limit && println(io, "  ... còn ", length(rows) - limit, " itemset nữa")
    end
    if !isempty(r.wrong_support)
        println(io, "SAI SUPPORT (nhóm ≠ tham chiếu):")
        for (items, a, b) in Iterators.take(r.wrong_support, limit)
            println(io, "  ", join(items, ' '), " : ", a, " ≠ ", b)
        end
        length(r.wrong_support) > limit &&
            println(io, "  ... còn ", length(r.wrong_support) - limit, " itemset nữa")
    end
    return nothing
end
