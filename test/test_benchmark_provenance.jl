# Integrity checks use temporary artifacts only, never measured result files.
using Test, TOML
include(joinpath(@__DIR__, "..", "experiments", "benchmark_common.jl"))
@testset "Benchmark measurement provenance" begin
    mktempdir() do dir
        config = TOML.parsefile(BenchmarkSupport.CONFIG)
        for kind in ("runtime", "memory")
            for file in BenchmarkSupport.artifacts(kind)
                write(joinpath(dir, file), "temporary regression fixture")
            end
            BenchmarkSupport.metadata(kind, config, BenchmarkSupport.snapshot(); dir=dir)
        end
        @test BenchmarkSupport.validate_runs(dir) == config
        meta = joinpath(dir, "optimization_memory_environment.toml")
        original = read(meta, String)
        info = TOML.parse(original)
        info["config"]["seed"] += 1
        open(io -> TOML.print(io, info), meta, "w")
        @test_throws ErrorException BenchmarkSupport.validate_runs(dir)
        write(meta, original)
        info = TOML.parse(original)
        info["provenance"]["files"]["Project.toml"] = "different code hash"
        open(io -> TOML.print(io, info), meta, "w")
        @test_throws ErrorException BenchmarkSupport.validate_runs(dir)
        write(meta, original)
        raw = joinpath(dir, "optimization_memory_raw.csv")
        content = read(raw, String)
        write(raw, content * "tampered")
        @test_throws ErrorException BenchmarkSupport.validate_runs(dir)
        rm(raw)
        @test_throws ErrorException BenchmarkSupport.validate_runs(dir)
        write(raw, content)
        rm(meta)
        @test_throws ErrorException BenchmarkSupport.validate_runs(dir)
        write(meta, original)
        @test BenchmarkSupport.validate_runs(dir) == config
    end
end
