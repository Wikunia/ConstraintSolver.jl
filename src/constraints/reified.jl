function init_constraint!(
    com::CS.CoM,
    constraint::ReifiedConstraint,
    fct::Union{MOI.VectorOfVariables, VAF{T}},
    set::RS
) where {A, T<:Real, RS<:ReifiedSet{A}}
    inner_constraint = constraint.inner_constraint

    # check which methods that inner constraint supports
    set_impl_functions!(com, inner_constraint)

    if inner_constraint.impl.init
        feasible = init_constraint!(com, inner_constraint, inner_constraint.fct, inner_constraint.set; active=false)
        # map the bounds to the indicator constraint
        constraint.bound_rhs = inner_constraint.bound_rhs
        return feasible
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
    # 2. if the inner constraint is ant-solved (all fixed but don't fulfill) the reified variable can be set to !activate_on
    # 3. if the reified constraint is active then prune can be called for the inner constraint
    # 4. if the reified constraint is fixed to inactive one would need to "anti" prune which is currently not possible

    variables = com.search_space
    rei_vidx = constraint.indices[1]
    inner_constraint = constraint.inner_constraint
    activate_on = Int(constraint.activate_on)

    # 1
    if is_solved_constraint(com, inner_constraint, inner_constraint.fct, inner_constraint.set)
        !fix!(com, variables[rei_vidx], activate_on) && return false
    #2
    elseif issetto(variables[rei_vidx], activate_on)
        return prune_constraint!(com, inner_constraint, inner_constraint.fct, inner_constraint.set)
    # 3
    elseif issetto(variables[rei_vidx], activate_on)
        return prune_constraint!(com, inner_constraint, inner_constraint.fct, inner_constraint.set)
    end
    return true
end

function still_feasible(
    com::CS.CoM,
    constraint::ReifiedConstraint,
    fct::Union{MOI.VectorOfVariables, VAF{T}},
    set::RS,
    vidx::Int,
    val::Int
) where {A, T<:Real, RS<:ReifiedSet{A}}
    inner_constraint = constraint.inner_constraint
    variables = com.search_space
    activate_on = Int(constraint.activate_on)
    rei_vidx = constraint.indices[1]
    # if currently activated check if inner constraint is feasible
    if (vidx == rei_vidx && val == activate_on) || issetto(variables[rei_vidx], activate_on)
        return still_feasible(com, inner_constraint, inner_constraint.fct, inner_constraint.set, vidx, val)
    end
    # if inner constraint is not activated it shouldn't be solved
    if all(i == vidx || isfixed(com.search_space[i]) for i in inner_constraint.indices)
        # if rei_vidx can't be activated:
        if !has(variables[rei_vidx], activate_on)
            values = [i == vidx ? val : value(com.search_space[i]) for i in inner_constraint.indices]
            return !is_solved_constraint(inner_constraint, inner_constraint.fct, inner_constraint.set, values)
        end
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
    return is_solved_constraint(inner_constraint, inner_constraint.fct, inner_constraint.set, values[2:end]) == (values[1] == activate_on)
end

function update_best_bound_constraint!(com::CS.CoM,
    constraint::ReifiedConstraint,
    fct::Union{MOI.VectorOfVariables, VAF{T}},
    set::RS,
    vidx::Int,
    lb::Int,
    ub::Int
) where {A, T<:Real, RS<:ReifiedSet{A}}
    inner_constraint = constraint.inner_constraint
    reified_vidx = constraint.indices[1]
    search_space = com.search_space
    reified_var = search_space[reified_vidx]
    if inner_constraint.impl.update_best_bound
        if CS.issetto(reified_var, Int(constraint.activate_on))
            return update_best_bound_constraint!(com, inner_constraint, inner_constraint.fct, inner_constraint.set, vidx, lb, ub)
        else
            # if not activated (for example in a different subtree) we reset the bounds
            for rhs in constraint.bound_rhs
                rhs.lb = typemin(Int64)
                rhs.ub = typemax(Int64)
            end
        end
    end
    return true
end

function single_reverse_pruning_constraint!(
    com::CoM,
    constraint::ReifiedConstraint,
    fct::Union{MOI.VectorOfVariables, VAF{T}},
    set::RS,
    var::Variable,
    backtrack_idx::Int
) where {A, T<:Real, RS<:ReifiedSet{A}}
    inner_constraint = constraint.inner_constraint
    # the variable must be part of the inner constraint
    if inner_constraint.impl.single_reverse_pruning && (var.idx != constraint.indices[1] || constraint.reified_in_inner)
        single_reverse_pruning_constraint!(com, inner_constraint, inner_constraint.fct, inner_constraint.set, var, backtrack_idx)
    end
end

function reverse_pruning_constraint!(
    com::CoM,
    constraint::ReifiedConstraint,
    fct::Union{MOI.VectorOfVariables, VAF{T}},
    set::RS,
    backtrack_id::Int
) where {A, T<:Real, RS<:ReifiedSet{A}}
    inner_constraint = constraint.inner_constraint
    if inner_constraint.impl.reverse_pruning
        reverse_pruning_constraint!(com, inner_constraint, inner_constraint.fct, inner_constraint.set, backtrack_id)
    end
end

function restore_pruning_constraint!(
    com::CoM,
    constraint::ReifiedConstraint,
    fct::Union{MOI.VectorOfVariables, VAF{T}},
    set::RS,
    prune_steps::Union{Int, Vector{Int}}
) where {A, T<:Real, RS<:ReifiedSet{A}}
    inner_constraint = constraint.inner_constraint
    if inner_constraint.impl.restore_pruning
        restore_pruning_constraint!(com, inner_constraint, inner_constraint.fct, inner_constraint.set, prune_steps)
    end
end

function finished_pruning_constraint!(com::CS.CoM,
    constraint::ReifiedConstraint,
    fct::Union{MOI.VectorOfVariables, VAF{T}},
    set::RS,
) where {A, T<:Real, RS<:ReifiedSet{A}}
    inner_constraint = constraint.inner_constraint
    if inner_constraint.impl.finished_pruning
        finished_pruning_constraint!(com, inner_constraint, inner_constraint.fct, inner_constraint.set)
    end
end
