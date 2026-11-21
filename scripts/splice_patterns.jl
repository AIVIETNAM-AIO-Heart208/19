# Ứng dụng sinh học: khai thác motif quanh vị trí cắt nối (splice junction) bằng Eclat của nhóm.
#
# Chạy từ repo root:  julia --project scripts/splice_patterns.jl
# - Tải data/raw/splice.data từ UCI nếu chưa có, kiểm SHA-256 (sai thì dừng, không ghi đè file cũ).
# - Làm sạch, mã hóa theo hai cách, khai thác từng lớp, ghi bảng CSV và run_info.toml vào
#   results/applications/splice/.
# Không có bước ngẫu nhiên: chạy lại trên cùng commit cho ra đúng các file như cũ.

using EclatMining, Downloads, SHA, TOML

const ROOT = dirname(@__DIR__)
const SOURCE_URL = "https://archive.ics.uci.edu/ml/machine-learning-databases/molecular-biology/splice-junction-gene-sequences/splice.data"
const SOURCE_PAGE = "https://archive.ics.uci.edu/dataset/69/molecular+biology+splice+junction+gene+sequences"
const SOURCE_DOI = "10.24432/C5M888"
const SOURCE_LICENSE = "CC BY 4.0"
const DATA_SHA256 = "ebbae10c85d3c285e2a2489a37e42bc2ee8d91d15005e391a9962fa3389a114f"
const DATA_PATH = joinpath(ROOT, "data", "raw", "splice.data")
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

function ensure_data()::String
    if !isfile(DATA_PATH)
        mkpath(dirname(DATA_PATH))
        tmp = DATA_PATH * ".download"
        Downloads.download(SOURCE_URL, tmp)
        got = file_sha256(tmp)
        got == DATA_SHA256 || (rm(tmp); error("SHA-256 của file tải về ($got) khác bản đã ghim ($DATA_SHA256)"))
        mv(tmp, DATA_PATH)
    end
    got = file_sha256(DATA_PATH)
    got == DATA_SHA256 || error("$DATA_PATH có SHA-256 $got, khác bản đã ghim $DATA_SHA256; không dùng file này")
    return DATA_PATH
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
    mined = Dict{String,Vector{Pair{Vector{Int},Int}}}()
    for cls in SPLICE_CLASSES
        res = mine_class(dbs[cls], ms)
        mined[cls] = res
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
    return rows, pairs, mined
end

jaccard(a::Set{Vector{Int}}, b::Set{Vector{Int}})::Float64 =
    isempty(a) && isempty(b) ? 1.0 : length(intersect(a, b)) / length(union(a, b))

function main()
    isempty(ARGS) || error("script không nhận tham số; chạy: julia --project scripts/splice_patterns.jl")
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
    sensitivity = Vector{String}[]
    for st in SETTINGS
        dbs = class_dbs(records, st.enc)
        append!(counts_rows, count_rows(st.name, st.enc, st.grid, dbs))
        rows, prs, mined = pattern_rows(st.name, st.enc, st.main, dbs, sizes)
        append!(patterns, rows)
        append!(pairs, prs)
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

    mkpath(OUT_DIR)
    write_csv(joinpath(OUT_DIR, "itemset_counts.csv"),
              ["encoding", "class", "minsup", "minsup_abs", "transactions", "itemsets", "itemsets_2plus", "maximal", "max_length"],
              counts_rows)
    write_csv(joinpath(OUT_DIR, "patterns.csv"),
              ["encoding", "class", "minsup", "length", "itemset", "motif", "support", "freq", "freq_ei", "freq_ie",
               "freq_n", "growth_vs_n", "confidence", "lift", "maximal"],
              patterns)
    write_csv(joinpath(OUT_DIR, "pair_dependence.csv"),
              ["encoding", "class", "minsup", "item_a", "item_b", "sup_ab", "sup_a", "sup_b", "transactions", "lift", "chi2",
               "min_expected"],
              pairs)
    write_csv(joinpath(OUT_DIR, "consensus.csv"),
              ["name", "pattern", "start", "class", "matches", "transactions", "fraction"], consensus)
    write_csv(joinpath(OUT_DIR, "cleaning_sensitivity.csv"),
              ["encoding", "class", "minsup", "itemsets_cleaned", "itemsets_raw", "common", "jaccard"], sensitivity)

    raw_sizes = class_counts(raw)
    info = Dict{String,Any}(
        "data" => Dict{String,Any}(
            "source_url" => SOURCE_URL, "source_page" => SOURCE_PAGE, "doi" => SOURCE_DOI,
            "license" => SOURCE_LICENSE, "sha256" => DATA_SHA256, "window" => WINDOW),
        "cleaning" => Dict{String,Any}(
            "input" => length(raw), "duplicates_removed" => cleaning.n_duplicates,
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
    open(joinpath(OUT_DIR, "run_info.toml"), "w") do io
        TOML.print(io, info; sorted=true)
    end
    println("Đã ghi kết quả vào $OUT_DIR")
end

main()
