function TableCol(name::String, type::DataType)
    width = length(name) <= 8 ? 10 : length(name) + 2
    return TableCol(name, type, width)
end

function TableCol(name::String, type::DataType, width::Int)
    return TableCol(Symbol(name), name, type, width)
end

function TableCol(id::Symbol, name::String, type::DataType, width::Int)
    return TableCol(id, name, type, width, :center)
end

function TableCol(id::Symbol, name::String, type::DataType, width::Int, alignment::Symbol)
    width = width <= length(name) + 2 ? length(name) + 2 : width
    return TableCol(
        id,
        name,
        type,
        width,
        alignment,
        hasmethod(format_table_value, (type, Int)),
    )
end

function TableSetup(cols::Vector{TableCol}, diff_criteria::Dict)
    new_row_criteria = hasmethod(is_new_row, (Vector{TableEntry}, Vector{TableEntry}, Dict))
    col_idx = Dict{Symbol,Int}()
    c = 0
    for col in cols
        c += 1
        col_idx[col.id] = c
    end
    return TableSetup(cols, col_idx, new_row_criteria, diff_criteria, Vector{TableEntry}())
end

function TableSetup(cols::Vector{TableCol})
    return TableSetup(cols, Dict{Symbol,Any}())
end

"""
    is_new_row(new::Vector{TableEntry}, before::Vector{TableEntry}, criteria::Dict)

Check whether a new row should be added to the table based on `criteria` and the previous `TableEntry` (`before`)
Return true if a new row should be added and false otherwise.
"""
function is_new_row(new::Vector{TableEntry}, before::Vector{TableEntry}, criteria::Dict)
    if length(before) != length(new)
        return true
    end
    if length(criteria) == 0
        return true
    end
    min_diff_duration = get(criteria, :min_diff_duration, 5.0)
    for (new_entry, old_entry) in zip(new, before)
        if new_entry.col_id == :duration
            if new_entry.value - old_entry.value >= min_diff_duration
                return true
            end
        end
    end
    return false
end

"""
    format_table_value(val::Int, len::Int)

Return the formatted integer value
"""
function format_table_value(val::Int, len::Int)
    s_val = string(val)
    if length(s_val) > len
        return val > 0 ? ">>" : "<<"
    end
    return s_val
end

"""
    format_table_value(val::Float64, len::Int)

Return the formatted float value
"""
function format_table_value(val::Float64, len::Int)
    s_val = fmt("<.10f", val)
    precision = 2
    s_val_split = split(s_val, ".")
    if length(s_val_split[1]) == 1 && s_val_split[1] == "0" && length(s_val_split) == 2
        while precision < 10
            if s_val_split[2][precision - 1] != '0'
                precision -= precision > 2 ? 1 : 0
                break
            end
            precision += 1
        end
    end

    prec_fmt = FormatSpec("<.$(precision)f")
    s_val = fmt(prec_fmt, val)
    while length(s_val) > len && precision > 0
        precision -= 1
        prec_fmt = FormatSpec("<.$(precision)f")
        s_val = fmt(prec_fmt, val)
    end
    if length(s_val) > len
        s_val = val > 0 ? ">>" : "<<"
    end
    return s_val
end

"""
    get_header(table::TableSetup)

Return the header string of the `TableSetup` including `======` as the second line
"""
function get_header(table::TableSetup)
    ln = ""
    sum_width = 0
    for col in table.cols
        width = col.width
        sum_width += width
        padding = width - length(col.name)
        if padding < 2
            padding = 2
            col.width = length(col.name) + 2
        end
        ln *= repeat(" ", fld(padding, 2) + 1)
        ln *= col.name
        ln *= repeat(" ", cld(padding, 2) + 1)
    end
    equals = repeat("=", sum(sum_width) + 2 * length(table.cols))
    header = "$ln\n$equals"
    return header
end

"""
    push_to_table!(table::TableSetup; force=false, kwargs...)

Given the arguments `kwargs` it will be checked whether a new row shell be added if `force` is `false`.
If `force` a new row is added. All values will be formatted in `get_row`
Return `true` if a new line got added
"""
function push_to_table!(table::TableSetup; force = false, kwargs...)
    row = Vector{TableEntry}(undef, length(table.cols))
    for p in kwargs
        col_idx = get(table.col_idx, p.first, 0)
        if col_idx != 0
            row[col_idx] = TableEntry(p.first, p.second)
        end
    end
    if force ||
       !table.new_row_criteria ||
       is_new_row(row, table.last_row, table.diff_criteria)
        println(get_row(table, row))
        table.last_row = row
        return true
    end
    return false
end

"""
    get_row(table::TableSetup, row::Vector{TableEntry})

Return the formatted and padded table row given `row` and a `TableSetup`
"""
function get_row(table::TableSetup, row::Vector{TableEntry})
    ln = ""
    for c in 1:length(table.cols)
        width = table.cols[c].width
        if isassigned(row, c)
            val = row[c].value
            if table.cols[c].b_format && isa(val, table.cols[c].type)
                s_val = format_table_value(val, width)
            else
                s_val = string(val)
            end
        else
            s_val = "-"
        end
        padding = width - length(s_val)

        if table.cols[c].alignment == :center
            ln *= repeat(" ", fld(padding, 2) + 1)
            ln *= s_val
            ln *= repeat(" ", cld(padding, 2) + 1)
        elseif table.cols[c].alignment == :left
            ln *= " "
            ln *= s_val
            ln *= repeat(" ", padding + 1)
        elseif table.cols[c].alignment == :right
            ln *= repeat(" ", padding + 1)
            ln *= s_val
            ln *= " "
        else
            @warn "Only the alignments :left, :right and :center are defined."
        end
    end
    return ln
end
