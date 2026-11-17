# So khớp hai file kết quả dạng tập {(itemset đã sort, support)}.
#   julia --project experiments/spmf/compare.jl ours.txt spmf.txt
# Exit code: 0 nếu khớp 100%, 1 nếu lệch, 2 nếu sai tham số.

using EclatMining

function main(args::Vector{String})::Int
    if length(args) != 2 || !all(isfile, args)
        println(stderr, "Cách dùng: julia --project experiments/spmf/compare.jl <output của nhóm> <output tham chiếu SPMF>")
        return 2
    end
    result = compare_itemsets(read_spmf_output(args[1]), read_spmf_output(args[2]))
    print_compare(stdout, result)
    if is_exact_match(result)
        println("KẾT QUẢ: KHỚP 100%")
        return 0
    end
    println("KẾT QUẢ: KHÔNG KHỚP")
    return 1
end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(main(ARGS))
end
