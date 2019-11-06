"""
    all_different(variables::Vector{Variable})

Create a BasicConstraint which will later be used by `all_different(com, constraint)`. \n
Can be used i.e by `add_constraint!(com, CS.all_different(variables))`.
"""
function all_different(variables::Vector{Variable})
    constraint = BasicConstraint()
    constraint.fct = all_different
    constraint.indices = Int[v.idx for v in variables]
    return constraint
end


"""
    all_different(com::CS.CoM, constraint::BasicConstraint; logs = true)

Tries to reduce the search space by the all_different constraint. 
Fixes values and then sets com.changed to true for the corresponding index.
Returns a ConstraintOutput object and throws a warning if infeasible and `logs` is set
"""
function all_different(com::CS.CoM, constraint::BasicConstraint; logs = true)
    indices = constraint.indices
    pvals = constraint.pvals 
    nindices = length(indices)

    search_space = com.search_space
    fixed_vals, unfixed_indices = fixed_vs_unfixed(search_space, indices)

    fixed_vals_set = Set(fixed_vals)
    # check if one value is used more than once
    if length(fixed_vals_set) < length(fixed_vals)
        logs && @warn "The problem is infeasible"
        return false
    end

    bfixed = true
    current_fixed_vals = fixed_vals
    
    while bfixed
        new_fixed_vals = Int[]
        bfixed = false
        for i in 1:length(unfixed_indices)
            pi = unfixed_indices[i]
            ind = indices[pi]
            @views c_search_space = search_space[ind]
            if !CS.isfixed(c_search_space)
                for pv in current_fixed_vals
                    if has(c_search_space, pv)
                        if !rm!(com, c_search_space, pv)
                            logs && @warn "The problem is infeasible"
                            return false
                        end

                        if nvalues(c_search_space) == 1
                            only_value = value(c_search_space)
                            push!(fixed_vals, only_value)
                            push!(new_fixed_vals, only_value)
                            bfixed = true
                            break
                        end
                    end
                end
            end
        end
        current_fixed_vals = new_fixed_vals
    end

    if length(fixed_vals) == nindices
        return true
    end

    min_pvals, max_pvals = extrema(pvals)
    len_range = max_pvals-min_pvals+1

    # find maximum_matching for infeasible check and Berge's lemma
    # building graph
    # ei = indices, ej = possible values
    # i.e ei=[1,2,1] ej = [1,2,2] => 1->[1,2], 2->[2]
    min_pvals_m1 = min_pvals-1

    pval_mapping = zeros(Int, length(pvals))
    vertex_mapping = zeros(Int, len_range)
    vertex_mapping_bw = zeros(Int, nindices+length(pvals))
    vc = 1
    for i in indices
        vertex_mapping_bw[vc] = i
        vc += 1
    end
    pvc = 1
    for pv in pvals
        pval_mapping[pvc] = pv
        vertex_mapping[pv-min_pvals_m1] = vc
        vertex_mapping_bw[vc] = pv
        vc += 1
        pvc += 1
    end
    num_nodes = vc


    # count the number of edges
    num_edges = 0
    @inbounds for i in indices
        num_edges += nvalues(search_space[i])
    end

    di_ei = Vector{Int64}(undef,num_edges)
    di_ej = Vector{Int64}(undef,num_edges)

    # add edge from each index to the possible values
    edge_counter = 0
    vc = 0
    @inbounds for i in indices
        vc += 1
        if isfixed(search_space[i])
            edge_counter += 1
            di_ei[edge_counter] = vc
            di_ej[edge_counter] = vertex_mapping[value(search_space[i])-min_pvals_m1]-nindices
        else
            for pv in values(search_space[i])
                edge_counter += 1
                di_ei[edge_counter] = vc
                di_ej[edge_counter] = vertex_mapping[pv-min_pvals_m1]-nindices
            end
        end
    end

    # find maximum matching (weights are 1)
    _weights = ones(Bool,num_edges)
    maximum_matching = bipartite_matching(_weights, di_ei, di_ej)
    if maximum_matching.weight != nindices
        logs && @warn "Infeasible (No maximum matching was found)"
        return false
    end

    # directed edges for strongly connected components
    vc = 0
    edge_counter = 0
    @inbounds for i in indices
        vc += 1
        if isfixed(search_space[i])
            edge_counter += 1
            di_ei[edge_counter] = vc
            di_ej[edge_counter] = vertex_mapping[value(search_space[i])-min_pvals_m1]
        else
            for pv in values(search_space[i])
                edge_counter += 1
                if pv == pval_mapping[maximum_matching.match[vc]]
                    di_ei[edge_counter] = vc 
                    di_ej[edge_counter] = vertex_mapping[pv-min_pvals_m1]
                else
                    di_ei[edge_counter] = vertex_mapping[pv-min_pvals_m1]
                    di_ej[edge_counter] = vc
                end
            end
        end
    end

    # if we have more values than indices
    if length(pvals) > nindices
        # add extra node which has all values as input which are used in the maximum matching
        # and the ones in maximum matching as inputs see: http://www.minicp.org (Part 6)
        # the direction is opposite to that of minicp 
        used_in_maximum_matching = Dict{Int, Bool}()
        for pval in pvals
            used_in_maximum_matching[pval] = false
        end
        vc = 0
        for i in indices
            vc += 1
            for pv in values(search_space[i])
                if pv == pval_mapping[maximum_matching.match[vc]]
                    used_in_maximum_matching[pv] = true
                    break
                end
            end
        end
        new_vertex = num_nodes+1
        for pv in pvals #kv in used_in_maximum_matching
            # not in maximum matching
            if !used_in_maximum_matching[pv]
                push!(di_ei, new_vertex)
                push!(di_ej, vertex_mapping[pv-min_pvals_m1])
            else 
                push!(di_ei, vertex_mapping[pv-min_pvals_m1])
                push!(di_ej, new_vertex)
            end
        end
    end

    sccs_map = strong_components_map(di_ei, di_ej)

    # remove the left over edges from the search space
    vmb = vertex_mapping_bw
    for (src,dst) in zip(di_ei, di_ej)
        # edges to the extra node don't count
        if src > num_nodes || dst > num_nodes
            continue
        end

        # if in same strong component -> part of a cycle -> part of a maximum matching
        if sccs_map[src] == sccs_map[dst]
            continue
        end
        #  remove edges in maximum matching and then edges which are part of a cycle
        if src <= nindices && dst == vertex_mapping[pval_mapping[maximum_matching.match[src]]-min_pvals_m1]
            continue
        end
      

        cind = vmb[dst]
        if !rm!(com, search_space[cind], vmb[src])
            logs && @warn "The problem is infeasible"
            return false
        end

        # if only one value possible make it fixed
        if nvalues(search_space[cind]) == 1
            only_value = value(search_space[cind])
        end
    end

    return true
end

"""
    all_different(com::CoM, constraint::Constraint, value::Int, index::Int)

Returns whether the constraint can be still fulfilled when setting a variable with index `index` to `value`.
"""
function all_different(com::CoM, constraint::Constraint, value::Int, index::Int)
    indices = constraint.indices
    for i=1:length(indices)
        if indices[i] == index
            continue
        end
        if issetto(com.search_space[indices[i]], value)
            return false
        end 
    end
    return true
end