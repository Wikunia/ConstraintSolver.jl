"""
    get_split_pvals(com, ::Val{:Auto}, var::Variable)

Splits the possible values into two by using either :smallest or :biggest value and the rest.
It depends on whether it's a satisfiability or optimization problem and whether the variable has a positive 
or negative coefficient + minimization or maximization 
Return lb, leq, geq, ub => the bounds for the lower part and the bounds for the upper part
"""
function get_split_pvals(com, ::Val{:Auto}, var::Variable)
    @assert var.min != var.max
    if isa(com.objective, LinearCombinationObjective)
        linear_comb = com.objective.lc 
        for i in 1:length(linear_comb.indices)
            if linear_comb.indices[i] == var.idx
                coeff = linear_comb.coeffs[i]
                factor = com.sense == MOI.MIN_SENSE ? -1 : 1
                if coeff*factor > 0
                    return get_split_pvals(com, Val(:Biggest), var)
                else
                    return get_split_pvals(com, Val(:Smallest), var)
                end
            end
        end
    end
    # fallback for satisfiability or not in objective
    return get_split_pvals(com, Val(:Smallest), var)
end

"""
    get_split_pvals(com, ::Val{:InHalf}, var::Variable)

Splits the possible values into two by obtaining the mean value.
Return lb, leq, geq, ub => the bounds for the lower part and the bounds for the upper part
"""
function get_split_pvals(com, ::Val{:InHalf}, var::Variable)
    pvals = values(var)
    @assert length(pvals) >= 2
    mean_val = mean(pvals)
    leq = typemin(Int)
    geq = typemax(Int)
    lb = typemax(Int)
    ub = typemin(Int)
    for pval in pvals
        if pval <= mean_val && pval > leq
            leq = pval
        elseif pval > mean_val && pval < geq
            geq = pval
        end
        if pval < lb 
            lb = pval
        end
        if pval > ub 
            ub = pval
        end
    end
    return lb, leq, geq, ub
end

"""
    get_split_pvals(com, ::Val{:Smallest}, var::Variable)

Splits the possible values into two by using the smallest value and the rest.
Return lb, leq, geq, ub => the bounds for the lower part and the bounds for the upper part
"""
function get_split_pvals(com, ::Val{:Smallest}, var::Variable)
    @assert var.min != var.max
    right_lb = partialsort(values(var), 2)
    return var.min, var.min, right_lb, var.max
end

"""
    get_split_pvals(com, ::Val{:Biggest}, var::Variable)

Splits the possible values into two by using the biggest value and the rest.
Return lb, leq, geq, ub => the bounds for the lower part and the bounds for the upper part
"""
function get_split_pvals(com, ::Val{:Biggest}, var::Variable)
    @assert var.min != var.max
    left_ub = partialsort(values(var), 2; rev=true)
    return var.min, left_ub, var.max, var.max
end

"""
    get_next_branch_variable(com::CS.CoM)

Get the next weak index for backtracking. This will be the next branching variable.
Return whether there is an unfixed variable and a best index
"""
function get_next_branch_variable(com::CS.CoM)
    return get_next_branch_variable(com, com.branch_strategy)
end

function get_next_branch_variable(com::CS.CoM, ::Val{:OLD})
    lowest_num_pvals = typemax(Int)
    biggest_inf = -1
    best_vidx = -1
    biggest_dependent = typemax(Int)
    is_in_objective = false
    found = false

    for vidx = 1:length(com.search_space)
        if !isfixed(com.search_space[vidx])
            num_pvals = nvalues(com.search_space[vidx])
            inf = com.bt_infeasible[vidx]
            if !is_in_objective && com.var_in_obj[vidx]
                is_in_objective = true
                lowest_num_pvals = num_pvals
                biggest_inf = inf
                best_vidx = vidx
                found = true
                continue
            end
            if !is_in_objective || com.var_in_obj[vidx]
                if inf >= biggest_inf
                    if inf > biggest_inf || num_pvals < lowest_num_pvals
                        lowest_num_pvals = num_pvals
                        biggest_inf = inf
                        best_vidx = vidx
                        found = true
                    end
                end
            end
        end
    end
    return found, best_vidx
end

function get_next_branch_variable(com::CS.CoM, ::Val{:ABS})
    # update activity 
    c_backtrack_idx = com.c_backtrack_idx
    γ = com.options.activity_decay
    for variable in com.search_space
        if length(variable.changes[c_backtrack_idx]) > 0
            variable.activity += 1
        elseif nvalues(variable) > 1
            variable.activity *= γ
        end
    end

    is_in_objective = false
    highest_activity = -1.0
    best_vidx = -1
    found = false

    for variable in com.search_space
        if !isfixed(variable)
            vidx = variable.idx
            num_pvals = nvalues(variable)
            activity_ratio = variable.activity / num_pvals
            if !is_in_objective && com.var_in_obj[vidx]
                is_in_objective = true
                found = true
                best_vidx = vidx
                continue
            end
            if !is_in_objective || com.var_in_obj[vidx]
                if activity_ratio >= highest_activity
                    highest_activity = activity_ratio
                    best_vidx = vidx
                    found = true
                end
            end
        end
    end
    return found, best_vidx
end