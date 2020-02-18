mutable struct ConstrainedObjectiveObj{T <: Real}
    complete_bound          :: T # best bound by single constraint
    constrained_bound       :: T # bound for the constrained idx 
    local_constrained_idx   :: Vector{Int} # local indices of objective function which are used to compute the constrained_bound
    left_over_obj           :: Union{Nothing, ObjectiveFunction} # unused part of the objective 
end


"""
    get_best_bound(com::CS.CoM, obj_fct::SingleVariableObjective, var_idx::Int, left_side::Bool, var_bound::Int)

Compute the best bound if we have a `SingleVariableObjective` and limit `var_idx` using either a `<=` or a `>=` bound 
with `var_bound` and `left_side`. `left_side = true` means we have a `<=` bound
Return a best bound given the constraints on `var_idx`
"""
function get_best_bound(com::CS.CoM, obj_fct::SingleVariableObjective, var_idx::Int, left_side::Bool, var_bound::Int)
    if obj_fct.index != var_idx
        if com.sense == MOI.MIN_SENSE
            return com.search_space[obj_fct.index].min
        else # MAX
            return com.search_space[obj_fct.index].max
        end
    else
        if com.sense == MOI.MIN_SENSE
            if left_side
                return com.search_space[obj_fct.index].min
            else
                return var_bound
            end
        else
            if left_side
                return var_bound
            else
                return com.search_space[obj_fct.index].max
            end
        end
    end
end

"""
    get_best_bound(com::CS.CoM, obj_fct::LinearCombinationObjective, var_idx::Int, left_side::Bool, var_bound::Int)

Compute the best bound if we have a `LinearCombinationObjective` and limit `var_idx` using either a `<=` or a `>=` bound 
with `var_bound` and `left_side`. `left_side = true` means we have a `<=` bound
Return a best bound given the constraints on `var_idx`
"""
function get_best_bound(com::CS.CoM, obj_fct::LinearCombinationObjective, var_idx::Int, left_side::Bool, var_bound::Int)
    indices = obj_fct.lc.indices
    coeffs = obj_fct.lc.coeffs
    objval = obj_fct.constant
    if com.sense == MOI.MIN_SENSE
        for i=1:length(indices)
            if indices[i] == var_idx
                if left_side && coeffs[i] >= 0
                    objval += coeffs[i]*com.search_space[indices[i]].min
                elseif left_side || coeffs[i] >= 0
                    objval += coeffs[i]*var_bound
                else 
                    objval += coeffs[i]*com.search_space[indices[i]].max
                end
                continue
            end
            if coeffs[i] >= 0
                objval += coeffs[i]*com.search_space[indices[i]].min
            else
                objval += coeffs[i]*com.search_space[indices[i]].max
            end
        end
    else # MAX Sense
        for i=1:length(indices)
            if indices[i] == var_idx
                if !left_side && coeffs[i] >= 0
                    objval += coeffs[i]*com.search_space[indices[i]].max
                elseif !left_side || coeffs[i] >= 0
                    objval += coeffs[i]*var_bound
                else 
                    objval += coeffs[i]*com.search_space[indices[i]].min
                end
                continue
            end
            if coeffs[i] >= 0
                objval += coeffs[i]*com.search_space[indices[i]].max
            else
                objval += coeffs[i]*com.search_space[indices[i]].min
            end
        end
    end

    # check each constraint which has `check_in_best_bound = true` for a better bound
    # if all variables are fixed we don't have to compute several bounds
    if all(v->isfixed(v), com.search_space)
        return objval
    end

    for constraint in com.constraints
        if constraint.check_in_best_bound
            constrained_obj = get_constrained_best_bound(com, constraint, constraint.fct, constraint.set, obj_fct, var_idx, left_side, var_bound)
            # if objective is not fully constrained get better bound on currently unconstrained objective `left_over_obj`
            # only call if the constraint was helpful => left_over_obj is at least one index smaller than the previous objective
            # and of course only if there is a left over objective
            if constrained_obj.left_over_obj !== nothing && length(constrained_obj.local_constrained_idx) >= 1
                bound_for_left_over = get_best_bound(com, constrained_obj.left_over_obj, var_idx, left_side, var_bound)
                constrained_obj.complete_bound = constrained_obj.constrained_bound+bound_for_left_over
            end
            if com.sense == MOI.MIN_SENSE && constrained_obj.complete_bound > objval
                objval = constrained_obj.complete_bound
            elseif com.sense == MOI.MAX_SENSE && constrained_obj.complete_bound < objval
                objval = constrained_obj.complete_bound
            end
        end
    end
    return objval
end
