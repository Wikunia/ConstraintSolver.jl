function init_constraint!(
    com::CS.CoM,
    constraint::ReifiedConstraint,
    fct::Union{MOI.VectorOfVariables, VAF{T}},
    set::RS
) where {A, T<:Real, RS<:ReifiedSet{A}}
    inner_constraint = constraint.inner_constraint
    if hasmethod(	
        init_constraint!,	
        (CS.CoM, typeof(inner_constraint), typeof(inner_constraint.std.fct), typeof(inner_constraint.std.set)),	
    )	
        return init_constraint!(com, inner_constraint, inner_constraint.std.fct, inner_constraint.std.set)
    end
    # still feasible
    return true
end

function prune_constraint!(
    com::CS.CoM,
    constraint::ReifiedConstraint,
    fct::Union{MOI.VectorOfVariables, VAF{T}},
    set::RS;
    logs = true
) where {A, T<:Real, RS<:ReifiedSet{A}}
    # 1. if the inner constraint is solved then the reified variable can be set to activate_on
    # 2. if the reified constraint is active then prune can be called for the inner constraint
    # 3. if the reified constraint is fixed to inactive one would need to "anti" prune which is currently not possible
    
    variables = com.search_space
    rei_ind = constraint.std.indices[1]
    inner_constraint = constraint.inner_constraint
    activate_on = Int(constraint.activate_on)

    # 1
    if is_solved_constraint(com, inner_constraint, inner_constraint.std.fct, inner_constraint.std.set)
        !fix!(com, variables[rei_ind], activate_on) && return false
    #2
    elseif issetto(variables[rei_ind], activate_on)
        return prune_constraint!(com, inner_constraint, inner_constraint.std.fct, inner_constraint.std.set)
    end
    return true
end

function still_feasible(
    com::CS.CoM,
    constraint::ReifiedConstraint,
    fct::Union{MOI.VectorOfVariables, VAF{T}},
    set::RS,
    val::Int,
    index::Int
) where {A, T<:Real, RS<:ReifiedSet{A}}
    inner_constraint = constraint.inner_constraint
    variables = com.search_space
    activate_on = Int(constraint.activate_on)
    rei_ind = constraint.std.indices[1]
    if (index == rei_ind && val == activate_on) || issetto(variables[rei_ind], activate_on)
        return still_feasible(com, inner_constraint, inner_constraint.std.fct, inner_constraint.std.set, val, index)
    end
    return true
end

function is_solved_constraint(
    constraint::ReifiedConstraint,
    fct::Union{MOI.VectorOfVariables, VAF{T}},
    set::RS,
    values::Vector{Int}
) where {A, T<:Real, RS<:ReifiedSet{A}}
    activate_on = Int(constraint.activate_on)
    inner_constraint = constraint.inner_constraint
    return is_solved_constraint(inner_constraint, inner_constraint.std.fct, inner_constraint.std.set, values[2:end]) == (values[1] == activate_on)
end