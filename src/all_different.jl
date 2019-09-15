"""
    all_different(com::CS.CoM, indices; logs = true)

Tries to reduce the search space by the all_different constraint. 
Fixes values and then sets com.changed to true for the corresponding index.
Returns a ConstraintOutput object and throws a warning if infeasible and `logs` is set
"""
function all_different(com::CS.CoM, constraint; logs = true)
    indices = constraint.indices
    pvals = constraint.pvals 

    changed = Dict{Int, Bool}()
    pruned  = zeros(Int, length(indices))

    search_space = com.search_space
    fixed_vals, unfixed_indices = fixed_vs_unfixed(search_space, indices)

    fixed_vals_set = Set(fixed_vals)
    # check if one value is used more than once
    if length(fixed_vals_set) < length(fixed_vals)
        logs && @warn "The problem is infeasible"
        return ConstraintOutput(false, changed, pruned)
    end


    bfixed = false
    for i in 1:length(unfixed_indices)
        pi = unfixed_indices[i]
        ind = indices[pi]
        @views c_search_space = search_space[ind]
        for pv in fixed_vals
            if has(c_search_space, pv)
                rm!(c_search_space, pv)
                pruned[pi] += 1
                changed[ind] = true
                if nvalues(c_search_space) == 0
                    com.bt_infeasible[ind] += 1
                    logs && @warn "The problem is infeasible"
                    return ConstraintOutput(false, changed, pruned)
                end

                if nvalues(c_search_space) == 1
                    only_value = value(c_search_space)
                    # check whether this is against any constraint
                    feasible = fulfills_constraints(com, ind, only_value)
                    if !feasible
                        com.bt_infeasible[ind] += 1
                        logs && @warn "The problem is infeasible"
                        return ConstraintOutput(false, changed, pruned)
                    end
                    push!(fixed_vals_set, only_value)
                    bfixed = true
                    break
                end
            end
        end
    end

    if length(fixed_vals_set) == length(indices)
        return ConstraintOutput(true, changed, pruned)
    end

    # find maximum_matching for infeasible check and Berge's lemma
    # building graph
    # ei = indices, ej = possible values
    # i.e ei=[1,2,1] ej = [1,2,2] => 1->[1,2], 2->[2]

    pval_mapping = zeros(Int, length(pvals))
    vertex_mapping = Dict{Int,Int64}()
    vertex_mapping_bw = Vector{Union{CartesianIndex,Int}}(undef, length(indices)+length(pvals))
    vc = 1
    for i in indices
        vertex_mapping_bw[vc] = i
        vc += 1
    end
    pvc = 1
    for pv in pvals
        pval_mapping[pvc] = pv
        vertex_mapping[pv] = vc
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


    ei = Vector{Int64}(undef,num_edges)
    ej = Vector{Int64}(undef,num_edges)

    # add edge from each index to the possible values
    edge_counter = 0
    vc = 0
    @inbounds for i in indices
        vc += 1
        if isfixed(search_space[i])
            edge_counter += 1
            ei[edge_counter] = vc
            ej[edge_counter] = vertex_mapping[value(search_space[i])]-length(indices)
        else
            for pv in values(search_space[i])
                edge_counter += 1
                ei[edge_counter] = vc
                ej[edge_counter] = vertex_mapping[pv]-length(indices)
            end
        end
    end

    # find maximum matching (weights are 1)
    _weights = ones(Bool,num_edges)
    maximum_matching = bipartite_matching(_weights,ei, ej)
    if maximum_matching.weight != length(indices)
        logs && @warn "Infeasible (No maximum matching was found)"
        return ConstraintOutput(false, changed, pruned)
    end

    # directed edges for strongly connected components
    di_ei = Vector{Int64}(undef,num_edges)
    di_ej = Vector{Int64}(undef,num_edges)

    vc = 0
    edge_counter = 0
    @inbounds for i in indices
        vc += 1
        if isfixed(search_space[i])
            edge_counter += 1
            di_ei[edge_counter] = vc
            di_ej[edge_counter] = vertex_mapping[value(search_space[i])]
        else
            for pv in values(search_space[i])
                edge_counter += 1
                if pv == pval_mapping[maximum_matching.match[vc]]
                    di_ei[edge_counter] = vc 
                    di_ej[edge_counter] = vertex_mapping[pv]
                else
                    di_ei[edge_counter] = vertex_mapping[pv]
                    di_ej[edge_counter] = vc
                end
            end
        end
    end

    sccs_map = strong_components_map(di_ei, di_ej)

    # remove the left over edges from the search space
    vmb = vertex_mapping_bw
    for (src,dst) in zip(di_ei, di_ej)
        # if in same strong component -> part of a cycle -> part of a maximum matching
        if sccs_map[src] == sccs_map[dst]
            continue
        end
        #  remove edges in maximum matching and then edges which are part of a cycle
        if src <= length(indices) && dst == vertex_mapping[pval_mapping[maximum_matching.match[src]]]
            continue
        end

        cind = vmb[dst]
        rm!(search_space[cind], vmb[src])
        for i=1:length(indices)
            if indices[i] == cind
                pruned[i] += 1
                break
            end
        end
        changed[cind] = true

        # if only one value possible make it fixed
        if nvalues(search_space[cind]) == 1
            only_value = value(search_space[cind])
            feasible = fulfills_constraints(com, cind, only_value)
            if !feasible
                logs && @warn "The problem is infeasible"
                com.bt_infeasible[cind] += 1
                return ConstraintOutput(false, changed, pruned)
            end
            changed[cind] = true
        end
    end

    return ConstraintOutput(true, changed, pruned)
end

"""
    all_different(com::CoM, indices, value::Int)

Returns whether the constraint can be still fulfilled.
"""
function all_different(com::CoM, indices, value::Int)
   return !any(v->issetto(v,value), com.search_space[indices])
end