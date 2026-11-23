using EclatMining
using Downloads, SHA, XLSX, ZipFile

const RETAIL_WORKBOOK = joinpath(dirname(@__DIR__), "data", "raw", "uci_online_retail", "Online Retail.xlsx")
const RETAIL_URL = "https://archive.ics.uci.edu/static/public/352/online+retail.zip"
const WORKBOOK_SHA256 = "43465a06f2ccf7c8b5bd2892bc7defb52f97487934fe93b16ae4c3936424676d"

function verify_workbook(path)
    bytes2hex(open(sha256, path)) == WORKBOOK_SHA256 ||
        throw(ArgumentError("SHA-256 mismatch for $path. Expected the original UCI workbook."))
end

function prepare_workbook(path; download_if_missing=false)
    if isfile(path)
        verify_workbook(path)
        return path
    end
    download_if_missing || throw(ArgumentError("Workbook not found: $path"))
    mkpath(dirname(abspath(path)))
    mktempdir(dirname(abspath(path))) do dir
        archive = Downloads.download(RETAIL_URL, joinpath(dir, "retail.zip"))
        candidate = joinpath(dir, "Online Retail.xlsx")
        reader = ZipFile.Reader(archive)
        try
            entry = only(filter(f -> f.name == "Online Retail.xlsx", reader.files))
            write(candidate, read(entry))
        finally
            close(reader)
        end
        verify_workbook(candidate)
        mv(candidate, path)
    end
    return path
end

const EXCLUDED_CODES = ("POST", "DOT", "C2", "BANK CHARGES", "AMAZONFEE", "M", "m", "B")

function invoice_row(line, line_number)
    fields = split(line, '\t'; keepempty=true)
    length(fields) == 5 ||
        throw(ArgumentError("TSV line $line_number: expected 5 columns, found $(length(fields))"))
    invoice, code, description, quantity, price = fields
    return (; invoice=String(invoice), code=String(code), description=String(description),
             quantity=tryparse(Float64, quantity), price=tryparse(Float64, price))
end

cell_text(value) = ismissing(value) ? "" : string(value)
cell_text(value::AbstractFloat) = isinteger(value) ? string(Int(value)) : string(value)
cell_number(value) = ismissing(value) ? nothing : tryparse(Float64, string(value))
cell_number(value::Real) = Float64(value)

function workbook_baskets(path)
    XLSX.openxlsx(path; enable_cache=false) do book
        rows = Iterators.Stateful(XLSX.eachrow(book[1]))
        header = popfirst!(rows)
        columns = (1, 2, 3, 4, 6)
        map(i -> header[i], columns) == ("InvoiceNo", "StockCode", "Description", "Quantity", "UnitPrice") ||
            throw(ArgumentError("Unexpected Online Retail worksheet header"))
        lines = ((invoice=cell_text(row[1]), code=cell_text(row[2]),
                  description=cell_text(row[3]), quantity=cell_number(row[4]),
                  price=cell_number(row[6])) for row in rows)
        EclatMining.market_baskets(lines; excluded_codes=EXCLUDED_CODES)
    end
end

function market_basket_report(io, data, itemsets, rules, minsup, minconf, threshold)
    stats = data.stats
    baskets = length(data.db)
    println(io, "# Luật kết hợp trên UCI Online Retail\n")
    println(io, "Minsup **$minsup** ($threshold giỏ), minconf **$minconf**.\n")
    println(io, "| Bước | Dòng hàng | Hóa đơn | Mã hàng |")
    println(io, "|---|---:|---:|---:|")
    println(io, "| Dữ liệu nguồn | $(stats.raw_rows) | $(stats.raw_invoices) | $(stats.raw_codes) |")
    println(io, "| Sau khi lọc hóa đơn hủy, mã thiếu, số lượng và đơn giá | $(stats.eligible_rows) | $(stats.eligible_baskets) | $(stats.eligible_codes) |")
    println(io, "| Sau khi loại mã phí và điều chỉnh | $(stats.eligible_rows - sum(values(stats.removed_codes); init=0)) | $baskets | $(length(data.codes)) |\n")
    removed = ["`$code`: $count" for (code, count) in sort!(collect(stats.removed_codes); by=first)]
    println(io, "Số dòng loại theo mã phí hoặc điều chỉnh: ", join(removed, ", "), ".\n")
    index = findfirst(==("536365"), data.invoices)
    if index !== nothing
        println(io, "**Hóa đơn 536365.** Dòng gốc (mã × số lượng): ",
                join(["$(row.code) × $(row.quantity)" for row in data.example], ", "), ".")
        println(io, "Giỏ theo thứ tự ID: ", join(data.db[index], ", "), ".")
        println(io, "Mã tương ứng: ", join(data.codes[data.db[index]], ", "), ".\n")
    end
    println(io, "**$(length(itemsets))** itemset phổ biến và **$(length(rules))** luật đạt ngưỡng.\n")
    label(items) = join(["$(data.names[i]) [$(data.codes[i])]" for i in items], " + ")
    format_label(items) = replace(label(items), "|" => "\\|")
    println(io, "| Hạng | Vế trái | Vế phải | Giỏ chứa cả hai | Support | Confidence | Lift |")
    println(io, "|---:|---|---|---:|---:|---:|---:|")
    for (rank, rule) in enumerate(Iterators.take(rules, 10))
        # Count each subset directly in the baskets to verify the reported metrics.
        count_baskets(items) = count(basket -> all(item -> item in basket, items), data.db)
        left = count_baskets(rule.antecedent)
        right = count_baskets(rule.consequent)
        joint = count_baskets((rule.antecedent..., rule.consequent...))
        (left, right, joint) == (rule.antecedent_count, rule.consequent_count, rule.joint_count) ||
            error("Direct support count differs for rule $rank")
        pct(value) = string(round(100 * Float64(value); digits=4), "%")
        @assert joint // baskets == EclatMining.rule_support(rule)
        @assert joint // left == EclatMining.rule_confidence(rule)
        @assert (joint // left) / (right // baskets) == EclatMining.rule_lift(rule)
        lift = round(Float64(EclatMining.rule_lift(rule)); digits=4)
        println(io, "| $rank | $(format_label(rule.antecedent)) | $(format_label(rule.consequent)) | $joint | $(pct(joint // baskets)) | $(pct(joint // left)) | $lift |")
    end
end

function main(args)
    length(args) in (3, 4) || error("Usage: run_market_basket.jl [input.xlsx|input.tsv] output.md minsup minconf")
    use_default_workbook = length(args) == 3
    input = use_default_workbook ? RETAIL_WORKBOOK : first(args)
    output, minsup, minconf = args[end-2:end]
    if EclatMining.same_file(input, output) || EclatMining.same_file(RETAIL_WORKBOOK, output)
        throw(ArgumentError("Output must be different from the input file: $output"))
    end
    confidence = EclatMining.parse_minconf(minconf)
    data = if endswith(lowercase(input), ".xlsx")
        workbook_baskets(prepare_workbook(input; download_if_missing=use_default_workbook))
    elseif endswith(lowercase(input), ".tsv")
        open(input) do io
            rows = (invoice_row(line, n) for (n, line) in enumerate(eachline(io)))
            EclatMining.market_baskets(rows; excluded_codes=EXCLUDED_CODES)
        end
    else
        throw(ArgumentError("Expected an XLSX workbook or TSV invoice lines: $input"))
    end
    isempty(data.db) && error("No valid baskets remain after filtering")
    threshold = minsup_abs(minsup, length(data.db))
    itemsets = eclat(data.db, threshold)
    rules = EclatMining.association_rules(itemsets, length(data.db), confidence)
    report = sprint(io -> market_basket_report(io, data, itemsets, rules, minsup, minconf, threshold))
    write(output, report)
end

abspath(PROGRAM_FILE) == (@__FILE__) && main(ARGS)
