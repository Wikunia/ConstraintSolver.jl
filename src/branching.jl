"""
    get_split_pvals(com, ::SplitAuto, var::Variable)

Splits the possible values into two by using either :smallest or :biggest value and the rest.
It depends on whether it's a satisfiability or optimization problem and whether the variable has a positive 
or negative coefficient + minimization or maximization 
Return lb, leq, geq, ub => the bounds for the lower part and the bounds for the upper part
"""
function get_split_pvals(com, ::SplitAuto, var::Variable)
    @assert var.min != var.max
    if isa(com.objective, LinearCombinationObjective)
        linear_comb = com.objective.lc 
        for i in 1:length(linear_comb.indices)
            if linear_comb.indices[i] == var.idx
                coeff = linear_comb.coeffs[i]
                factor = com.sense == MOI.MIN_SENSE ? -1 : 1
                if coeff*factor > 0
                    return get_split_pvals(com, SplitBiggest(), var)
                else
                    return get_split_pvals(com, SplitSmallest(), var)
                end
            end
        end
    end
    # fallback for satisfiability or not in objective
    return get_split_pvals(com, SplitSmallest(), var)
end

"""
    get_split_pvals(com, ::SplitInHalf, var::Variable)

Splits the possible values into two by obtaining the mean value.
Return lb, leq, geq, ub => the bounds for the lower part and the bounds for the upper part
"""
function get_split_pvals(com, ::SplitInHalf, var::Variable)
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
    get_split_pvals(com, ::SplitSmallest, var::Variable)

Splits the possible values into two by using the smallest value and the rest.
Return lb, leq, geq, ub => the bounds for the lower part and the bounds for the upper part
"""
function get_split_pvals(com, ::SplitSmallest, var::Variable)
    @assert var.min != var.max
    right_lb = partialsort(values(var), 2)
    return var.min, var.min, right_lb, var.max
end

"""
    get_split_pvals(com, ::SplitBiggest, var::Variable)

Splits the possible values into two by using the biggest value and the rest.
Return lb, leq, geq, ub => the bounds for the lower part and the bounds for the upper part
"""
function get_split_pvals(com, ::SplitBiggest, var::Variable)
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
