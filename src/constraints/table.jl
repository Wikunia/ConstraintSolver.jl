include("table/support.jl")
include("table/residues.jl")
include("table/RSparseBitSet.jl")

function update_table(com::CoM, constraint::TableConstraint)
    current = constraint.current
    supports = constraint.supports
    variables = com.search_space
    for local_vidx in constraint.changed_vars
        vidx = constraint.indices[local_vidx]
        clear_mask(current)
        # TODO: Include incremental update
        # reset based update
        for value in CS.values(variables[vidx])
            add_to_mask(current, supports[com, vidx, value])
        end
        intersect_with_mask(current)
        is_empty(current) && break
    end
end

function filter_domains(com::CoM, constraint::TableConstraint)
    current = constraint.current
    supports = constraint.supports
    residues = constraint.residues
    variables = com.search_space
    for local_vidx in constraint.unfixed_vars
        vidx = constraint.indices[local_vidx]
        for value in CS.values(variables[vidx])
            idx = residues[com, vidx, value]
            if current.words[idx] & supports[com, vidx, value][idx] == UInt64(0)
                idx = intersect_index(current, supports[com, vidx, value])
                if idx != 0
                    # TODO set index method
                    residues[com, vidx, value] = idx
                else
                    if !rm!(com, variables[vidx], value)
                        return false # not feasible anymore
                    end
                end 
            end
        end
        constraint.last_sizes[local_vidx] = CS.nvalues(variables[vidx])
    end
    return true
end
    
"""
    init_constraint!(com::CS.CoM, constraint::TableConstraint, fct::MOI.VectorOfVariables, set::TableSetInternal)

"""
function init_constraint!(
    com::CS.CoM,
    constraint::TableConstraint,
    fct::MOI.VectorOfVariables,
    set::TableSetInternal,
)
    num_pos_rows = size(set.table, 1)
    
    possible_rows = trues(num_pos_rows)
    search_space = com.search_space

    indices = constraint.indices
    for row_id in 1:size(set.table)[1]
        row = set.table[row_id,:]
        for (i, vidx) in enumerate(indices)
            if !has(search_space[vidx], row[i])
                # println("row_id: $row_id")
                possible_rows[row_id] = false
                num_pos_rows -= 1
                break
            end
        end
    end
    num_pos_rows == 0 && return false

    support = constraint.supports
    
    support.var_start = cumsum([nvalues(search_space[vidx]) for vidx in indices])
    support.var_start .+= 1
    num_supports = support.var_start[end]-1

    pushfirst!(support.var_start, 1)
    num_64_words = cld(num_pos_rows, 64)

    # define RSparseBitSet
    rsbs = constraint.current
    rsbs.words = fill(~zero(UInt64), num_64_words)
    rsbs.indices = 1:num_64_words
    rsbs.last_ptr = num_64_words
    rsbs.mask = zeros(UInt64, num_64_words)
    ending_ones = (num_pos_rows-1) % 64 +1
    rsbs.words[end] = rsbs.words[end] .⊻ ((UInt64(1) << (64-ending_ones))-1)

    support.values = zeros(UInt64, (num_64_words, num_supports))

    num_64_idx = 0
    rp_idx = 0
    for r=1:length(possible_rows)
        if possible_rows[r]
            rp_idx += 1
            if rp_idx % 64 == 1
                num_64_idx += 1
            end
            for (c, vidx) in enumerate(indices)
                variable = search_space[vidx]
                var_offset = variable.offset
                table_val = set.table[r,c]
                val_idx = variable.init_val_to_index[table_val + var_offset]
                @assert variable.init_vals[val_idx] == table_val
                support_col_idx = support.var_start[c]+val_idx-1
                # println("support_col_idx: $support_col_idx")
                cell_64 = support.values[num_64_idx, support_col_idx]
                pos_in_64 = (rp_idx-1) % 64 + 1
                support.values[num_64_idx, support_col_idx] = cell_64 .| (UInt64(1) << (64-pos_in_64))
            end
        end
    end

    # check if a support column is completely zero
    # that means that the variable corresponding to that column can't have the value corresponding to the column 
    feasible = true
    for c = 1:size(support.values, 2)
        if all(i->i==UInt64(0), support.values[:,c])
            # getting the correct index in indices
            var_i = 1
            while support.var_start[var_i] <= c
                var_i += 1
            end
            var_i -= 1
            val_i = c-support.var_start[var_i]+1
            var = indices[var_i]
            val = search_space[var].init_vals[val_i]
            feasible = rm!(com, search_space[var], val; changes=false)
            !feasible && break
        end
    end
    !feasible && return false

    # define residues
    residues = constraint.residues
    residues.var_start = support.var_start
    residues.values = zeros(Int, num_supports)
    for sc=1:num_supports
        idx = support.values[:,sc]
        residues.values[sc] = intersect_index(rsbs, idx)
    end

    # define last_sizes
    constraint.last_sizes = [CS.nvalues(com.search_space[vidx]) for vidx in constraint.indices]

    return feasible
end

"""
    prune_constraint!(com::CS.CoM, constraint::TableConstraint, fct::MOI.VectorOfVariables, set::TableSetInternal; logs = true)

Reduce the number of possibilities given the `TableConstraint`.
Return whether still feasible and throws a warning if infeasible and `logs` is set to `true`
"""
function prune_constraint!(
    com::CS.CoM,
    constraint::TableConstraint,
    fct::MOI.VectorOfVariables,
    set::TableSetInternal;
    logs = true,
)
    current = constraint.current
    indices = constraint.indices
    variables = com.search_space

    # All local indices (1 corresponds to indices[1]) which have changed
    constraint.changed_vars = findall(x->CS.nvalues(variables[indices[x]]) != constraint.last_sizes[x], 1:length(indices))
    for local_vidx in constraint.changed_vars
        constraint.last_sizes[local_vidx] = CS.nvalues(variables[indices[local_vidx]])
    end
    constraint.unfixed_vars = findall(x->constraint.last_sizes[x] > 1, 1:length(indices))
    update_table(com, constraint)
    is_empty(current) && return false

    return filter_domains(com, constraint)
end

"""
    still_feasible(com::CoM, constraint::TableConstraint, fct::MOI.VectorOfVariables, set::TableSetInternal, value::Int, index::Int)

Return whether the constraint can be still fulfilled when setting a variable with index `index` to `value`.
"""
function still_feasible(
    com::CoM,
    constraint::TableConstraint,
    fct::MOI.VectorOfVariables,
    set::TableSetInternal,
    value::Int,
    index::Int,
)
    # just a placeholder 
    return true
end