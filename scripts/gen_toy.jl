# Sinh các CSDL nhỏ trong data/toy/ dùng cho unit test (toy.txt có sẵn, không sinh lại).
#   julia --project scripts/gen_toy.jl
# Seed cố định 42. Các file sinh ra được commit, nên test không phụ thuộc việc chạy lại script
# (dãy số ngẫu nhiên của Julia có thể đổi giữa các phiên bản Julia).

using Random
using EclatMining

const TOY_DIR = normpath(joinpath(@__DIR__, "..", "data", "toy"))

function write_lines(name::String, lines::Vector{String})::Nothing
    open(joinpath(TOY_DIR, name), "w") do io
        for line in lines
            print(io, line, '\n')
        end
    end
    println("đã ghi ", name, " (", length(lines), " dòng)")
    return nothing
end

# Mỗi item 1..n_items có mặt trong giao dịch với xác suất p; không sinh giao dịch rỗng.
function random_db(n_tx::Int, n_items::Int, p::Float64)::Vector{String}
    lines = String[]
    while length(lines) < n_tx
        items = [i for i in 1:n_items if rand() < p]
        isempty(items) || push!(lines, join(items, ' '))
    end
    return lines
end

function main()::Nothing
    Random.seed!(42)

    # Giao dịch trùng nhau: mỗi bản sao vẫn được tính vào support.
    write_lines("dup_tx.txt", ["1 2 3", "1 2 3", "1 2 3", "2 4", "2 4", "1 4", "3",
                               "1 2 3 4", "1 2 3 4", "2 3"])

    # File "bẩn": comment @ # %, dòng trống, dòng chỉ có dấu cách, dấu cách thừa,
    # item chưa sort, item trùng trong dòng.
    dirty = ["@ metadata line", "# comment line", "% another comment", "",
             "  3 1 2 2  ", "1   2 3 3 5 ", "", "5 5 5", "2 4 1 4", "   ", "4 2", "3 5 1 ",
             "@ITEM=1=bread", "1 2 3 5"]
    write_lines("dup_items_comments.txt", dirty)

    # Bản đã làm sạch của file trên (qua chính read_spmf) để đối chiếu cách SPMF đọc file bẩn.
    clean = read_spmf(joinpath(TOY_DIR, "dup_items_comments.txt"))
    write_lines("dup_items_comments_clean.txt", [join(t, ' ') for t in clean])

    write_lines("empty.txt", String[])

    write_lines("rand_dense.txt", random_db(60, 12, 0.6))     # dày: ~7 item/giao dịch
    write_lines("rand_sparse.txt", random_db(200, 15, 0.15))  # thưa: ~2 item/giao dịch
    return nothing
end

main()
