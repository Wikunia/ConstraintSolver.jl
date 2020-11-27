#=
    Support for single variable functions i.e a <= b
=#

"""
prune_constraint!(com::CS.CoM, constraint::CS.SingleVariableConstraint, fct::MOI.ScalarAffineFunction{T}, set::MOI.LessThan{T}; logs = true) where T <: Real

Support for constraints of the form a <= b where a and b are single variables.
This function removes values which aren't possible based on this constraint.
"""
function prune_constraint!(
    com::CS.CoM,
    constraint::CS.SingleVariableConstraint,
    fct::SAF{T},
    set::MOI.LessThan{T};
    logs = true,
) where {T<:Real}
    lhs = constraint.lhs
    rhs = constraint.rhs
    search_space = com.search_space
    !remove_above!(com, search_space[lhs], search_space[rhs].max) && return false
    !remove_below!(com, search_space[rhs], search_space[lhs].min) && return false
    return true
end

"""
    less_than(com::CoM, constraint::CS.SingleVariableConstraint, vidx::Int, val::Int)

Checks whether setting an `vidx` to `val` fulfills `constraint`
"""
function still_feasible(
    com::CoM,
    constraint::CS.SingleVariableConstraint,
    fct::SAF{T},
    set::MOI.LessThan{T},
    vidx::Int,
    val::Int,
) where {T<:Real}
    if constraint.lhs == vidx
        # if a > maximum possible value of rhs => Infeasible
        if val > com.search_space[constraint.rhs].max
            return false
        else
            return true
        end
    elseif constraint.rhs == vidx
        if val < com.search_space[constraint.lhs].min
            return false
        else
            return true
        end
    else
        error("This should not happen but if it does please open an issue with the information: SingleVariableConstraint index is neither lhs nor rhs and your model.")
    end
end

function is_constraint_solved(
    constraint::CS.SingleVariableConstraint,
    fct::SAF{T},
    set::MOI.LessThan{T},
    values::Vector{Int}
) where {T<:Real}
    return values[1] <= values[2]
end
