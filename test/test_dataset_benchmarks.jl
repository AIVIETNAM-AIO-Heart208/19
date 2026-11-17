include(joinpath(@__DIR__, "..", "experiments", "dataset_benchmarks.jl"))
using .DatasetBenchmarks

@testset "Dataset benchmark safeguards" begin
    B = DatasetBenchmarks
    @test B.levels(["90%", "80%", "70%", "60%", "50%"], 100) == [90,80,70,60,50]
    @test_throws Exception B.levels(["90%", "80%"], 100)
    @test_throws Exception B.levels(["90%", "80%", "70%", "60%", "50%"], 2)
    @test_throws Exception B.levels(["90%", "80%", "85%", "60%", "50%"], 100)
    @test_throws Exception B.levels(["90%", "80%", "70%", "60%", "0%"], 100)
    @test B.summarize([1,2,3,4,5], 5) == (median=3.0, q1=2.0, q3=4.0, iqr=2.0)
    @test_throws Exception B.summarize([1,2], 5)
    @test_throws Exception B.summarize([missing], 1)
    mktempdir() do dir
        a, b = joinpath(dir, "unicode input a.txt"), joinpath(dir, "b.txt")
        write(a, "@FILETYPE=FrequentItemsets\n1 #SUP: 2\n")
        write(b, "1 #SUP: 2\n")
        @test B.output_count(a) == 1
        @test B.exact_outputs(a,b)
        write(b, "1 #SUP: 1\n")
        @test !B.exact_outputs(a,b)
        write(b, "")
        @test B.output_count(b) == 0
        @test !B.exact_outputs(a,b)
        write(b, "broken")
        @test_throws Exception B.output_count(b)
        # A failed parse must release its file before Windows cleanup/replacement.
        rm(b)
        @test !isfile(b)
        @test_throws Exception B.output_count(joinpath(dir, "missing"))
        log = joinpath(dir, "child.log")
        @test B.timed_process(`$(Base.julia_cmd()) --startup-file=no -e 'exit(3)'`, log, 20).status == "process_error"
        @test B.timed_process(`$(Base.julia_cmd()) --startup-file=no -e 'sleep(10)'`, log, 0.1).status == "timeout"
    end
end
