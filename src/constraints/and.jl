function get_constraint(fct, set)
    if fct isa SAF
        return new_linear_constraint(fct, set)
    else
        internals = create_interals(fct, set)
        return init_constraint_struct(set, internals) 
    end
end

function get_saf(fct::MOI.VectorAffineFunction)
    MOI.ScalarAffineFunction([t.scalar_term for t in fct.terms], fct.constants[1])
end

function get_vov(fct::MOI.VectorAffineFunction)
    return MOI.VectorOfVariables([t.scalar_term.variable_index for t in fct.terms])
end


function init_constraint_struct(set::AndSet{F1,F2}, internals) where {F1,F2}
    f = MOIU.eachscalar(internals.fct)

    lhs_fct = f[1:set.lhs_dimension]
    rhs_fct = f[end-set.rhs_dimension+1:end]

    if F1 <: MOI.ScalarAffineFunction
        lhs_fct = get_saf(lhs_fct)
    end
    if F2 <: MOI.ScalarAffineFunction
        rhs_fct = get_saf(rhs_fct)
    end

    if F1 <: MOI.VectorOfVariables
        lhs_fct = get_vov(lhs_fct)
    end
    if F2 <: MOI.VectorOfVariables
        rhs_fct = get_vov(rhs_fct)
    end

   
    lhs = get_constraint(lhs_fct, set.lhs_set)
    rhs = get_constraint(rhs_fct, set.rhs_set)

    AndConstraint(
        internals,
        lhs,
        rhs
    )
end

function init_constraint!(
    com::CS.CoM,
    constraint::AndConstraint,
    fct,
    set::AndSet;
    active = true,
)
    set_impl_functions!(com,  constraint.lhs)
    set_impl_functions!(com,  constraint.rhs)
    if constraint.lhs.impl.init   
        !init_constraint!(com, constraint.lhs, constraint.lhs.fct, constraint.lhs.set) && return false
    end
    if constraint.rhs.impl.init   
        !init_constraint!(com, constraint.rhs, constraint.rhs.fct, constraint.rhs.set) && return false
    end
    return true
end


"""
    is_constraint_solved(
        constraint::AndConstraint,
        fct,
        set::AndSet,
        values::Vector{Int},
    )  

Checks if both inner constraints are solved
"""
function is_constraint_solved(
    constraint::AndConstraint,
    fct,
    set::AndSet,
    values::Vector{Int},
)
    lhs_solved = is_constraint_solved(constraint.lhs, constraint.lhs.fct, constraint.lhs.set, values[1:set.lhs_dimension])
    rhs_solved = is_constraint_solved(constraint.rhs, constraint.rhs.fct, constraint.rhs.set, values[end-set.rhs_dimension+1:end])
    return lhs_solved && rhs_solved
end

"""
    function is_constraint_violated(
        com::CoM,
        constraint::AndConstraint,
        fct,
        set::AndSet,
    )

Check if either of the inner constraints are violated already
"""
function is_constraint_violated(
    com::CoM,
    constraint::AndConstraint,
    fct,
    set::AndSet,
)
    lhs_violated = is_constraint_violated(com, constraint.lhs, constraint.lhs.fct, constraint.lhs.set)
    rhs_violated = is_constraint_violated(com, constraint.rhs, constraint.rhs.fct, constraint.rhs.set)
    return lhs_violated || rhs_violated
end


"""
    still_feasible(com::CoM, constraint::AndConstraint, fct, set::AndSet, vidx::Int, value::Int)

Return whether the constraint can be still fulfilled when setting a variable with index `vidx` to `value`.
**Attention:** This assumes that it isn't violated before.
"""
function still_feasible(
    com::CoM,
    constraint::AndConstraint,
    fct,
    set::AndSet,
    vidx::Int,
    value::Int,
)
    lhs_indices = constraint.lhs.indices
    for i in 1:length(lhs_indices)
        if lhs_indices[i] == vidx
            !still_feasible(com, constraint.lhs, constraint.lhs.fct, constraint.lhs.set, vidx, value) && return false
        end
    end
    rhs_indices = constraint.rhs.indices
    for i in 1:length(rhs_indices)
        if rhs_indices[i] == vidx
            !still_feasible(com, constraint.rhs, constraint.rhs.fct, constraint.rhs.set, vidx, value) && return false
        end
    end
    return true
end

"""
    prune_constraint!(com::CS.CoM, constraint::AndConstraint, fct, set::AndSet; logs = true)

Reduce the number of possibilities given the `AndConstraint` by pruning both parts
Return whether still feasible
"""
function prune_constraint!(
    com::CS.CoM,
    constraint::AndConstraint,
    fct,
    set::AndSet;
    logs = true,
)
    !prune_constraint!(com, constraint.lhs, constraint.lhs.fct, constraint.lhs.set; logs=logs) && return false
    feasible = prune_constraint!(com, constraint.rhs, constraint.rhs.fct, constraint.rhs.set; logs=logs)
    return feasible
end