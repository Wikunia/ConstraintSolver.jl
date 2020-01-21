"""
    Base.:(<=)(x::LinearCombination, y::Real)

Create a linear constraint with `LinearCombination` and an integer rhs `y`. \n
Can be used i.e by `add_constraint!(com, x+y <= 2)`.
"""
function Base.:(<=)(x::LinearCombination, y::Real)
    indices, coeffs, constant_lhs = simplify(x)
    
    rhs = y-constant_lhs
    func, T = linear_combination_to_saf(LinearCombination(indices, coeffs))
    lc = LinearConstraint(func, MOI.LessThan{T}(rhs), indices)
    
    lc.hash = constraint_hash(lc)
    return lc
end

function Base.:(<=)(x::Real, y::LinearCombination)
    indices = y.indices
    coeffs = -y.coeffs
    return LinearCombination(indices, coeffs) <= -x
end

"""
    Base.:(==)(x::LinearCombination, y::Variable)

Create a linear constraint with `LinearCombination` and a variable rhs `y`. \n
Can be used i.e by `add_constraint!(com, x+y <= z)`.
"""
function Base.:(<=)(x::LinearCombination, y::Variable)
    return x - LinearCombination([y.idx], [1]) <= 0
end

"""
    Base.:(<=)(x::LinearCombination, y::LinearCombination)

Create a linear constraint with `LinearCombination` on the left and right hand side. \n
Can be used i.e by `add_constraint!(com, x+y <= a+b)`.
"""
function Base.:(<=)(x::LinearCombination, y::LinearCombination)
    return x-y <= 0
end

function prune_constraint!(com::CS.CoM, constraint::LinearConstraint, fct::SAF{T}, set::MOI.LessThan{T}; logs = true) where T <: Real
    indices = constraint.indices
    search_space = com.search_space
    rhs = set.upper - fct.constant

    # compute max and min values for each index
    maxs = constraint.maxs
    mins = constraint.mins
    pre_maxs = constraint.pre_maxs
    pre_mins = constraint.pre_mins
    for (i,idx) in enumerate(indices)
        if fct.terms[i].coefficient >= 0
            max_val = search_space[idx].max * fct.terms[i].coefficient
            min_val = search_space[idx].min * fct.terms[i].coefficient
        else
            min_val = search_space[idx].max * fct.terms[i].coefficient
            max_val = search_space[idx].min * fct.terms[i].coefficient
        end
        maxs[i] = max_val
        mins[i] = min_val
        pre_maxs[i] = max_val
        pre_mins[i] = min_val
    end

    # for each index compute the minimum value possible
    # to fulfill the constraint
    full_min = sum(mins)-rhs

    # if the minimum is bigger than 0 (and not even near zero)
    # the equation can't sum to <= 0 => infeasible
    if full_min > com.options.atol
        com.bt_infeasible[indices] .+= 1
        return false
    end

    for (i,idx) in enumerate(indices)
        if isfixed(search_space[idx])
            continue
        end
        # minimum without current index
        c_min = full_min-mins[i]
        # if the current maximum is too high set a new maximum value to be less than 0
        if c_min + maxs[i] > com.options.atol
            maxs[i] = -c_min
        end
    end

    # update all
    for (i,idx) in enumerate(indices)
        # if the maximum of coefficient * variable got reduced
        # get a safe threshold because of floating point errors
        if maxs[i] < pre_maxs[i]
            threshold = get_safe_upper_threshold(com, maxs[i], fct.terms[i].coefficient)
            if fct.terms[i].coefficient > 0
                still_feasible = remove_above!(com, search_space[idx], threshold)
            else
                still_feasible = remove_below!(com, search_space[idx], threshold)
            end
            if !still_feasible
                return false
            end
        end
    end

    return true
end

function still_feasible(com::CoM, constraint::LinearConstraint, fct::SAF{T}, set::MOI.LessThan{T}, val::Int, index::Int) where T <: Real
    search_space = com.search_space
    rhs = set.upper - fct.constant
    min_sum = zero(T)

    for (i,idx) in enumerate(constraint.indices)
        if idx == index
            min_sum += val*fct.terms[i].coefficient
            continue
        end
        if isfixed(search_space[idx])
            min_sum += CS.value(search_space[idx])*fct.terms[i].coefficient
        else
            if fct.terms[i].coefficient >= 0
                min_sum += search_space[idx].min*fct.terms[i].coefficient
            else
                min_sum += search_space[idx].max*fct.terms[i].coefficient
            end
        end
    end
    if min_sum > rhs+com.options.atol
        return false
    end

    return true
end
