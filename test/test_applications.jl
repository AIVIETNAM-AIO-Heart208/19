@testset "Online Retail baskets" begin
    line(invoice, code; description=code, quantity=1, price=1) =
        (; invoice, code, description, quantity, price)
    rows = [
        line("2", "B2"), line("1", "100A"), line("1", "B2"),
        line("2", "100A"), line("1", "B2"; quantity=3),
        line("c3", "B2"), line("4", "POST"), line("5", "B2"; quantity=0),
        line("6", "B2"; price=0), line("7", "B2"; price=nothing),
        line("", "B2"), line("8", ""),
    ]
    data = EclatMining.market_baskets(rows; excluded_codes=("POST",))
    @test data.invoices == ["1", "2"]
    @test data.codes == ["100A", "B2"]
    @test data.db == [[1, 2], [1, 2]]
    @test data.stats.eligible_baskets == 3
    @test data.stats.removed_codes == Dict("POST" => 1)
    reordered = EclatMining.market_baskets(reverse(rows); excluded_codes=("POST",))
    @test reordered.codes == data.codes
    @test reordered.db == data.db
end

module RetailRunner
include(joinpath(@__DIR__, "..", "scripts", "run_market_basket.jl"))
end

@testset "Reading invoice lines from Excel" begin
    mktempdir() do dir
        path = joinpath(dir, "sample.xlsx")
        RetailRunner.XLSX.openxlsx(path, mode="w") do book
            sheet = book[1]
            sheet["A1"] = ["InvoiceNo" "StockCode" "Description" "Quantity" "InvoiceDate" "UnitPrice"]
            sheet["A2"] = [101 "01A" "Tea" 1 "" 1.0]
            sheet["A3"] = [101 22 "Coffee" 1 "" 3.5]
            sheet["A4"] = ["c102" "01A" "Tea" 1 "" 1.0]
        end
        data = RetailRunner.workbook_baskets(path)
        @test data.codes == ["01A", "22"]
        @test data.invoices == ["101"]
        @test data.db == [[1, 2]]
        original = read(path)
        @test_throws "SHA-256 mismatch" RetailRunner.prepare_workbook(path)
        @test read(path) == original
        alias = joinpath(dir, "output.md")
        hardlink(path, alias)
        @test_throws "different from the input file" RetailRunner.main([path, alias, "1%", "50%"])
        @test read(path) == original
    end
end

@testset "Market basket CLI rejects invalid input" begin
    mktempdir() do dir
        output = joinpath(dir, "rules.md")
        workbook = joinpath(dir, "missing", "invoices.xlsx")
        @test_throws "Workbook not found: $workbook" RetailRunner.main([workbook, output, "1%", "50%"])
        @test !ispath(dirname(workbook))
        @test !ispath(output)

        input = joinpath(dir, "invoices.tsv")
        write(output, "previous report")
        for (invalid, columns) in (("2\tB\tTea\t1", 4), ("2\tB\tTea\t1\t2\t", 6))
            write(input, "1\tA\t\t1\t2\r\n", invalid, "\r\n")
            @test_throws "TSV line 2: expected 5 columns, found $columns" RetailRunner.main([input, output, "1%", "50%"])
            @test read(output, String) == "previous report"
        end
    end
end

@testset "Market basket CLI protects invoice input" begin
    root = dirname(@__DIR__)
    script = joinpath(root, "scripts", "run_market_basket.jl")
    mktempdir() do dir
        input = joinpath(dir, "invoices.tsv")
        alias = joinpath(dir, "alias.md")
        original = "1\t100A\tTea\t1\t1\n"
        write(input, original)
        hardlink(input, alias)
        for output in (input, alias)
            errors = IOBuffer()
            cmd = `$(Base.julia_cmd()) --startup-file=no --project=$root $script $input $output 1% 50%`
            @test !success(pipeline(cmd; stdout=devnull, stderr=errors))
            @test occursin("different from the input file", String(take!(errors)))
            @test read(input, String) == original
        end
    end
end

@testset "Market basket confidence thresholds" begin
    for value in ("0", "0%", "0.0", "0.0%", " .00% ")
        @test EclatMining.parse_minconf(value) === 0 // 1
        @test_throws ArgumentError parse_minsup(value)
    end
    @test EclatMining.parse_minconf("0.01%") === 1 // 10000
    @test EclatMining.parse_minconf("100%") === 1 // 1
    for value in ("-0.1", "101%", "0..0%", "%")
        @test_throws ArgumentError EclatMining.parse_minconf(value)
    end
    root = dirname(@__DIR__)
    script = joinpath(root, "scripts", "run_market_basket.jl")
    mktempdir() do dir
        input, output = joinpath(dir, "input.tsv"), joinpath(dir, "rules.md")
        write(input, "1\t100A\tTea\t1\t1\n1\t200B\tCoffee\t1\t1\n")
        tables = map(("0%", "0.0%")) do minconf
            run(`$(Base.julia_cmd()) --startup-file=no --project=$root $script $input $output 1% $minconf`)
            filter(line -> startswith(line, "| 1 |") || startswith(line, "| 2 |"), readlines(output))
        end
        @test length(first(tables)) == 2
        @test first(tables) == last(tables)
    end
end

@testset "Association rules" begin
    db = [[1, 2, 3], [1, 2, 3], [1], [3]]
    itemsets = eclat(db, 2)
    rules = EclatMining.association_rules(itemsets, 4, 2 // 3)
    forward = only(r for r in rules if r.antecedent == (1, 2) && r.consequent == (3,))
    backward = only(r for r in rules if r.antecedent == (3,) && r.consequent == (1, 2))
    @test forward.joint_count == 2
    @test EclatMining.rule_support(forward) == 1 // 2
    @test EclatMining.rule_confidence(forward) == 1
    @test EclatMining.rule_lift(forward) == 4 // 3
    @test EclatMining.rule_confidence(backward) == 2 // 3
    @test length(EclatMining.association_rules(itemsets, 4, 7 // 10)) < length(rules)
    @test first(rules, 10) == first(EclatMining.association_rules(reverse(itemsets), 4, 2 // 3), 10)
    @test isempty(EclatMining.association_rules(eclat([[1], [2]], 1), 2, 1 // 2))
    tied_rules = EclatMining.association_rules(eclat([[1, 2]], 1), 1, 1 // 1)
    @test [r.antecedent for r in tied_rules] == [(1,), (2,)]
end

