# Ứng dụng sinh học: khai thác mẫu bảo tồn quanh vị trí cắt nối (splice junction) trong DNA.
#
# Dữ liệu: UCI "Molecular Biology (Splice-junction Gene Sequences)", mỗi mẫu là một cửa sổ
# 60 nucleotide quanh một vị trí, nhãn EI (exon -> intron, donor), IE (intron -> exon, acceptor)
# hoặc N (không phải vị trí cắt nối). Cửa sổ đánh số -30..-1, +1..+30, không có vị trí 0;
# ranh giới nằm giữa -1 và +1.
#
# Mỗi chuỗi thành một giao dịch: item là cặp (vị trí, ký hiệu). Itemset phổ biến là một tổ hợp
# vị trí cố định cùng xuất hiện trong nhiều chuỗi, tức một motif có khoảng trống. TID-set của
# item (p, b) chính là tập chuỗi có ký hiệu b tại vị trí p, nên phép giao của Eclat là phép lọc
# "chuỗi khớp mọi vị trí của mẫu". Mọi itemset ở đây đều do `eclat` của nhóm sinh ra; các hàm
# còn lại chỉ đọc, mã hóa, đếm lại và tính chỉ số trên kết quả đó.

export SPLICE_CLASSES, SpliceRecord, read_splice, SpliceCleaning, clean_splice, class_counts
export SequenceEncoding, NucleotideEncoding, PurinePyrimidineEncoding
export n_items, item_label, item_id, encode, class_transactions, mine_class
export maximal_itemsets, transaction_bits, support_count, class_contrast
export pair_dependence, pair_table, pattern_string, matches_consensus

"Ba lớp của bộ dữ liệu: EI = donor (exon -> intron), IE = acceptor (intron -> exon), N = không phải."
const SPLICE_CLASSES = ("EI", "IE", "N")

# Mã IUPAC cho DNA: mỗi ký hiệu ứng với tập nucleotide nó có thể là.
const IUPAC = Dict{Char,String}(
    'A' => "A", 'C' => "C", 'G' => "G", 'T' => "T",
    'R' => "AG", 'Y' => "CT", 'S' => "CG", 'W' => "AT", 'K' => "GT", 'M' => "AC",
    'B' => "CGT", 'D' => "AGT", 'H' => "ACT", 'V' => "ACG", 'N' => "ACGT",
)

# ---------------------------------------------------------------------------
# Đọc dữ liệu
# ---------------------------------------------------------------------------

"Một mẫu: lớp (EI, IE, N), tên mẫu trong GenBank và chuỗi nucleotide (chữ hoa)."
struct SpliceRecord
    class::String
    name::String
    seq::String
end
Base.:(==)(a::SpliceRecord, b::SpliceRecord) = a.class == b.class && a.name == b.name && a.seq == b.seq

function check_window(window::Int)::Nothing
    (window >= 2 && iseven(window)) || throw(ArgumentError("cửa sổ phải là số chẵn ≥ 2, nhận được $window"))
    return nothing
end

function parse_splice_line(line::AbstractString, lineno::Int, window::Int)::SpliceRecord
    parts = split(line, ',')
    length(parts) == 3 || throw(ArgumentError("dòng $lineno: cần 3 trường 'lớp, tên, chuỗi', có $(length(parts))"))
    cls = String(strip(parts[1]))
    cls in SPLICE_CLASSES || throw(ArgumentError("dòng $lineno: lớp lạ \"$cls\""))
    seq = uppercase(String(strip(parts[3])))
    length(seq) == window || throw(ArgumentError("dòng $lineno: chuỗi dài $(length(seq)), cần $window"))
    for c in seq
        haskey(IUPAC, c) || throw(ArgumentError("dòng $lineno: ký tự '$c' không phải mã IUPAC của DNA"))
    end
    return SpliceRecord(cls, String(strip(parts[2])), seq)
end

"""
    read_splice(path_or_io; window=60) -> Vector{SpliceRecord}

Đọc file `splice.data` của UCI: mỗi dòng `lớp, tên, chuỗi`. Bỏ dòng trống, chịu được CRLF và
chữ thường. Báo lỗi khi lớp lạ, thiếu trường, sai độ dài cửa sổ hoặc ký tự không phải mã IUPAC.
"""
function read_splice(io::IO; window::Int=60)::Vector{SpliceRecord}
    check_window(window)
    out = SpliceRecord[]
    for (lineno, line) in enumerate(eachline(io))
        isempty(strip(line)) && continue
        push!(out, parse_splice_line(line, lineno, window))
    end
    return out
end
read_splice(path::AbstractString; window::Int=60)::Vector{SpliceRecord} = open(io -> read_splice(io; window=window), path)

# ---------------------------------------------------------------------------
# Làm sạch
# ---------------------------------------------------------------------------

"Kết quả làm sạch: bản ghi giữ lại, số dòng đầu vào, số bản trùng đã bỏ, các bản ghi nhãn mâu thuẫn."
struct SpliceCleaning
    records::Vector{SpliceRecord}
    n_input::Int
    n_duplicates::Int
    conflicting::Vector{SpliceRecord}
end

"""
    clean_splice(records) -> SpliceCleaning

- Cùng chuỗi, cùng lớp xuất hiện nhiều lần (cùng một vị trí cắt nối nằm trong nhiều bản ghi
  GenBank): giữ bản đầu tiên, vì bản sao làm support bị đếm lặp.
- Cùng chuỗi nhưng khác lớp: không biết nhãn nào đúng nên loại mọi bản.
Thứ tự các bản ghi giữ lại theo thứ tự gốc.
"""
function clean_splice(records::Vector{SpliceRecord})::SpliceCleaning
    labels = Dict{String,Set{String}}()
    for r in records
        push!(get!(Set{String}, labels, r.seq), r.class)
    end
    kept = SpliceRecord[]
    conflicting = SpliceRecord[]
    seen = Set{String}()
    dups = 0
    for r in records
        if length(labels[r.seq]) > 1
            push!(conflicting, r)
        elseif r.seq in seen
            dups += 1
        else
            push!(seen, r.seq)
            push!(kept, r)
        end
    end
    return SpliceCleaning(kept, length(records), dups, conflicting)
end

"Số bản ghi của từng lớp (có đủ ba lớp, kể cả lớp 0 bản ghi)."
function class_counts(records::Vector{SpliceRecord})::Dict{String,Int}
    counts = Dict{String,Int}(c => 0 for c in SPLICE_CLASSES)
    for r in records
        counts[r.class] += 1
    end
    return counts
end

# ---------------------------------------------------------------------------
# Mã hóa chuỗi thành giao dịch
# ---------------------------------------------------------------------------

"Cách biến một chuỗi thành giao dịch; mỗi kiểu con định nghĩa bảng ký hiệu và `symbol_index`."
abstract type SequenceEncoding end

"Item = (vị trí, nucleotide A/C/G/T): 4 item mỗi vị trí, 4 × window item."
struct NucleotideEncoding <: SequenceEncoding
    window::Int
    NucleotideEncoding(window::Int) = (check_window(window); new(window))
end

"Item = (vị trí, nhóm base): R = purin (A/G), Y = pyrimidin (C/T); 2 × window item."
struct PurinePyrimidineEncoding <: SequenceEncoding
    window::Int
    PurinePyrimidineEncoding(window::Int) = (check_window(window); new(window))
end

symbols(::NucleotideEncoding) = ('A', 'C', 'G', 'T')
symbols(::PurinePyrimidineEncoding) = ('R', 'Y')

# Chỉ số ký hiệu của một ký tự trong chuỗi; 0 nghĩa là không xác định được, vị trí đó không sinh item.
symbol_index(::NucleotideEncoding, c::Char)::Int = c == 'A' ? 1 : c == 'C' ? 2 : c == 'G' ? 3 : c == 'T' ? 4 : 0
symbol_index(::PurinePyrimidineEncoding, c::Char)::Int =
    (c == 'A' || c == 'G' || c == 'R') ? 1 : (c == 'C' || c == 'T' || c == 'Y') ? 2 : 0

"Số item phân biệt của cách mã hóa."
n_items(enc::SequenceEncoding)::Int = enc.window * length(symbols(enc))

"Ký tự thứ `j` (1..window) nằm ở vị trí nào: -window/2..-1 rồi +1..+window/2."
function position_offset(j::Int, window::Int)::Int
    half = window ÷ 2
    return j <= half ? j - half - 1 : j - half
end

function position_index(offset::Int, window::Int)::Int
    half = window ÷ 2
    (offset != 0 && abs(offset) <= half) || throw(ArgumentError("vị trí $offset nằm ngoài cửa sổ ±$half (không có vị trí 0)"))
    return offset < 0 ? offset + half + 1 : offset + half
end

"Nhãn đọc được của item, ví dụ `+1G` (nucleotide G ngay sau ranh giới) hay `-5Y`."
function item_label(enc::SequenceEncoding, id::Int)::String
    1 <= id <= n_items(enc) || throw(ArgumentError("item $id ngoài khoảng 1..$(n_items(enc))"))
    k = length(symbols(enc))
    p = position_offset((id - 1) ÷ k + 1, enc.window)
    return string(p > 0 ? "+" : "", p, symbols(enc)[(id - 1) % k + 1])
end

"Ngược của `item_label`: `item_id(enc, \"+1G\")`."
function item_id(enc::SequenceEncoding, label::AbstractString)::Int
    m = match(r"^([+-]?\d+)([A-Z])$", label)
    m === nothing && throw(ArgumentError("nhãn item không hợp lệ: \"$label\""))
    j = position_index(parse(Int, m.captures[1]), enc.window)
    s = findfirst(==(only(m.captures[2])), symbols(enc))
    s === nothing && throw(ArgumentError("ký hiệu '$(m.captures[2])' không thuộc cách mã hóa $(typeof(enc))"))
    return (j - 1) * length(symbols(enc)) + s
end

"""
    encode(enc, seq) -> Vector{Int}

Một chuỗi thành một giao dịch: mỗi vị trí có ký hiệu xác định sinh đúng một item, nên giao dịch
đã sort tăng dần và dài tối đa `window`. Ký tự mơ hồ (ví dụ N) không sinh item: không đoán base.
"""
function encode(enc::SequenceEncoding, seq::AbstractString)::Vector{Int}
    length(seq) == enc.window || throw(ArgumentError("chuỗi dài $(length(seq)), cần $(enc.window)"))
    k = length(symbols(enc))
    t = Int[]
    sizehint!(t, enc.window)
    for (j, c) in enumerate(seq)
        s = symbol_index(enc, c)
        s == 0 || push!(t, (j - 1) * k + s)
    end
    return t
end

"CSDL giao dịch của một lớp, theo thứ tự bản ghi."
class_transactions(records::Vector{SpliceRecord}, cls::AbstractString, enc::SequenceEncoding)::Vector{Vector{Int}} =
    [encode(enc, r.seq) for r in records if r.class == cls]

# ---------------------------------------------------------------------------
# Khai thác và hậu xử lý
# ---------------------------------------------------------------------------

"""
    mine_class(db, minsup) -> Vector{Pair{Vector{Int},Int}}

Khai thác bằng `eclat` của nhóm với minsup tương đối trong lớp (ngưỡng tuyệt đối
`ceil(minsup × |db|)` như phần còn lại của dự án). Kết quả sort theo itemset để ổn định.
"""
function mine_class(db::Vector{Vector{Int}}, minsup::Rational{Int})::Vector{Pair{Vector{Int},Int}}
    res = eclat(db, minsup_abs(minsup, length(db)))
    return sort!(res; by=first)
end
mine_class(db::Vector{Vector{Int}}, minsup::AbstractString) = mine_class(db, parse_minsup(minsup))

"""
    maximal_itemsets(itemsets) -> Vector{Pair{Vector{Int},Int}}

Giữ itemset phổ biến không nằm trong itemset phổ biến nào lớn hơn. Nhờ tính đóng xuống, X có
tập cha phổ biến khi và chỉ khi có tập cha phổ biến lớn hơn đúng một item, nên chỉ cần đánh dấu
mọi tập con bỏ-một-item của từng itemset. Giữ thứ tự đầu vào.
"""
function maximal_itemsets(itemsets::Vector{Pair{Vector{Int},Int}})::Vector{Pair{Vector{Int},Int}}
    covered = Set{Vector{Int}}()
    for (Y, _) in itemsets
        length(Y) > 1 || continue
        ys = issorted(Y) ? Y : sort(Y)
        for k in eachindex(ys)
            push!(covered, deleteat!(copy(ys), k))
        end
    end
    return [p for p in itemsets if !((issorted(first(p)) ? first(p) : sort(first(p))) in covered)]
end

"Mỗi giao dịch thành một BitVector độ dài `nitems` để đếm nhanh một mẫu có nằm trong giao dịch không."
function transaction_bits(db::Vector{Vector{Int}}, nitems::Int)::Vector{BitVector}
    out = Vector{BitVector}(undef, length(db))
    for (t, tx) in enumerate(db)
        b = falses(nitems)
        for i in tx
            1 <= i <= nitems || throw(ArgumentError("item $i ngoài khoảng 1..$nitems"))
            b[i] = true
        end
        out[t] = b
    end
    return out
end

"Số giao dịch chứa mọi item của `itemset` (đếm trực tiếp, dùng để tra một mẫu ở lớp khác)."
support_count(bits::Vector{BitVector}, itemset::Vector{Int})::Int = count(b -> all(i -> b[i], itemset), bits)

"""
    class_contrast(sup_mined, counts, sizes, cls) -> NamedTuple

Mẫu X khai thác được ở lớp `cls` với support `sup_mined`. `counts[c]` là số chuỗi lớp c chứa X
(đếm lại), `sizes[c]` là số chuỗi của lớp c. Trả về:
- `freq_*`: tỉ lệ chuỗi chứa X trong từng lớp; `freq` là của lớp `cls`.
- `growth_vs_n = freq / freq_n`: X phổ biến ở `cls` gấp bao nhiêu lần ở nhóm đối chứng N.
- `confidence = P(cls | X)` trên toàn dữ liệu và `lift = confidence / P(cls)`: luật X -> cls.
  Hai chỉ số này phụ thuộc tỉ lệ lớp do người dựng bộ dữ liệu chọn, không phải tỉ lệ trong genome.
Báo lỗi khi support của Eclat khác số đếm lại ở chính lớp đó.
"""
function class_contrast(sup_mined::Int, counts::Dict{String,Int}, sizes::Dict{String,Int}, cls::AbstractString)
    counts[cls] == sup_mined || throw(ArgumentError("support từ Eclat ($sup_mined) khác số đếm lại ($(counts[cls])) ở lớp $cls"))
    freq(c) = counts[c] / sizes[c]
    f = freq(cls)
    fn = freq("N")
    growth = fn == 0 ? (f > 0 ? Inf : NaN) : f / fn
    total_x = sum(counts[c] for c in SPLICE_CLASSES)
    total = sum(sizes[c] for c in SPLICE_CLASSES)
    conf = counts[cls] / total_x
    return (freq=f, freq_ei=freq("EI"), freq_ie=freq("IE"), freq_n=fn, growth_vs_n=growth,
            confidence=conf, lift=conf / (sizes[cls] / total))
end

"""
    pair_dependence(sup_ab, sup_a, sup_b, n) -> (lift, chi2)

Hai vị trí a, b trong n chuỗi. `lift = n·sup_ab / (sup_a·sup_b)`: bằng 1 khi hai vị trí độc lập
(giả định của ma trận trọng số theo vị trí), > 1 khi hay đi cùng nhau, < 1 khi né nhau.
`chi2` là thống kê χ² của bảng 2×2 (1 bậc tự do; > 10,83 ứng với p < 0,001 khi chỉ kiểm một
cặp, kiểm nhiều cặp thì phải hiệu chỉnh). NaN khi một vị trí có mặt ở mọi chuỗi hoặc không chuỗi nào.
"""
function pair_dependence(sup_ab::Int, sup_a::Int, sup_b::Int, n::Int)
    (0 <= sup_ab <= min(sup_a, sup_b) && max(sup_a, sup_b) <= n && sup_a + sup_b - sup_ab <= n) ||
        throw(ArgumentError("support không nhất quán: sup_ab=$sup_ab, sup_a=$sup_a, sup_b=$sup_b, n=$n"))
    a = sup_ab
    b = sup_a - sup_ab
    c = sup_b - sup_ab
    d = n - sup_a - sup_b + sup_ab
    denom = Float64(sup_a) * (n - sup_a) * sup_b * (n - sup_b)
    chi2 = denom == 0 ? NaN : n * (Float64(a) * d - Float64(b) * c)^2 / denom
    lift = sup_a * sup_b == 0 ? NaN : n * sup_ab / (Float64(sup_a) * sup_b)
    return (lift=lift, chi2=chi2)
end

"""
    pair_table(itemsets, n) -> Vector{NamedTuple}

Với mỗi 2-itemset phổ biến {a, b} trong kết quả của một lớp có n chuỗi: support của cặp và của
từng item (có sẵn trong kết quả nhờ tính đóng xuống), kèm lift và χ².
"""
function pair_table(itemsets::Vector{Pair{Vector{Int},Int}}, n::Int)
    single = Dict{Int,Int}(only(X) => s for (X, s) in itemsets if length(X) == 1)
    rows = NamedTuple{(:a, :b, :sup_ab, :sup_a, :sup_b, :lift, :chi2),Tuple{Int,Int,Int,Int,Int,Float64,Float64}}[]
    for (X, s) in itemsets
        length(X) == 2 || continue
        a, b = minmax(X[1], X[2])
        (haskey(single, a) && haskey(single, b)) || throw(ArgumentError("thiếu support của item đơn trong cặp $X"))
        d = pair_dependence(s, single[a], single[b], n)
        push!(rows, (a=a, b=b, sup_ab=s, sup_a=single[a], sup_b=single[b], lift=d.lift, chi2=d.chi2))
    end
    return rows
end

# ---------------------------------------------------------------------------
# Trình bày và đối chiếu với mẫu chuẩn
# ---------------------------------------------------------------------------

"""
    pattern_string(enc, itemset; from, to) -> String

Vẽ itemset trên đoạn vị trí `from..to`: ký hiệu ở vị trí có trong mẫu, `.` ở vị trí tự do, `|`
tại ranh giới. Ví dụ `-1G +1G +2T +4A +5G` trên -3..+6 là `..G|GT.AG.`.
"""
function pattern_string(enc::SequenceEncoding, itemset::Vector{Int}; from::Int, to::Int)::String
    i_from = position_index(from, enc.window)
    i_to = position_index(to, enc.window)
    i_from <= i_to || throw(ArgumentError("from ($from) phải đứng trước to ($to)"))
    k = length(symbols(enc))
    at = Dict{Int,Char}()
    for id in itemset
        1 <= id <= n_items(enc) || throw(ArgumentError("item $id ngoài khoảng 1..$(n_items(enc))"))
        j = (id - 1) ÷ k + 1
        haskey(at, j) && throw(ArgumentError("itemset có hai item ở cùng vị trí $(position_offset(j, enc.window))"))
        at[j] = symbols(enc)[(id - 1) % k + 1]
    end
    io = IOBuffer()
    for j in i_from:i_to
        j == enc.window ÷ 2 + 1 && j != i_from && print(io, '|')
        print(io, get(at, j, '.'))
    end
    return String(take!(io))
end

"""
    matches_consensus(seq, consensus, start) -> Bool

Chuỗi `seq` có khớp mẫu chuẩn `consensus` (mã IUPAC) đặt từ vị trí `start` không, ví dụ mẫu
donor `MAGGTRAGT` từ -3 trong tài liệu kèm bộ dữ liệu. Vị trí nhảy từ -1 sang +1. Nucleotide mơ
hồ trong `seq` (ví dụ N) không được tính là khớp.
"""
function matches_consensus(seq::AbstractString, consensus::AbstractString, start::Int)::Bool
    window = length(seq)
    check_window(window)
    chars = collect(seq)
    pattern = collect(consensus)
    # Chỉ số ký tự trong `seq` của từng ký hiệu mẫu chuẩn; báo lỗi nếu mẫu vượt cửa sổ.
    idx = Vector{Int}(undef, length(pattern))
    p = start
    for k in eachindex(pattern)
        haskey(IUPAC, pattern[k]) || throw(ArgumentError("ký tự '$(pattern[k])' của mẫu chuẩn không phải mã IUPAC"))
        idx[k] = position_index(p, window)
        p = p == -1 ? 1 : p + 1
    end
    for k in eachindex(pattern)
        b = chars[idx[k]]
        (b in ('A', 'C', 'G', 'T') && b in IUPAC[pattern[k]]) || return false
    end
    return true
end
