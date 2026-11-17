include("size_benchmarks.jl")
abspath(PROGRAM_FILE) == (@__FILE__) && SizeBenchmarks.main("transaction_length",ARGS)

