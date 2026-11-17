include("dataset_benchmarks.jl")
abspath(PROGRAM_FILE) == (@__FILE__) && DatasetBenchmarks.main(ARGS)
