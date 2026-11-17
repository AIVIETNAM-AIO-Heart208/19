using EclatMining

function main(args)
    length(args) == 3 || error("Expected input, output, minsup")
    input, output, support = args
    db = read_spmf(input)
    result = eclat_bitset(db, minsup_abs(support, length(db)))
    n = write_spmf(output, result; sorted=false)
    println("BENCHMARK_COMPLETE ", n)
end

abspath(PROGRAM_FILE) == (@__FILE__) && main(ARGS)
