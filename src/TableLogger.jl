mutable struct TableOpenNodes
    value  :: Int
end
mutable struct TableClosedNodes
    value  :: Int
end
mutable struct TableIncumbent{T <: Real}
    value  :: T
end
mutable struct TableBestBound{T <: Real}
    value  :: T
end
mutable struct TableDuration
    value  :: Float64
end

mutable struct TableRow{T <: Real}
    open_nodes      :: TableOpenNodes
    closed_nodes    :: TableClosedNodes
    incumbent       :: TableIncumbent{T}
    best_bound      :: TableBestBound{T}
    duration        :: TableDuration
end

function TableRow(open_nodes::Int, closed_nodes::Int, incumbent::T, best_bound::T, duration::Float64) where T <: Real
    return TableRow(
        TableOpenNodes(open_nodes),
        TableClosedNodes(closed_nodes),
        TableIncumbent(incumbent),
        TableBestBound(best_bound),
        TableDuration(duration)
    )
end

mutable struct TableSetup
    cols                :: Vector{Symbol}
    col_names           :: Vector{String}
    col_widths          :: Vector{Int}
    b_parse             :: Vector{Bool}
    min_diff_duration   :: Float64
end

function TableSetup(cols::Vector{Symbol}, col_names::Vector{String}, col_width::Vector{Int}; min_diff_duration=5.0)
    @assert length(cols) == length(col_names) == length(col_width)
    b_parse = zeros(Bool, length(cols))
    for c=1:length(cols)
        field_type = fieldtype(TableRow, cols[c])
        if hasmethod(CS.parse_table_value, (field_type, Int))
            b_parse[c] = true
        end
    end
    return TableSetup(cols, col_names, col_width, b_parse, min_diff_duration)
end

function parse_table_value(val::Union{TableOpenNodes, TableClosedNodes}, len::Int)
    s_val = string(val.value)
    if length(s_val) > len
        return ">>"
    end
    return s_val
end

function parse_table_value(val::TableDuration, len::Int)
    s_val = fmt("<.2f", val.value)
    if length(s_val) > len
        return ">>"
    end
    return s_val
end

function parse_table_value(val::Union{TableBestBound, TableIncumbent}, len::Int)
    s_val = fmt("<.10f", val.value)
    precision = 2
    s_val_split = split(s_val, ".")
    if length(s_val_split[1]) == 1 && s_val_split[1] == "0" && length(s_val_split) == 2
        while precision < 10
            if s_val_split[2][precision-1] != '0'
                precision -= 1
                break
            end
            precision += 1
        end    
    end

    prec_fmt = FormatSpec("<.$(precision)f")
    s_val = fmt(prec_fmt, val.value)
    while length(s_val) > len && precision >= 0
        precision -= 1
        prec_fmt = FormatSpec("<.$(precision)f")
        s_val = fmt(prec_fmt, val.value)
    end
    if length(s_val) > len
        s_val = ":/"
    end
    return s_val
end


function get_header(table::TableSetup)
    ln = ""
    for c=1:length(table.cols)
        width     = table.col_widths[c]
        col_name  = table.col_names[c]

        padding = width-length(col_name)
        if padding < 2
            padding = 2
            table.col_widths[c] = length(col_name)+2
        end
        ln *= repeat(" ",fld(padding, 2))
        ln *= col_name
        ln *= repeat(" ",cld(padding, 2))
    end
    equals = repeat("=", sum(table.col_widths))
    header = "$ln\n$equals"
    return header
end

function get_row(table::TableSetup, row::TableRow)
    ln = ""
    for c=1:length(table.cols)
        col     = table.cols[c]
        width   = table.col_widths[c]
        val     = getfield(row, col)
        if table.b_parse[c]
            s_val   = parse_table_value(val, width)
        else
            s_val   = string(val.value)
        end
        padding = width-length(s_val)

        ln *= repeat(" ",fld(padding, 2))
        ln *= s_val
        ln *= repeat(" ",cld(padding, 2))
    end
    return ln
end