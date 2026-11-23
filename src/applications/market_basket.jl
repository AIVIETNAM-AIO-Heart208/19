"""Convert invoice lines to sorted item-ID baskets, retaining invoice and item labels."""
function market_baskets(rows; excluded_codes=())
    raw_invoices, raw_codes = Set{String}(), Set{String}()
    baskets = Dict{String,Set{String}}()
    descriptions = Dict{String,String}()
    removed_codes = Dict{String,Int}()
    raw_rows = 0
    eligible_rows = 0
    example = NamedTuple[]
    for row in rows
        invoice, code = strip(row.invoice), strip(row.code)
        raw_rows += 1
        isempty(invoice) || push!(raw_invoices, invoice)
        isempty(code) || push!(raw_codes, code)
        invoice == "536365" && push!(example, row)
        (isempty(invoice) || isempty(code) || startswith(uppercase(invoice), "C")) && continue
        (row.quantity === nothing || !(isfinite(row.quantity) && row.quantity > 0)) && continue
        (row.price === nothing || !(isfinite(row.price) && row.price > 0)) && continue
        eligible_rows += 1
        push!(get!(Set{String}, baskets, invoice), code)
        name = strip(row.description)
        # Pick the first nonempty description in source order for a stable display label.
        isempty(name) || get!(descriptions, code, name)
        if code in excluded_codes
            removed_codes[code] = get(removed_codes, code, 0) + 1
        end
    end
    eligible_baskets = length(baskets)
    eligible_codes = Set(code for items in values(baskets) for code in items)
    for items in values(baskets)
        setdiff!(items, excluded_codes)
    end
    filter!(entry -> !isempty(last(entry)), baskets)
    invoices = sort!(collect(keys(baskets)))
    codes = sort!(collect(setdiff!(eligible_codes, excluded_codes)))
    ids = Dict(code => id for (id, code) in enumerate(codes))
    db = [sort!([ids[code] for code in baskets[invoice]]) for invoice in invoices]
    names = [get(descriptions, code, code) for code in codes]
    stats = (; raw_rows, raw_invoices=length(raw_invoices), raw_codes=length(raw_codes),
             eligible_rows, eligible_baskets, eligible_codes=length(codes) + length(removed_codes),
             removed_codes)
    return (; db, invoices, codes, names, example, stats)
end

