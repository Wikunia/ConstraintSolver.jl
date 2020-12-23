function recompute_lc_extrema!(
    com::CS.CoM,
    constraint::LinearConstraint,
    fct::SAF{T},
) where {T<:Real}
    indices = constraint.indices
    search_space = com.search_space
    maxs = constraint.maxs
    mins = constraint.mins
    pre_maxs = constraint.pre_maxs
    pre_mins = constraint.pre_mins

    for (i, vidx) in enumerate(indices)
        if fct.terms[i].coefficient >= 0
            max_val = search_space[vidx].max * fct.terms[i].coefficient
            min_val = search_space[vidx].min * fct.terms[i].coefficient
        else
            min_val = search_space[vidx].max * fct.terms[i].coefficient
            max_val = search_space[vidx].min * fct.terms[i].coefficient
        end
        maxs[i] = max_val
        mins[i] = min_val
        pre_maxs[i] = max_val
        pre_mins[i] = min_val
    end
end
