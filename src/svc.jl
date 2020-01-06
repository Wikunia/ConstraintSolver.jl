#=
    Support for single variable functions i.e a <= b
=#

"""
    less_than(com::CS.CoM, constraint::SingleVariableConstraint; logs = true)

Support for constraints of the form a <= b where a and b are single variables.
This function removes values which aren't possible based on this constraint.
"""
function less_than(com::CS.CoM, constraint::CS.SingleVariableConstraint; logs = true)
    
    return true
end

"""
    less_than(com::CoM, constraint::CS.SingleVariableConstraint, val::Int, index::Int)

Checks whether setting an `index` to `val` fulfills `constraint`
"""
function less_than(com::CoM, constraint::CS.SingleVariableConstraint, val::Int, index::Int)
    if constraint.lhs == index
        # if a > maximum possible value of rhs => Infeasible
        if val > com.search_space[constraint.rhs].max
            return false
        else
            return true
        end
    elseif constraint.rhs == index
        if val < com.search_space[constraint.lhs].min
            return false
        else
            return true
        end
    else
        error("This should not happen but if it does please open an issue with the information: SingleVariableConstraint index is neither lhs nor rhs and your model.")
    end
end