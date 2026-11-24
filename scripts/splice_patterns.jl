# Ứng dụng sinh học: khai thác motif quanh vị trí cắt nối (splice junction) bằng Eclat của nhóm.
#
# Chạy từ repo root:  julia --project scripts/splice_patterns.jl [--output-dir <thư mục>]
# - Tải splice.data cùng hai file mô tả splice.names, splice.theory từ UCI vào data/raw/ nếu chưa có,
#   kiểm SHA-256 (sai thì dừng, không ghi đè file cũ).
# - Làm sạch, mã hóa theo hai cách, khai thác từng lớp, ghi bảng CSV và run_info.toml vào
#   results/applications/splice/, hoặc vào thư mục truyền qua --output-dir (notebook dùng thư mục tạm
#   để chạy lại mà không ghi đè kết quả đã commit).
# Không có bước ngẫu nhiên: chạy lại trên cùng commit cho ra đúng các file như cũ.

using EclatMining, Downloads, SHA, TOML

const ROOT = dirname(@__DIR__)
const SOURCE_BASE = "https://archive.ics.uci.edu/ml/machine-learning-databases/molecular-biology/splice-junction-gene-sequences/"
const SOURCE_PAGE = "https://archive.ics.uci.edu/dataset/69/molecular+biology+splice+junction+gene+sequences"
const SOURCE_DOI = "10.24432/C5M888"
const SOURCE_LICENSE = "CC BY 4.0"
# File dữ liệu và hai file mô tả đi kèm (định nghĩa lớp, mẫu chuẩn), ghim bằng SHA-256.
const SOURCE_FILES = (
    "splice.data" => "ebbae10c85d3c285e2a2489a37e42bc2ee8d91d15005e391a9962fa3389a114f",
    "splice.names" => "dd67d612a9c57a1230fbeed1e6e0a2130559f419b01765799627236bc7f6fff1",
    "splice.theory" => "9d090c73b9279e5e88531a03f45e04bacc508bffe0c2defebe5225f9f61f12c5",
)
const RAW_DIR = joinpath(ROOT, "data", "raw")
const OUT_DIR = joinpath(ROOT, "results", "applications", "splice")
const WINDOW = 60

# Mỗi cách mã hóa: dải minsup cho bảng số itemset và một minsup chính cho bảng mẫu.
const SETTINGS = (
    (name="nucleotide", enc=NucleotideEncoding(WINDOW),
     grid=[9 // 10, 8 // 10, 7 // 10, 6 // 10, 5 // 10, 2 // 5, 3 // 10, 1 // 4, 1 // 5], main=3 // 10),
    (name="purine_pyrimidine", enc=PurinePyrimidineEncoding(WINDOW),
     grid=[9 // 10, 8 // 10, 7 // 10, 6 // 10, 1 // 2], main=3 // 5),
)

# Đoạn vị trí dùng để vẽ motif trong bảng mẫu.
const MOTIF_FROM = -20
const MOTIF_TO = 10

# Mẫu chuẩn trong file splice.theory kèm bộ dữ liệu (mã IUPAC, vị trí bắt đầu).
const CONSENSUS = (
    (name="donor_full", pattern="MAGGTRAGT", start=-3),
    (name="donor_gt", pattern="GT", start=1),
    (name="acceptor_core", pattern="YAGG", start=-3),
    (name="acceptor_ag", pattern="AG", start=-2),
)

file_sha256(path::AbstractString)::String = bytes2hex(open(sha256, path))

function ensure_file(name::String, expected::String)::String
    path = joinpath(RAW_DIR, name)
    if !isfile(path)
        mkpath(RAW_DIR)
        tmp = path * ".download"
        Downloads.download(SOURCE_BASE * name, tmp)
        got = file_sha256(tmp)
        got == expected || (rm(tmp); error("SHA-256 của $name tải về ($got) khác bản đã ghim ($expected)"))
        mv(tmp, path)
    end
    got = file_sha256(path)
    got == expected || error("$path có SHA-256 $got, khác bản đã ghim $expected; không dùng file này")
    return path
end

# Tải (nếu thiếu) và kiểm cả ba file; trả về đường dẫn splice.data.
function ensure_data()::String
    paths = [ensure_file(name, sha) for (name, sha) in SOURCE_FILES]
    return paths[1]
end

fmt(x::AbstractFloat)::String = isfinite(x) ? string(round(x; digits=4)) : string(x)
fmt(x)::String = string(x)
pct(r::Rational{Int})::String = (p = r * 100; isinteger(p) ? string(Int(p), "%") : string(Float64(p), "%"))
labels(enc::SequenceEncoding, X::Vector{Int})::String = join((item_label(enc, i) for i in X), ' ')

function write_csv(path::AbstractString, header::Vector{String}, rows::Vector{Vector{String}})::Nothing
    open(path, "w") do io
        print(io, join(header, ','), '\n')
        for r in rows
            length(r) == length(header) || error("dòng có $(length(r)) cột, header có $(length(header))")
            print(io, join(r, ','), '\n')
        end
    end
    return nothing
end

class_dbs(records::Vector{SpliceRecord}, enc::SequenceEncoding) =
    Dict{String,Vector{Vector{Int}}}(c => class_transactions(records, c, enc) for c in SPLICE_CLASSES)

# Số itemset theo minsup cho từng lớp: cho thấy lớp N gần như không có mẫu nhiều item.
function count_rows(name::String, enc::SequenceEncoding, grid::Vector{Rational{Int}}, dbs)::Vector{Vector{String}}
    rows = Vector{String}[]
    for cls in SPLICE_CLASSES, ms in grid
        db = dbs[cls]
        res = mine_class(db, ms)
        multi = count(p -> length(first(p)) >= 2, res)
        maxlen = isempty(res) ? 0 : maximum(length(first(p)) for p in res)
        push!(rows, [name, cls, pct(ms), fmt(minsup_abs(ms, length(db))), fmt(length(db)), fmt(length(res)),
                     fmt(multi), fmt(length(maximal_itemsets(res))), fmt(maxlen)])
    end
    return rows
end

# Mọi itemset phổ biến ở minsup chính, kèm support đếm lại ở các lớp khác và chỉ số so sánh lớp.
function pattern_rows(name::String, enc::SequenceEncoding, ms::Rational{Int}, dbs, sizes::Dict{String,Int})
    bits = Dict(c => transaction_bits(dbs[c], n_items(enc)) for c in SPLICE_CLASSES)
    rows = Vector{String}[]
    pairs = Vector{String}[]
    family = Vector{String}[]
    mined = Dict{String,Vector{Pair{Vector{Int},Int}}}()
    for cls in SPLICE_CLASSES
        res = mine_class(dbs[cls], ms)
        mined[cls] = res
        # Số phép kiểm cho Bonferroni: mọi cặp có thể được kiểm, không chỉ các cặp đạt minsup.
        tested = count(p -> p.min_expected >= 5, pair_table(res, sizes[cls]))
        push!(family, [name, cls, pct(ms), fmt(count(p -> length(first(p)) == 1, res)),
                       fmt(candidate_pair_count(res, sizes[cls], enc)), fmt(tested)])
        maximal = Set(first.(maximal_itemsets(res)))
        stats = map(res) do (X, s)
            counts = Dict(c => support_count(bits[c], X) for c in SPLICE_CLASSES)
            (X=X, s=s, r=class_contrast(s, counts, sizes, cls))
        end
        sort!(stats; by=t -> (-length(t.X), -t.s, t.X))
        for t in stats
            push!(rows, [name, cls, pct(ms), fmt(length(t.X)), labels(enc, t.X),
                         pattern_string(enc, t.X; from=MOTIF_FROM, to=MOTIF_TO), fmt(t.s),
                         fmt(t.r.freq), fmt(t.r.freq_ei), fmt(t.r.freq_ie), fmt(t.r.freq_n),
                         fmt(t.r.growth_vs_n), fmt(t.r.confidence), fmt(t.r.lift), fmt(t.X in maximal)])
        end
        for p in sort(pair_table(res, sizes[cls]); by=p -> (p.chi2 >= 0 ? -p.chi2 : 0.0, p.a, p.b))
            push!(pairs, [name, cls, pct(ms), item_label(enc, p.a), item_label(enc, p.b), fmt(p.sup_ab),
                          fmt(p.sup_a), fmt(p.sup_b), fmt(sizes[cls]), fmt(p.lift), fmt(p.chi2), fmt(p.min_expected)])
        end
    end
    return rows, pairs, mined, family
end

jaccard(a::Set{Vector{Int}}, b::Set{Vector{Int}})::Float64 =
    isempty(a) && isempty(b) ? 1.0 : length(intersect(a, b)) / length(union(a, b))

# Tên locus GenBank là phần trước dấu '-' đầu tiên của tên mẫu, ví dụ HUMAPOE4-DONOR-1061 -> HUMAPOE4.
locus(name::AbstractString)::String = String(first(split(name, '-')))

# Đoạn -6..+6 quanh ranh giới, có '|' ở giữa.
function around_boundary(seq::AbstractString)::String
    half = length(seq) ÷ 2
    return string(seq[(half - 5):half], '|', seq[(half + 1):(half + 6)])
end

# Các phép đếm trên dữ liệu gốc (chưa làm sạch) mà ghi chú thiết kế dẫn ra.
function raw_check_rows(raw::Vector{SpliceRecord})::Vector{Vector{String}}
    checks = (
        ("gt_at_+1", r -> matches_consensus(r.seq, "GT", 1)),
        ("ag_at_-2", r -> matches_consensus(r.seq, "AG", -2)),
        ("gt_anywhere", r -> occursin("GT", r.seq)),
        ("name_contains_DONOR", r -> occursin("DONOR", r.name)),
        ("name_contains_ACCEPTOR", r -> occursin("ACCEPTOR", r.name)),
    )
    rows = Vector{String}[]
    for (name, f) in checks, cls in SPLICE_CLASSES
        recs = [r for r in raw if r.class == cls]
        push!(rows, [name, cls, fmt(count(f, recs)), fmt(length(recs))])
    end
    return rows
end

# Donor không có GT tại +1,+2 và acceptor không có AG tại -2,-1 (dữ liệu gốc).
function non_canonical_rows(raw::Vector{SpliceRecord})::Vector{Vector{String}}
    rows = Vector{String}[]
    for r in raw
        lacks = (r.class == "EI" && !matches_consensus(r.seq, "GT", 1)) ||
                (r.class == "IE" && !matches_consensus(r.seq, "AG", -2))
        lacks || continue
        push!(rows, [r.class, r.name, around_boundary(r.seq),
                     fmt(matches_consensus(r.seq, "GC", 1)), fmt(matches_consensus(r.seq, "AG", 1))])
    end
    return rows
end

# Nhóm chuỗi trùng trong cùng lớp và số nhóm gồm nhiều locus GenBank khác nhau.
function duplicate_groups(raw::Vector{SpliceRecord})::Tuple{Int,Int}
    groups = Dict{Tuple{String,String},Vector{String}}()
    for r in raw
        push!(get!(Vector{String}, groups, (r.class, r.seq)), r.name)
    end
    dups = [names for names in values(groups) if length(names) > 1]
    return length(dups), count(g -> length(unique(locus.(g))) > 1, dups)
end

"Thư mục ghi kết quả: mặc định `OUT_DIR`, hoặc thư mục sau `--output-dir`."
function output_dir(args::Vector{String})::String
    isempty(args) && return OUT_DIR
    (length(args) == 2 && args[1] == "--output-dir" && !isempty(args[2])) ||
        error("tham số không hợp lệ; chạy: julia --project scripts/splice_patterns.jl [--output-dir <thư mục>]")
    return abspath(args[2])
end

function main(args::Vector{String})
    out = output_dir(args)
    path = ensure_data()
    # Code hoặc dữ liệu đã commit có bị sửa không; bỏ qua chính thư mục kết quả mà script sẽ ghi đè.
    dirty = !isempty(read(`git -C $ROOT status --porcelain -- . ":(exclude)results/applications/splice"`, String))
    raw = read_splice(path; window=WINDOW)
    cleaning = clean_splice(raw)
    records = cleaning.records
    sizes = class_counts(records)
    println("Đọc $(length(raw)) chuỗi; bỏ $(cleaning.n_duplicates) bản trùng và $(length(cleaning.conflicting)) bản nhãn mâu thuẫn; còn $(length(records)).")

    counts_rows = Vector{String}[]
    patterns = Vector{String}[]
    pairs = Vector{String}[]
    family = Vector{String}[]
    sensitivity = Vector{String}[]
    for st in SETTINGS
        dbs = class_dbs(records, st.enc)
        append!(counts_rows, count_rows(st.name, st.enc, st.grid, dbs))
        rows, prs, mined, fam = pattern_rows(st.name, st.enc, st.main, dbs, sizes)
        append!(patterns, rows)
        append!(pairs, prs)
        append!(family, fam)
        # Độ nhạy với bước làm sạch: khai thác lại trên dữ liệu gốc ở cùng minsup tương đối.
        raw_dbs = class_dbs(raw, st.enc)
        for cls in SPLICE_CLASSES
            a = Set(first.(mined[cls]))
            b = Set(first.(mine_class(raw_dbs[cls], st.main)))
            push!(sensitivity, [st.name, cls, pct(st.main), fmt(length(a)), fmt(length(b)),
                                fmt(length(intersect(a, b))), fmt(jaccard(a, b))])
        end
        println("$(st.name): minsup $(pct(st.main)) -> ", join(("$c $(length(mined[c]))" for c in SPLICE_CLASSES), ", "), " itemset")
    end

    consensus = Vector{String}[]
    for cs in CONSENSUS, cls in SPLICE_CLASSES
        recs = [r for r in records if r.class == cls]
        m = count(r -> matches_consensus(r.seq, cs.pattern, cs.start), recs)
        push!(consensus, [cs.name, cs.pattern, fmt(cs.start), cls, fmt(m), fmt(length(recs)), fmt(m / length(recs))])
    end

    mkpath(out)
    write_csv(joinpath(out, "itemset_counts.csv"),
              ["encoding", "class", "minsup", "minsup_abs", "transactions", "itemsets", "itemsets_2plus", "maximal", "max_length"],
              counts_rows)
    write_csv(joinpath(out, "patterns.csv"),
              ["encoding", "class", "minsup", "length", "itemset", "motif", "support", "freq", "freq_ei", "freq_ie",
               "freq_n", "growth_vs_n", "confidence", "lift", "maximal"],
              patterns)
    write_csv(joinpath(out, "pair_dependence.csv"),
              ["encoding", "class", "minsup", "item_a", "item_b", "sup_ab", "sup_a", "sup_b", "transactions", "lift", "chi2",
               "min_expected"],
              pairs)
    write_csv(joinpath(out, "pair_family.csv"),
              ["encoding", "class", "minsup", "frequent_singles", "candidate_pairs", "tested_pairs"], family)
    write_csv(joinpath(out, "consensus.csv"),
              ["name", "pattern", "start", "class", "matches", "transactions", "fraction"], consensus)
    write_csv(joinpath(out, "cleaning_sensitivity.csv"),
              ["encoding", "class", "minsup", "itemsets_cleaned", "itemsets_raw", "common", "jaccard"], sensitivity)
    write_csv(joinpath(out, "raw_checks.csv"), ["check", "class", "matches", "transactions"], raw_check_rows(raw))
    write_csv(joinpath(out, "non_canonical.csv"), ["class", "name", "around_boundary", "gc_at_+1", "ag_at_+1"],
              non_canonical_rows(raw))

    raw_sizes = class_counts(raw)
    n_groups, n_groups_loci = duplicate_groups(raw)
    info = Dict{String,Any}(
        "data" => Dict{String,Any}(
            "source_base" => SOURCE_BASE, "source_page" => SOURCE_PAGE, "doi" => SOURCE_DOI,
            "license" => SOURCE_LICENSE, "sha256" => Dict{String,Any}(SOURCE_FILES...), "window" => WINDOW),
        "cleaning" => Dict{String,Any}(
            "input" => length(raw), "duplicates_removed" => cleaning.n_duplicates,
            "duplicate_groups" => n_groups, "duplicate_groups_spanning_loci" => n_groups_loci,
            "conflicting_removed" => [r.name for r in cleaning.conflicting], "kept" => length(records),
            "ambiguous_kept" => count(r -> any(c -> !(c in "ACGT"), r.seq), records),
            "raw_class_counts" => raw_sizes, "class_counts" => sizes),
        "mining" => Dict{String,Any}(
            st.name => Dict{String,Any}("minsup_grid" => pct.(st.grid), "minsup_main" => pct(st.main))
            for st in SETTINGS),
        "motif_span" => [MOTIF_FROM, MOTIF_TO],
        "environment" => Dict{String,Any}(
            "julia" => string(VERSION),
            "commit" => strip(read(`git -C $ROOT rev-parse HEAD`, String)),
            "dirty" => dirty),
    )
    open(joinpath(out, "run_info.toml"), "w") do io
        TOML.print(io, info; sorted=true)
    end
    println("Đã ghi kết quả vào $out")
end

abspath(PROGRAM_FILE) == (@__FILE__) && main(ARGS)
