@inline nvalues(v::CS.Variable) = v.last_ptr - v.first_ptr + 1


"""
    value(v::CS.Variable)

Get the value of the variable if it is fixed. Otherwise one of the possible values is returned.
Can be used if the status is :Solved as then all variables are fixed.
"""
@inline value(v::CS.Variable) = v.values[v.last_ptr]

@inline values(v::CS.Variable) = v.values[(v.first_ptr):(v.last_ptr)]

"""
    values(m::Model, v::VariableRef)

Return all possible values for the variable. (Only one if solved to optimality)
"""
function values(m::Model, v::VariableRef)
    com = CS.get_inner_model(m)
    return values(com.search_space[v.index.value])
end

@inline view_values(v::CS.Variable) = @views v.values[(v.first_ptr):(v.last_ptr)]

"""
    view_removed_values(v::CS.Variable)

Return a view of all removed values
"""
@inline view_removed_values(v::CS.Variable) = @views v.values[(v.last_ptr + 1):end]

function num_removed(var::CS.Variable)
    return length(var.values) - var.last_ptr
end

function issetto(v::CS.Variable, x::Int)
    if !isfixed(v)
        return false
    else
        return x == value(v)
    end
end

function has(v::CS.Variable, x::Int)
    if x > v.max || x < v.min
        return false
    end
    vidx = v.indices[x + v.offset]
    return v.first_ptr <= vidx <= v.last_ptr
end

function rm!(
    com::CS.CoM,
    v::CS.Variable,
    x::Int;
    in_remove_several = false,
    changes = true,
    check_feasibility = true,
)
    if !in_remove_several && check_feasibility
        # after removing nothing would be possible
        len_vals = nvalues(v)
        if len_vals == 1
            com.bt_infeasible[v.idx] += 1
            return false
        elseif len_vals == 2
            possible = values(v)
            left_over = possible[1] == x ? possible[2] : possible[1]
            if !fulfills_constraints(com, v.idx, left_over)
                com.bt_infeasible[v.idx] += 1
                return false
            end
        end
    end

    vidx = v.indices[x + v.offset]
    v.indices[x + v.offset], v.indices[v.values[v.last_ptr] + v.offset] =
        v.indices[v.values[v.last_ptr] + v.offset], v.indices[x + v.offset]
    v.values[vidx], v.values[v.last_ptr] = v.values[v.last_ptr], v.values[vidx]
    v.last_ptr -= 1
    if !in_remove_several
        vals = view_values(v)
        if CS.nvalues(v) > 0
            if x == v.min
                v.min = minimum(vals)
            end
            if x == v.max
                v.max = maximum(vals)
            end
        end
        changes && push!(v.changes[com.c_backtrack_idx], (:rm, x, 0, 1))
    end
    return true
end

function fix!(com::CS.CoM, v::CS.Variable, x::Int; changes = true, check_feasibility = true)
    if check_feasibility && !fulfills_constraints(com, v.idx, x)
        com.bt_infeasible[v.idx] += 1
        return false
    end
    !has(v, x) && return false
    vidx = v.indices[x + v.offset]
    pr_below = vidx - v.first_ptr
    pr_above = v.last_ptr - vidx
    changes && push!(v.changes[com.c_backtrack_idx], (:fix, x, v.last_ptr, 0))
    v.last_ptr = vidx
    v.first_ptr = vidx
    v.min = x
    v.max = x
    return true
end

function isfixed(v::CS.Variable)
    return v.last_ptr == v.first_ptr
end

function remove_below!(
    com::CS.CoM,
    var::CS.Variable,
    val::Int;
    changes = true,
    check_feasibility = true,
)
    vals = values(var)
    still_possible = filter(v -> v >= val, vals)
    if nvalues(var) == length(still_possible)
        return true
    end
    if check_feasibility
        if length(still_possible) == 0
            com.bt_infeasible[var.idx] += 1
            return false
        elseif length(still_possible) == 1
            if !fulfills_constraints(com, var.idx, still_possible[1])
                com.bt_infeasible[var.idx] += 1
                return false
            end
        end
    end

    nremoved = 0
    for v in vals
        if v < val
            rm!(com, var, v; in_remove_several = true)
            nremoved += 1
        end
    end
    if nremoved > 0 && feasible(var)
        var.min = minimum(values(var))
        changes &&
            push!(var.changes[com.c_backtrack_idx], (:remove_below, val, 0, nremoved))
    end
    return true
end

function remove_above!(
    com::CS.CoM,
    var::CS.Variable,
    val::Int;
    changes = true,
    check_feasibility = true,
)
    vals = values(var)
    still_possible = filter(v -> v <= val, vals)
    if nvalues(var) == length(still_possible)
        return true
    end
    if check_feasibility
        if length(still_possible) == 0
            com.bt_infeasible[var.idx] += 1
            return false
        elseif length(still_possible) == 1
            if !fulfills_constraints(com, var.idx, still_possible[1])
                com.bt_infeasible[var.idx] += 1
                return false
            end
        end
    end

    nremoved = 0
    for v in vals
        if v > val
            rm!(com, var, v; in_remove_several = true)
            nremoved += 1
        end
    end
    if nremoved > 0 && feasible(var)
        var.max = maximum(values(var))
        changes &&
            push!(var.changes[com.c_backtrack_idx], (:remove_above, val, 0, nremoved))
    end
    return true
end

function feasible(var::CS.Variable)
    return var.last_ptr >= var.first_ptr
end
