# Lập bảng correctness theo từng dataset từ một lần chạy runtime đã có.
#
# Không chạy lại thuật toán: chỉ đọc `summary.csv` do experiments/run_benchmarks.jl
# (hàm `run_case` trong experiments/dataset_benchmarks.jl) sinh ra. Trong lần
# chạy đó, mỗi cấu hình được so với SPMF bằng `compare_itemsets` (từng itemset
# đã sort và support). Cấu hình lệch KHÔNG được ghi vào CSV, nên script còn đối
# chiếu danh sách cấu hình mong đợi trong `environment.toml` cùng thư mục: thiếu
# cấu hình nào thì báo lỗi và thoát với mã khác 0.
#
# Dùng:
#   julia --project experiments/run_correctness.jl <summary.csv> <output.md>

using TOML

# Trả về các cặp (dataset, minsup) mà lần chạy đã dự định chạy.
function expected_configs(env_path::AbstractString)
    cfg = TOML.parsefile(env_path)["config"]
    return [(ds, ms) for ds in cfg["dataset_ids"] for ms in cfg["minsup"][ds]]
end

function read_summary(path::AbstractString)
    lines = filter(!isempty, readlines(path))
    header = [strip(f, '"') for f in split(lines[1], ',')]
    rows = Dict{String,String}[]
    for line in lines[2:end]
        fields = [strip(f, '"') for f in split(line, ',')]
        length(fields) == length(header) || error("Dòng CSV sai số cột: $line")
        push!(rows, Dict(zip(header, fields)))
    end
    return rows
end

function build_table(rows)
    datasets = unique(r["dataset"] for r in rows)
    out = String[]
    push!(out, "| Dataset | minsup | Ngưỡng tuyệt đối | Itemset Julia | Itemset SPMF | Tỉ lệ khớp itemset + support |")
    push!(out, "|---|---:|---:|---:|---:|---|")
    total = 0
    matched = 0
    for ds in datasets
        minsups = unique(r["minsup"] for r in rows if r["dataset"] == ds)
        for ms in minsups
            sel = filter(r -> r["dataset"] == ds && r["minsup"] == ms, rows)
            jl = only(filter(r -> r["miner"] == "julia", sel))
            sp = only(filter(r -> r["miner"] == "spmf", sel))
            jl["threshold"] == sp["threshold"] || error("Ngưỡng lệch: $ds $ms")
            n_jl = parse(Int, jl["itemsets"])
            n_sp = parse(Int, sp["itemsets"])
            ok = n_jl == n_sp && jl["validation"] == "exact_match" &&
                 sp["validation"] == "exact_match"
            total += 1
            matched += ok
            cell = ok ? "$n_jl/$n_sp (100%)" : "KHÔNG KHỚP"
            push!(out, "| $ds | $ms | $(jl["threshold"]) | $n_jl | $n_sp | $cell |")
        end
    end
    push!(out, "")
    push!(out, "Tổng: **$matched/$total** cấu hình khớp hoàn toàn với SPMF.")
    return out, matched, total
end

function main(args)
    length(args) == 2 || error("Dùng: run_correctness.jl <summary.csv> <output.md>")
    rows = read_summary(args[1])
    expected = expected_configs(joinpath(dirname(abspath(args[1])), "environment.toml"))
    present = Set((r["dataset"], r["minsup"], r["miner"]) for r in rows)
    missing_cfg = [(ds, ms, m) for (ds, ms) in expected for m in ("julia", "spmf")
                   if (ds, ms, m) ∉ present]
    if !isempty(missing_cfg)
        println(stderr, "Thiếu $(length(missing_cfg)) dòng so với cấu hình dự định: ",
                join(("$ds $ms $m" for (ds, ms, m) in missing_cfg), "; "))
        exit(1)
    end
    table, matched, total = build_table(rows)
    open(args[2], "w") do io
        println(io, join(table, "\n"))
    end
    println("$matched/$total cấu hình khớp. Đã ghi $(args[2])")
    matched == total || exit(1)
end

main(ARGS)
