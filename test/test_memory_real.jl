# The memory run on the real datasets must fail when a dataset/minsup/miner pair has fewer
# successful repeats than configured. If every repeat times out there are no itemset counts
# left to disagree, so checking only for disagreement would wrongly report success.
module MemoryRealRun
include(joinpath(@__DIR__, "..", "experiments", "run_memory_real.jl"))
end

@testset "Memory run fails when repeats are missing" begin
    M = MemoryRealRun
    cases = [Dict("dataset" => "chess", "minsup" => "75%"), Dict("dataset" => "retail", "minsup" => "0.1%")]
    observations(dataset, minsup, miner, statuses...) = [(; dataset, minsup, miner, status) for status in statuses]
    complete(dataset, minsup) = vcat((observations(dataset, minsup, m, "success", "success", "success") for m in M.MINERS)...)
    retail_ok = complete("retail", "0.1%")

    @test M.check_run(vcat(complete("chess", "75%"), retail_ok), cases, 3, String[]) === nothing

    # Every repeat of both miners times out: no measurement at all.
    all_timeout = vcat((observations("chess", "75%", m, "timeout", "timeout", "timeout") for m in M.MINERS)...)
    @test_throws "chess 75% baseline: 0/3 successful" M.check_run(vcat(all_timeout, retail_ok), cases, 3, String[])
    @test_throws "chess 75% bitset: 0/3 successful" M.check_run(vcat(all_timeout, retail_ok), cases, 3, String[])

    # A single timeout among three repeats is also a missing measurement.
    one_timeout = vcat(observations("retail", "0.1%", "baseline", "success", "success", "success"),
                       observations("retail", "0.1%", "bitset", "success", "timeout", "success"))
    @test_throws "retail 0.1% bitset: 2/3 successful" M.check_run(vcat(complete("chess", "75%"), one_timeout), cases, 3, String[])

    # Crashes and runs without a result line count as missing too.
    failed = vcat(observations("chess", "75%", "baseline", "success", "process_error", "success"),
                  observations("chess", "75%", "bitset", "validation_failed", "success", "success"))
    @test_throws "chess 75% baseline: 2/3 successful" M.check_run(vcat(failed, retail_ok), cases, 3, String[])
    @test_throws "chess 75% bitset: 2/3 successful" M.check_run(vcat(failed, retail_ok), cases, 3, String[])

    # A configured case with no observation at all.
    @test_throws "chess 75% baseline: 0/3 successful" M.check_run(retail_ok, cases, 3, String[])

    # Disagreeing itemset counts still stop a complete run.
    @test_throws "Itemset counts differ" M.check_run(vcat(complete("chess", "75%"), retail_ok), cases, 3, ["chess 75%: [100, 101]"])
end
