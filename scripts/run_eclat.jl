# CLI: julia --project scripts/run_eclat.jl --input <file> --output <file> --minsup <0.4 | 40%>
# Chỉ dùng ARGS, không cần package ngoài.

using EclatMining

const USAGE = """
Cách dùng:
  julia --project scripts/run_eclat.jl --input <file> --output <file> --minsup <0.4 | 40%>

Tham số:
  --input   file giao dịch định dạng SPMF (mỗi dòng một giao dịch, item cách nhau dấu cách)
  --output  file kết quả, mỗi dòng `i1 i2 ... #SUP: n`
  --minsup  ngưỡng support tương đối: tỉ lệ trong (0, 1] như 0.4, hoặc phần trăm như 40%
            (quy đổi ra tuyệt đối bằng ceil(minsup × số giao dịch), giống SPMF)
"""

# Đọc ARGS thành Dict tên tham số => giá trị. Ném ArgumentError khi thiếu/sai.
function parse_args(args::Vector{String})::Dict{String,String}
    opts = Dict{String,String}()
    i = 1
    while i <= length(args)
        key = args[i]
        key in ("--input", "--output", "--minsup") || throw(ArgumentError("tham số lạ: $key"))
        i < length(args) || throw(ArgumentError("thiếu giá trị cho $key"))
        haskey(opts, key) && throw(ArgumentError("tham số $key bị lặp"))
        opts[key] = args[i+1]
        i += 2
    end
    for key in ("--input", "--output", "--minsup")
        haskey(opts, key) || throw(ArgumentError("thiếu tham số $key"))
    end
    return opts
end

# Trả về exit code: 0 thành công, 1 khi tham số thiếu/sai.
function main(args::Vector{String})::Int
    if "--help" in args || "-h" in args
        print(USAGE)
        return 0
    end
    local opts::Dict{String,String}
    local minsup::Rational{Int}
    try
        opts = parse_args(args)
        minsup = parse_minsup(opts["--minsup"])
        isfile(opts["--input"]) || throw(ArgumentError("không tìm thấy file input: " * opts["--input"]))
    catch err
        err isa ArgumentError || rethrow()
        println(stderr, "Lỗi: ", err.msg, "\n")
        print(stderr, USAGE)
        return 1
    end

    db = read_spmf(opts["--input"])
    threshold = minsup_abs(minsup, length(db))
    elapsed = @elapsed result = eclat(db, threshold)     # chỉ đo bước khai thác
    write_spmf(opts["--output"], result)

    println("Số transaction   : ", length(db))
    println("Minsup tuyệt đối : ", threshold, "  (= ceil(", opts["--minsup"], " × ", length(db), "))")
    println("Số itemset       : ", length(result))
    println("Thời gian khai thác: ", round(elapsed * 1000; digits=3),
            " ms (không tính đọc/ghi file; có gồm thời gian JIT của lần gọi đầu)")
    return 0
end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(main(ARGS))
end
