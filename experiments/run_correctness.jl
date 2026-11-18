# Lập bảng correctness theo từng dataset từ một lần chạy runtime đã có.
#
# Không chạy lại thuật toán: chỉ đọc `summary.csv` do experiments/run_runtime.jl
# sinh ra. Trong lần chạy đó, mỗi cấu hình đã được so với SPMF bằng
# `compare_itemsets` (từng itemset đã sort và support), kết quả ghi ở cột
# `validation`.
#
# Dùng:
#   julia --project experiments/run_correctness.jl <summary.csv> <output.md>

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
    table, matched, total = build_table(rows)
    open(args[2], "w") do io
        println(io, join(table, "\n"))
    end
    println("$matched/$total cấu hình khớp. Đã ghi $(args[2])")
    matched == total || exit(1)
end

main(ARGS)
