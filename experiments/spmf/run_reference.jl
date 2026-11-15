# Sinh output tham chiếu của SPMF (Eclat) cho mọi CSDL trong test/fixtures/transactions/.
#   julia --project experiments/spmf/run_reference.jl [đường dẫn spmf.jar]
# Cần JDK 25+ và tools/spmf.jar (hoặc truyền đường dẫn / đặt biến môi trường SPMF_JAR).
# Chạy được trên Windows lẫn Linux/Colab vì chỉ gọi `java` qua `run`.
# Kết quả: test/fixtures/spmf_expected/<tên>_<minsup%>.txt và test/fixtures/cases.toml.
# Script KHÔNG tự sửa hay tự tạo output: nếu SPMF không sinh được file thì chỉ báo lại.

const ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const IN_DIR = joinpath(ROOT, "test", "fixtures", "transactions")
const OUT_DIR = joinpath(ROOT, "test", "fixtures", "spmf_expected")
const CASES_FILE = joinpath(ROOT, "test", "fixtures", "cases.toml")

# Mức minsup (%) cho từng CSDL. Mặc định 20/40/60; ngoại lệ có lý do:
#   toy: 21% và 39% kiểm tra làm tròn ceil (1,05 -> 2; 1,95 -> 2).
#   rand_sparse: dữ liệu thưa, 20–60% gần như không còn itemset, thêm ngưỡng thấp để test có nội dung.
const DEFAULT_LEVELS = [20, 40, 60]
const LEVELS = Dict{String,Vector{Int}}(
    "toy" => [20, 21, 39, 40, 60],
    "rand_sparse" => [2, 5, 10, 20, 40, 60],
)

# SPMF không đọc được các file này (đã quan sát hộp đen, xem test/fixtures/README.md).
# File bẩn được đối chiếu qua bản đã làm sạch `<tên>_clean.txt`.
const SPMF_REJECTS = Dict{String,String}(
    "empty" => "SPMF từ chối file rỗng",
    "dup_items_comments" => "SPMF crash vì dấu cách đầu dòng, item trùng; dùng bản _clean",
)

# Chạy một lệnh, gộp stdout + stderr; không ném lỗi khi exit code ≠ 0.
function capture(cmd::Cmd)::String
    buf = IOBuffer()
    run(pipeline(ignorestatus(cmd); stdout=buf, stderr=buf))
    return String(take!(buf))
end

function find_jar(args::Vector{String})::String
    jar = !isempty(args) ? args[1] : get(ENV, "SPMF_JAR", joinpath(ROOT, "tools", "spmf.jar"))
    isfile(jar) || error("Không thấy spmf.jar tại $jar (tải về theo experiments/spmf/README.md)")
    return abspath(jar)
end

function main(args::Vector{String})::Int
    jar = find_jar(args)
    java_version = strip(first(split(capture(`java -version`), '\n')))
    mkpath(OUT_DIR)

    cases = NamedTuple{(:input, :minsup, :expected, :n_itemsets),Tuple{String,Int,String,Int}}[]
    failed = 0
    for file in sort(filter(f -> endswith(f, ".txt"), readdir(IN_DIR)))
        name = file[1:end-4]
        if haskey(SPMF_REJECTS, name)
            println("BỎ QUA ", rpad(file, 34), SPMF_REJECTS[name])
            continue
        end
        for p in get(LEVELS, name, DEFAULT_LEVELS)
            out = joinpath(OUT_DIR, "$(name)_$(p).txt")
            rm(out; force=true)
            log = capture(Cmd(["java", "-jar", jar, "run", "Eclat", joinpath(IN_DIR, file), out, "$p%"]))
            # SPMF chỉ in dòng thống kê này khi chạy xong; khi lỗi nó có thể để lại file output rỗng.
            if isfile(out) && occursin("Frequent itemsets count", log)
                n = count(l -> occursin("#SUP:", l), eachline(out))
                push!(cases, (input=file, minsup=p, expected="$(name)_$(p).txt", n_itemsets=n))
                println("OK    ", rpad(file, 34), lpad(p, 3), "%  ", lpad(n, 6), " itemset")
            else
                failed += 1
                rm(out; force=true)
                msg = join(filter(l -> occursin(r"ERROR MESSAGE|empty", l), split(log, '\n')), ' ')
                println("FAIL  ", rpad(file, 34), lpad(p, 3), "%  SPMF không chạy được: ", strip(msg))
            end
        end
    end

    # cases.toml xác định (không có timestamp) để `git diff` chỉ đổi khi kết quả đổi.
    open(CASES_FILE, "w") do io
        println(io, "# Các test case đối chiếu SPMF. File này do experiments/spmf/run_reference.jl ghi, không sửa tay.")
        println(io, "[spmf]")
        println(io, "algorithm = \"Eclat\"")
        println(io, "version = \"2.65\"")
        println(io, "java = \"", replace(java_version, '"' => '\''), "\"")
        println(io, "command = \"java -jar tools/spmf.jar run Eclat <input> <expected> <minsup>%\"")
        for c in cases
            println(io, "\n[[case]]")
            println(io, "input = \"transactions/", c.input, "\"")
            println(io, "minsup_percent = ", c.minsup)
            println(io, "expected = \"spmf_expected/", c.expected, "\"")
            println(io, "n_itemsets = ", c.n_itemsets)
        end
    end
    println("Đã sinh ", length(cases), " file expected; SPMF không chạy được: ", failed)
    return failed
end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(main(ARGS))
end
