include("size_benchmarks.jl")
abspath(PROGRAM_FILE) == (@__FILE__) && SizeBenchmarks.main("scalability",ARGS)

