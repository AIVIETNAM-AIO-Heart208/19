# Kiểm thử I/O: parser, writer, quy đổi minsup, round-trip, clean_spmf.
# Chạy qua test/runtests.jl (file đó định nghĩa TOY_DIR, EXPECTED_DIR, TOY_40, toy()).

using Test
using EclatMining

@testset "read_spmf" begin
    db = read_spmf(toy("toy.txt"))
    @test db == [[1, 3, 4], [2, 3, 5], [1, 2, 3, 5], [2, 5], [1, 2, 3, 5]]
    @test length(db) == 5

    # Giao dịch trùng nhau phải được giữ nguyên.
    dup = read_spmf(toy("dup_tx.txt"))
    @test length(dup) == 10
    @test count(==([1, 2, 3]), dup) == 3

    # Dòng trống, dòng @ # %, dấu cách thừa, item chưa sort, item trùng trong dòng.
    dirty = read_spmf(toy("dup_items_comments.txt"))
    # Dòng "   " (chỉ có dấu cách) là một giao dịch rỗng, đứng giữa [1, 2, 4] và [2, 4].
    @test dirty == [[1, 2, 3], [1, 2, 3, 5], [5], [1, 2, 4], Int[], [2, 4], [1, 3, 5], [1, 2, 3, 5]]
    # Bỏ giao dịch rỗng thì ra đúng bản _clean (7 giao dịch, không có dòng chỉ có dấu cách).
    @test filter(!isempty, dirty) == read_spmf(toy("dup_items_comments_clean.txt"))

    @test isempty(read_spmf(toy("empty.txt")))

    # Đọc từ IOBuffer: CRLF, BOM, tab, thiếu newline cuối file.
    io = IOBuffer("﻿3 1\r\n\r\n#x\r\n2\t2  1")
    @test EclatMining.read_transactions(io) == [[1, 3], [1, 2]]

    @test_throws ArgumentError EclatMining.read_transactions(IOBuffer("1 a 3\n"))
    @test_throws ArgumentError EclatMining.read_transactions(IOBuffer("1 -2 3\n"))

    @test (@inferred read_spmf(toy("toy.txt"))) isa Vector{Vector{Int}}

    # Dòng chỉ có khoảng trắng = một giao dịch rỗng (giống SPMF); dòng trống hẳn thì bỏ.
    @testset "dòng chỉ có khoảng trắng" begin
        text = "1 2\n1 2\n1\n\n   \n\t\n1 2\n"
        db = EclatMining.read_transactions(IOBuffer(text))
        @test db == [[1, 2], [1, 2], [1], Int[], Int[], [1, 2]]     # "   " và "\t" tính, "" không tính
        without = EclatMining.read_transactions(IOBuffer("1 2\n1 2\n1\n\n1 2\n"))
        @test length(db) == length(without) + 2                     # |DB| tăng đúng số dòng khoảng trắng

        # Ngưỡng tuyệt đối đổi theo |DB|: 70% × 4 = 2,8 -> 3 nhưng 70% × 5 = 3,5 -> 4.
        one_ws = EclatMining.read_transactions(IOBuffer("1 2\n1 2\n1\n   \n1 2\n"))
        four = EclatMining.read_transactions(IOBuffer("1 2\n1 2\n1\n1 2\n"))
        @test (length(four), length(one_ws)) == (4, 5)
        @test minsup_abs(parse_minsup("70%"), length(four)) == 3
        @test minsup_abs(parse_minsup("70%"), length(one_ws)) == 4
        @test Dict(eclat(four, 3)) == Dict([1] => 4, [2] => 3, [1, 2] => 3)
        @test Dict(eclat(one_ws, 4)) == Dict([1] => 4)              # item 2 (support 3) rớt vì ngưỡng tăng

        # Giao dịch rỗng không được làm thay đổi support của itemset nào.
        @test Dict(eclat(one_ws, 1)) == Dict(eclat(four, 1))
    end
end

@testset "parse_minsup / minsup_abs" begin
    @test parse_minsup("40%") == 2 // 5
    @test parse_minsup("0.4") == 2 // 5
    @test parse_minsup(" .5 ") == 1 // 2
    @test parse_minsup("1") == 1
    @test parse_minsup("1.0") == 1
    @test parse_minsup("100%") == 1
    @test parse_minsup("0.5%") == 1 // 200

    @test minsup_abs(parse_minsup("40%"), 5) == 2     # 2.0 đúng số nguyên
    @test minsup_abs(parse_minsup("0.4"), 5) == 2
    @test minsup_abs(parse_minsup("21%"), 5) == 2     # 1.05 -> 2
    @test minsup_abs(parse_minsup("39%"), 5) == 2     # 1.95 -> 2
    @test minsup_abs(parse_minsup("7%"), 100) == 7    # bẫy float: ceil(0.07*100) == 8
    @test ceil(Int, 0.07 * 100) == 8                  # chứng minh cái bẫy là có thật
    @test minsup_abs(parse_minsup("100%"), 5) == 5
    @test minsup_abs(parse_minsup("100%"), 88162) == 88162
    @test minsup_abs(parse_minsup("0.1%"), 5) == 1    # minsup rất nhỏ vẫn ≥ 1
    @test minsup_abs(parse_minsup("40%"), 0) == 0     # CSDL rỗng
    @test minsup_abs("40%", 5) == 2                   # phiên bản nhận thẳng chuỗi
    @test minsup_abs(parse_minsup(".999999999999999"), 10000) == 10000   # numerator*n > typemax(Int64)

    for bad in ("0", "0%", "0.0", "1.01", "101%", "-0.4", "abc", "", "%", ".", "4e-1", "40 %%")
        @test_throws ArgumentError parse_minsup(bad)
    end

    @test (@inferred parse_minsup("40%")) isa Rational{Int}
    @test (@inferred minsup_abs(2 // 5, 5)) isa Int
end

@testset "write_spmf / read_spmf_output" begin
    mktempdir() do dir
        path = joinpath(dir, "out.txt")

        # Định dạng từng dòng; itemset chưa sort phải được ghi tăng dần.
        @test write_spmf(path, [[3, 1] => 2, [2] => 4]) == 2
        @test readlines(path) == ["2 #SUP: 4", "1 3 #SUP: 2"]

        # Round-trip từ Vector các Pair.
        result = eclat(read_spmf(toy("toy.txt")), 2)
        write_spmf(path, result)
        @test read_spmf_output(path) == TOY_40
        @test length(readlines(path)) == 15

        # Round-trip từ Dict.
        write_spmf(path, TOY_40)
        @test read_spmf_output(path) == TOY_40

        # Kết quả rỗng.
        @test write_spmf(path, Pair{Vector{Int},Int}[]) == 0
        @test isempty(read_spmf_output(path))
    end

    # Output thật của SPMF có 2 dòng header bắt đầu bằng @.
    spmf = read_spmf_output(joinpath(EXPECTED_DIR, "toy_40.txt"))
    @test spmf == TOY_40

    @test_throws ArgumentError EclatMining.read_itemsets(IOBuffer("1 2 3\n"))
    @test_throws ArgumentError EclatMining.read_itemsets(IOBuffer("1 2 #SUP: x\n"))
    @test_throws ArgumentError EclatMining.read_itemsets(IOBuffer("1 2 #SUP: 2\n2 1 #SUP: 2\n"))
    @test (@inferred read_spmf_output(joinpath(EXPECTED_DIR, "toy_40.txt"))) isa Dict{Vector{Int},Int}
end

@testset "clean_spmf" begin
    dirty_path = toy("dup_items_comments.txt")
    mktempdir() do dir
        out = joinpath(dir, "cleaned.txt")
        n = clean_spmf(dirty_path, out)

        # Không đổi số giao dịch và nội dung: đọc lại bản sạch ra đúng CSDL của file bẩn.
        @test n == 8
        @test read_spmf(out) == read_spmf(dirty_path)
        @test length(read_spmf(out)) == length(read_spmf(dirty_path))

        # Fixture đã commit (đã chạy qua SPMF thật) đúng là output của clean_spmf.
        @test readlines(out) == readlines(toy("dup_items_comments_cleaned.txt"))   # readlines: không phụ thuộc CRLF khi checkout

        # Dạng sạch: một dấu cách giữa các item, không dấu cách đầu/cuối, riêng giao dịch rỗng là một dấu cách.
        lines = readlines(out)
        @test lines == ["1 2 3", "1 2 3 5", "5", "1 2 4", " ", "2 4", "1 3 5", "1 2 3 5"]

        # Idempotent.
        out2 = joinpath(dir, "cleaned2.txt")
        @test clean_spmf(out, out2) == n
        @test readlines(out2) == readlines(out)

        # CRLF, BOM, dòng comment, dòng trống, dòng khoảng trắng.
        crlf = joinpath(dir, "crlf.txt")
        write(crlf, "﻿@x\r\n 2  1 1 \r\n\r\n\t \r\n# c\r\n3")
        @test clean_spmf(crlf, out) == 3
        @test read(out, String) == "1 2\n \n3\n"

        # File rỗng cho ra file rỗng; item sai báo lỗi; không ghi đè chính file input.
        write(crlf, "")
        @test clean_spmf(crlf, out) == 0
        @test filesize(out) == 0
        write(crlf, "1 x\n")
        @test_throws ArgumentError clean_spmf(crlf, out)
        @test_throws ArgumentError clean_spmf(crlf, crlf)
    end
end

# CLI: include script vào module riêng để gọi main(args) ngay trong tiến trình test, không đụng tên trong Main.
# Khối `if abspath(PROGRAM_FILE) == @__FILE__` cuối script không chạy khi include.
module CLI
include(joinpath(@__DIR__, "..", "scripts", "run_eclat.jl"))
end

@testset "CLI: từ chối --input và --output cùng một file" begin
    run_cli(input, output) = redirect_stdio(stdout=devnull, stderr=devnull) do
        CLI.main(["--input", input, "--output", output, "--minsup", "40%"])
    end
    mktempdir() do dir
        cd(dir) do
            original = read(toy("toy.txt"))
            write("x.txt", original)

            # Cùng file, khác dạng đường dẫn: đều phải exit ≠ 0, input giữ nguyên, không tạo file nào.
            pairs = [("x.txt", "x.txt"), ("x.txt", "./x.txt"), ("./x.txt", "x.txt"),
                     ("x.txt", joinpath(dir, "x.txt")), ("x.txt", joinpath("sub", "..", "x.txt"))]
            Sys.iswindows() && append!(pairs, [("x.txt", "X.TXT"), ("X.txt", "x.TXT")])
            @testset "$inp vs $out" for (inp, out) in pairs
                @test run_cli(inp, out) != 0
                @test read("x.txt") == original
                @test readdir(dir) == ["x.txt"]
            end

            # Symlink: dạng chữ khác hẳn, chỉ samefile bắt được. Windows cần quyền tạo symlink nên có thể bỏ qua.
            linked = try
                symlink(joinpath(dir, "x.txt"), "link.txt"); true
            catch err
                err isa Base.IOError || rethrow(); false
            end
            if linked
                @test CLI.same_file("x.txt", "link.txt")
                @test run_cli("x.txt", "link.txt") != 0
                @test read("x.txt") == original
                rm("link.txt")
            else
                @test_skip run_cli("x.txt", "link.txt") != 0
            end

            # Đối chứng: output là file khác thì chạy bình thường, input vẫn nguyên.
            @test !CLI.same_file("x.txt", "y.txt")
            @test run_cli("x.txt", "y.txt") == 0
            @test read_spmf_output("y.txt") == TOY_40
            @test read("x.txt") == original
        end
    end
end

@testset "clean_spmf preserves aliased input" begin
    mktempdir() do dir
        cd(dir) do
            original = "2 1\n1 3\n"
            write("db.txt", original)
            aliases = ["db.txt", "./db.txt", joinpath(dir, "db.txt")]
            Sys.iswindows() && push!(aliases, "DB.TXT")
            for alias in aliases
                @test_throws ArgumentError clean_spmf("db.txt", alias)
                @test read("db.txt", String) == original
            end
            hardlink("db.txt", "hard.txt")
            @test_throws ArgumentError clean_spmf("db.txt", "hard.txt")
            @test read("db.txt", String) == original
            @test read("hard.txt", String) == original
            # Same helper protects the CLI, including hard links.
            @test CLI.same_file("db.txt", "hard.txt")
            @test clean_spmf("db.txt", "clean.txt") == 2
            @test read("clean.txt", String) == "1 2\n1 3\n"
            @test read("db.txt", String) == original
            # Windows may deny symlink creation; the existing CLI test reports that skip.
            linked = try
                symlink(joinpath(dir, "db.txt"), "sym.txt")
                true
            catch err
                err isa Base.IOError || rethrow()
                false
            end
            if linked
                @test_throws ArgumentError clean_spmf("db.txt", "sym.txt")
                @test read("db.txt", String) == original
            end
        end
    end
end
