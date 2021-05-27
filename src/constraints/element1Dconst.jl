function init_constraint_struct(::Element1DConstInner, internals)
    Element1DConstConstraint(
        internals,
        Int[], # zSupp will be filled later
        Variable(0), 
        Variable(0),
        1,
        1
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
)
    # Assume z == T[y]
    z = com.search_space[constraint.indices[1]]
    y = com.search_space[constraint.indices[2]]

    constraint.z = z
    constraint.y = y

    num_vals = z.upper_bound - z.lower_bound + 1
    constraint.zSupp = zeros(Int, num_vals)
    T = set.array

   return true
end

function activate_constraint!(
    com::CS.CoM,
    constraint::Element1DConstConstraint,
    fct::MOI.VectorOfVariables,
    set::Element1DConstInner;
)
    # Assume z == T[y]
    pvals = constraint.pvals

    y = constraint.y
    z = constraint.z
    T = set.array

    # Remove values of y which are out of bounds
    # Normal indexing
    !remove_below!(com, y, 1) && return false
    !remove_above!(com, y, length(set.array)) && return false

    # initial filtering for y
    for val in CS.values(y)
        if !(has(z, T[val]))
            !rm!(com, y, val) && return false
        end
    end

    # initial filtering for z
    zSupp = constraint.zSupp
    calculate_zSupp!(constraint, set)
    # for each value v in values(z):
    for val in CS.values(z)
        val_shifted = val - z.lower_bound + 1
        if zSupp[val_shifted] == 0
            !rm!(com, z, val) && return false
        end
    end
    return true
end

function is_constraint_solved(
    constraint::Element1DConstConstraint,
    fct::MOI.VectorOfVariables,
    set::Element1DConstInner,
    values::Vector{Int},
)
    T = set.array
    return T[values[2]] == values[1]
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
    z = constraint.z
    y = constraint.y
    zSupp = constraint.zSupp
    T = set.array
    
    # change in z 
    step_nr = com.c_step_nr
    current_z_changes = view_changes(z, step_nr)
    for change_ptr in constraint.z_changes_ptr:length(current_z_changes)
        change = current_z_changes[change_ptr]
        change_type = change[1]
        change_val = change[2]
        if change_type == :fix
            for y_val in CS.values(y)
                if T[y_val] != change_val
                    !rm!(com, y, y_val) && return false
                end
            end
        elseif change_type == :rm
            for y_val in CS.values(y)
                if T[y_val] == change_val
                    !rm!(com, y, y_val) && return false
                end
            end
        elseif change_type == :remove_above
            for y_val in CS.values(y)
                if T[y_val] > change_val
                    !rm!(com, y, y_val) && return false
                end
            end
        elseif change_type == :remove_below
            for y_val in CS.values(y)
                if T[y_val] < change_val
                    !rm!(com, y, y_val) && return false
                end
            end
        end
    end
    constraint.z_changes_ptr = length(current_z_changes) + 1

    # change in y
    current_y_changes = view_changes(y, step_nr)
    for change_ptr in constraint.y_changes_ptr:length(current_y_changes)
        change = current_y_changes[change_ptr]
        change_type = change[1]
        change_val = change[2]
        if change_type == :fix
            !fix!(com, z, T[change_val]) && return false
        elseif change_type == :rm 
            if 1 <= T[change_val] - z.lower_bound + 1 <= length(T)
                zSupp[T[change_val] - z.lower_bound + 1] -= 1
            end
        elseif change_type == :remove_above
            for val in change_val+1:length(T)
                T_val_shifted = T[val] - z.lower_bound + 1
                zSupp[T_val_shifted] > 0 && (zSupp[T_val_shifted] -= 1)
            end
        elseif change_type == :remove_below
            for val in 1:min(change_val-1, length(T))
                T_val_shifted = T[val] - z.lower_bound + 1
                zSupp[T_val_shifted] > 0 && (zSupp[T_val_shifted] -= 1)
            end
        end
    end
    constraint.y_changes_ptr = length(current_y_changes) + 1

    # remove z values val where zSupp[val] == 0
    for z_val in CS.values(z)
        if zSupp[z_val - z.lower_bound + 1] == 0
            !rm!(com, z, z_val) && return false
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
        # constraint doesn't have to be activated => check if y_val is a possible index
        return any(y_val->checkbounds(Bool, T, y_val) && T[y_val] == value, CS.values(y))
    elseif vidx == y_vidx
        return has(z, T[value])
    end
    return true
end

function is_constraint_violated(  
    com::CoM,
    constraint::Element1DConstConstraint, 
    fct::MOI.VectorOfVariables, 
    set::Element1DConstInner
)
    # Assume z == T[y]
    z_vidx = constraint.indices[1]
    y_vidx = constraint.indices[2]
    z = com.search_space[z_vidx]
    y = com.search_space[y_vidx]    
    T = set.array
    if isfixed(y)
        val = T[CS.value(y)]
        return !has(z, val)
    end
    if isfixed(z)
        vals = T[CS.values(y)]
        zval = CS.value(z)
        return !(zval in vals)
    end
    return false
end

function finished_pruning_constraint!(
    com::CS.CoM,
    constraint::Element1DConstConstraint,
    fct::MOI.VectorOfVariables,
    set::Element1DConstInner,
)
    constraint.z_changes_ptr = 1
    constraint.y_changes_ptr = 1
end

"""
    reverse_pruning_constraint!(
        com::CoM,
        constraint::Element1DConstConstraint,
        fct::MOI.VectorOfVariables,
        set::Element1DConstInner,
    )

Is called after `single_reverse_pruning_constraint!`.
"""
function reverse_pruning_constraint!(
    com::CoM,
    constraint::Element1DConstConstraint,
    fct::MOI.VectorOfVariables,
    set::Element1DConstInner,
    backtrack_id::Int,
)
    calculate_zSupp!(constraint, set)
end

function calculate_zSupp!(constraint, set)
    # initial filtering for z
    zSupp = constraint.zSupp
    z = constraint.z
    y = constraint.y
    T = set.array

    # for each value v in values(z):
    for val in CS.values(z)
        # zSupp(v) = |{i in D(y): T[i]=z}| 
        val_shifted = val - z.lower_bound + 1
        # Filter: zSupp(v) = 0 => remove v from D(z)
        zSupp[val_shifted] = count(y_val->T[y_val] == val, CS.values(y))
    end
end