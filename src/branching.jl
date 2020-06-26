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
        lc = com.objective.lc 
        for i in 1:length(lc.indices)
            if lc.indices[i] == var.idx
                coeff = lc.coeffs[i]
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
    lowest_num_pvals = typemax(Int)
    biggest_inf = -1
    best_ind = -1
    biggest_dependent = typemax(Int)
    is_in_objective = false
    found = false

    for ind = 1:length(com.search_space)
        if !isfixed(com.search_space[ind])
            num_pvals = nvalues(com.search_space[ind])
            inf = com.bt_infeasible[ind]
            if !is_in_objective && com.var_in_obj[ind]
                is_in_objective = true
                lowest_num_pvals = num_pvals
                biggest_inf = inf
                best_ind = ind
                found = true
                continue
            end
            if !is_in_objective || com.var_in_obj[ind]
                if inf >= biggest_inf
                    if inf > biggest_inf || num_pvals < lowest_num_pvals
                        lowest_num_pvals = num_pvals
                        biggest_inf = inf
                        best_ind = ind
                        found = true
                    end
                end
            end
        end
    end
    return found, best_ind
end
