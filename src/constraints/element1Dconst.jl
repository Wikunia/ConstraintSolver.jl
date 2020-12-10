function init_constraint_struct(::Type{Element1DConstInner}, internals)
    Element1DConstConstraint(
        internals,
        Int[], # zSupp will be filled later
    )
end

"""
    init_constraint!(com::CS.CoM, constraint::Element1DConstConstraint, fct::MOI.VectorOfVariables, set::Element1DConstInner;
                     active = true)

Initialize the Element1DConstConstraint by initializing zSupp
"""
function init_constraint!(
    com::CS.CoM,
    constraint::Element1DConstConstraint,
    fct::MOI.VectorOfVariables,
    set::Element1DConstInner;
    active = true,
)
    # Assume z == T[y]
    pvals = constraint.pvals

    z = com.search_space[constraint.indices[1]]
    y = com.search_space[constraint.indices[2]]
    num_vals = z.upper_bound - z.lower_bound + 1
    constraint.zSupp = zeros(Int, num_vals)

    # Remove values of y which are out of bounds
    # Assume normal indexing
    !remove_below!(com, y, 1) && return false
    !remove_above!(com, y, length(set.array)) && return false

    # initial filtering
    zSupp = constraint.zSupp
    T = set.array
    # for each value v in values(z):
    for val in CS.values(z)
        # zSupp(v) = |{i in D(y): T[i]=z}| 
        val_shifted = val - z.lower_bound + 1
        # Filter: zSupp(v) = 0 => remove v from D(z)
        zSupp[val] = count(y_val->T[y_val] == val, CS.values(y))
        if zSupp[val] == 0
            !rm!(com, z, val) && return false
        end
    end
    return true
end

"""
    prune_constraint!(com::CS.CoM, constraint::Element1DConstConstraint, fct::MOI.VectorOfVariables, set::Element1DConstInner; logs = true)

Reduce the number of possibilities given the `Element1DConstConstraint`.
Return whether still feasible
"""
function prune_constraint!(
    com::CS.CoM,
    constraint::Element1DConstConstraint,
    fct::MOI.VectorOfVariables,
    set::Element1DConstInner;
    logs = true,
)
    # Assume z == T[y]
    z = com.search_space[constraint.indices[1]]
    y = com.search_space[constraint.indices[2]]
    zSupp = constraint.zSupp
    T = set.array
    # for each value v in values(z):
    for val in CS.values(z)
        # zSupp(v) = |{i in D(y): T[i]=z}| 
        val_shifted = val - z.lower_bound + 1
        # Filter: zSupp(v) = 0 => remove v from D(z)
        zSupp[val] = count(y_val->T[y_val] == val, CS.values(y))
        if zSupp[val] == 0
            !rm!(com, z, val) && return false
        end
    end

    return true
end


"""
    still_feasible(com::CoM, constraint::Element1DConstConstraint, fct::MOI.VectorOfVariables, set::Element1DConstInner, vidx::Int, value::Int)

Return whether the constraint can be still fulfilled when setting a variable with index `vidx` to `value`.
**Attention:** This assumes that it isn't violated before.
"""
function still_feasible(
    com::CoM,
    constraint::Element1DConstConstraint, 
    fct::MOI.VectorOfVariables, 
    set::Element1DConstInner,
    vidx::Int,
    value::Int,
)
    # Assume z == T[y]
    z_vidx = constraint.indices[1]
    y_vidx = constraint.indices[2]
    z = com.search_space[z_vidx]
    y = com.search_space[y_vidx]    
    T = set.array

    if vidx == z_vidx
        return any(y_val->T[y_val] == value, CS.values(y))
    elseif vidx == y_vidx
        return has(z, T[value])
    end
    return true
end