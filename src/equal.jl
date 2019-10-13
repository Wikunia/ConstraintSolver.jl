"""
    equal(variables::Vector{Variable})

Create a BasicConstraint which will later be used by `equal(com, constraint)`
"""
function equal(variables::Vector{Variable})
    constraint = BasicConstraint()
    constraint.fct = equal
    constraint.indices = Int[v.idx for v in variables]
    return constraint
end

function Base.:(==)(x::Variable, y::Variable)
    bc = BasicConstraint()
    bc.fct = equal
    bc.indices = Int[x.idx, y.idx]
    return bc
end

function equal(com::CS.CoM, constraint::BasicConstraint; logs = true)
    indices = constraint.indices

    changed = Dict{Int, Bool}()

    search_space = com.search_space
    # is only needed if we want to set more 
    if length(indices) > 2
        fixed_vals, unfixed_indices = fixed_vs_unfixed(search_space, indices)

        fixed_vals_set = Set(fixed_vals)
        # check if one value is used more than once
        if length(fixed_vals_set) > 1
            logs && @warn "The problem is infeasible"
            return ConstraintOutput(false, changed)
        elseif length(fixed_vals_set) == 0
            return ConstraintOutput(true, changed)
        end

        # otherwise prune => set all variables to fixed value
        for i in unfixed_indices
            idx = indices[i]
            feasible, pr_below, pr_above = fix!(com, search_space[idx], fixed_vals[1])
            if !feasible
                return ConstraintOutput(false, changed)
            end
            changed[idx] = true
        end
    else # faster for two variables
        v1 = search_space[indices[1]]
        v2 = search_space[indices[2]]
        fixed_v1 = isfixed(v1)
        fixed_v2 = isfixed(v2)
        if !fixed_v1 && !fixed_v2
            return ConstraintOutput(true, changed)
        elseif fixed_v1 && fixed_v2
            if value(v1) != value(v2)
                return ConstraintOutput(false, changed)
            end
            return ConstraintOutput(true, changed)
        end
        # one is fixed and one isn't
        if fixed_v1
            fix_v = 2
            feasible, pr_below, pr_above = fix!(com, v2, value(v1))
            if !feasible
                return ConstraintOutput(false, changed)
            end
        else 
            feasible, pr_below, pr_above = fix!(com, v1, value(v2))
            if !feasible
                return ConstraintOutput(false, changed)
            end
            fix_v = 1
        end
        changed[indices[fix_v]] = true
    end
    return ConstraintOutput(true, changed)
end

"""
    equal(com::CoM, constraint::Constraint, value::Int, index::Int)

Returns whether the constraint can be still fulfilled.
"""
function equal(com::CoM, constraint::Constraint, value::Int, index::Int)
    indices = filter(i->i!=index, constraint.indices)
    return all(v->issetto(v,value) || !isfixed(v), com.search_space[indices])
end