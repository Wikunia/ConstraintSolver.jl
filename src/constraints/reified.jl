function init_constraint!(
    com::CS.CoM,
    constraint::ReifiedConstraint,
    fct::Union{MOI.VectorOfVariables,VAF{T}},
    set::RS,
) where {A,T<:Real,RS<:ReifiedSet{A}}
    inner_constraint = constraint.inner_constraint
    anti_constraint = constraint.anti_constraint

    variables = com.search_space
    rei_vidx = constraint.indices[1]
    rei_var = variables[rei_vidx]

    # check which methods that inner constraint supports
    set_impl_functions!(com, inner_constraint)
    anti_constraint !== nothing && set_impl_functions!(com, anti_constraint)

    if inner_constraint.impl.init
        feasible = init_constraint!(
            com,
            inner_constraint,
            inner_constraint.fct,
            inner_constraint.set;
            active = false,
        )
        # map the bounds to the indicator constraint
        constraint.bound_rhs = inner_constraint.bound_rhs
        # the reified variable can't be activated if inner constraint is infeasible
        if !feasible
            !rm!(com, rei_var, Int(constraint.activate_on)) && return false
        end
    end

    if anti_constraint !== nothing && anti_constraint.impl.init
        feasible = init_constraint!(
            com,
            anti_constraint,
            anti_constraint.fct,
            anti_constraint.set;
            active = false,
        )
    end
    # still feasible
    return true
end

function prune_constraint!(
    com::CS.CoM,
    constraint::ReifiedConstraint,
    fct::Union{MOI.VectorOfVariables,VAF{T}},
    set::RS;
    logs = true,
) where {A,T<:Real,RS<:ReifiedSet{A}}
    # 1. if the inner constraint is solved then the reified variable can be set to activate_on
    # 2. if the inner constraint is anti-solved (all fixed but don't fulfill) the reified variable can be set to !activate_on
    # 3. if the reified constraint is active then prune can be called for the inner constraint
    # 4. if the reified constraint is fixed to inactive one can "anti" prune

    variables = com.search_space
    rei_vidx = constraint.indices[1]
    inner_constraint = constraint.inner_constraint
    anti_constraint = constraint.anti_constraint
    activate_on = Int(constraint.activate_on)
    activate_off = activate_on == 1 ? 0 : 1

    # 1
    if is_constraint_solved(
        com,
        inner_constraint,
        inner_constraint.fct,
        inner_constraint.set,
    )
        !fix!(com, variables[rei_vidx], activate_on) && return false
        # 2
    elseif all(isfixed(variables[vidx]) for vidx in inner_constraint.indices)
        !fix!(com, variables[rei_vidx], activate_off) && return false
        # 3
    elseif issetto(variables[rei_vidx], activate_on)
        return prune_constraint!(
            com,
            inner_constraint,
            inner_constraint.fct,
            inner_constraint.set,
        )
    elseif issetto(variables[rei_vidx], activate_off) && anti_constraint !== nothing
        return prune_constraint!(
            com,
            anti_constraint,
            anti_constraint.fct,
            anti_constraint.set,
        )
    end
    return true
end

function still_feasible(
    com::CS.CoM,
    constraint::ReifiedConstraint,
    fct::Union{MOI.VectorOfVariables,VAF{T}},
    set::RS,
    vidx::Int,
    val::Int,
) where {A,T<:Real,RS<:ReifiedSet{A}}
    inner_constraint = constraint.inner_constraint
    variables = com.search_space
    activate_on = Int(constraint.activate_on)
    activate_off = activate_on == 1 ? 0 : 1
    rei_vidx = constraint.indices[1]

    # if currently activated check if inner constraint is feasible
    if (vidx == rei_vidx && val == activate_on) || issetto(variables[rei_vidx], activate_on)
        # check if already violated
        violated = is_constraint_violated(
            com,
            inner_constraint,
            inner_constraint.fct,
            inner_constraint.set,
        )
        violated && return false
        return still_feasible(
            com,
            inner_constraint,
            inner_constraint.fct,
            inner_constraint.set,
            vidx,
            val,
        )
    end
    # if inner constraint can't be activated it shouldn't be solved
    if (vidx == rei_vidx && val == activate_off) || issetto(variables[rei_vidx], activate_off)
        if all(i == vidx || isfixed(com.search_space[i]) for i in inner_constraint.indices)
            values = [
                i == vidx ? val : value(com.search_space[i])
                for i in inner_constraint.indices
            ]
            return !is_constraint_solved(
                inner_constraint,
                inner_constraint.fct,
                inner_constraint.set,
                values,
            )
        end
    end
    return true
end

function is_constraint_solved(
    constraint::ReifiedConstraint,
    fct::Union{MOI.VectorOfVariables,VAF{T}},
    set::RS,
    values::Vector{Int},
) where {A,T<:Real,RS<:ReifiedSet{A}}
    activate_on = Int(constraint.activate_on)
    inner_constraint = constraint.inner_constraint
    return is_constraint_solved(
        inner_constraint,
        inner_constraint.fct,
        inner_constraint.set,
        values[2:end],
    ) == (values[1] == activate_on)
end

"""
    is_constraint_violated(
        com::CoM,
        constraint::ReifiedConstraint,
        fct::Union{MOI.VectorOfVariables,VAF{T}},
        set::RS
    )  where {A,T<:Real,RS<:ReifiedSet{A}}

Checks if the constraint is violated as it is currently set. This can happen inside an
inactive reified or indicator constraint.
"""
function is_constraint_violated(
    com::CoM,
    constraint::ReifiedConstraint,
    fct::Union{MOI.VectorOfVariables,VAF{T}},
    set::RS,
) where {A,T<:Real,RS<:ReifiedSet{A}}
    if all(isfixed(var) for var in com.search_space[constraint.indices])
        return !is_constraint_solved(
            constraint,
            fct,
            set,
            [CS.value(var) for var in com.search_space[constraint.indices]],
        )
    end

    reified_vidx = constraint.indices[1]
    reified_var = com.search_space[reified_vidx]
    if isfixed(reified_var) && CS.value(reified_var) == Int(constraint.activate_on)
        inner_constraint = constraint.inner_constraint
        return is_constraint_violated(
            com,
            inner_constraint,
            inner_constraint.fct,
            inner_constraint.set,
        )
    end
    return false
end
