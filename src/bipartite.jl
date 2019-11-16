struct BipartiteMatching
    weight :: Int64
    match  :: Vector{Int64}
end


function bipartite_cardinality_matching(ei_in::Vector{Int}, ej_in::Vector{Int}, m, n; ei_sorted=false)
    @assert length(ei_in) == length(ej_in)
    ei = ei_in
    ej = ej_in
    if !ei_sorted
        perm = sortperm(ei_in)
        ei = ei_in[perm]
        ej = ej_in[perm]
    end
    
    len = length(ei)
    matching_ei = zeros(Int, m)
    matching_ej = zeros(Int, n)
    
    # create initial matching
    match_len = 0
    for (ei_i,ej_i) in zip(ei,ej)
        if matching_ei[ei_i] == 0 && matching_ej[ej_i] == 0
            matching_ei[ei_i] = ej_i
            matching_ej[ej_i] = ei_i
            match_len += 1
        end
    end


    if match_len < m && match_len < n
        # creating indices be able to get edges a vertex is connected to
        # only works if l is sorted
        index_ei = zeros(Int, m+1)
        last = ei[1]
        c = 2
        @inbounds for i = 2:len
            if ei[i] != last
                index_ei[last+1] = c
                last = ei[i]
            end
            c += 1
        end
        index_ei[ei[end]+1] = c
        index_ei[1] = 1

        process_nodes = zeros(Int, m+n)
        depths = zeros(Int, m+n)
        parents = zeros(Int, m+n)
        used_ei = zeros(Bool, m)
        used_ej = zeros(Bool, n)
        found = false

        # find augmenting path
        @inbounds while match_len < m
            found = false
            
            for ei_i in ei
                # free vertex
                if matching_ei[ei_i] == 0
                    pend = 1
                    pstart = 1
                    process_nodes[pstart] = ei_i
                    depths[pstart] = 1

                    # while there are open vertices
                    while pstart <= pend
                        node = process_nodes[pstart]
                        depth = depths[pstart]
                        
                        # from ei to ej
                        if depth % 2 == 1
                            # only works if ei is sorted
                            for ej_i = index_ei[node]:index_ei[node+1]-1
                                child_node = ej[ej_i]
                                # if connected to free vertex
                                if matching_ej[child_node] == 0
                                    # found augmenting path
                                    parent = pstart
                                    last = child_node
                                    c = 0
                                    while parent != 0
                                        current = process_nodes[parent]
                                        if c % 2 == 0
                                            matching_ej[last] = current
                                            matching_ei[current] = last
                                        end
                                        c += 1
                                        last = current
                                        parent = parents[parent]
                                    end
                                    # break because we found a path
                                    found = true
                                    break
                                end
                                
                                # don't use matching edge
                                if matching_ej[child_node] != node && !used_ej[child_node]
                                    used_ej[child_node] = true
                                    pend += 1
                                    depths[pend] = depth+1
                                    process_nodes[pend] = child_node
                                    parents[pend] = pstart
                                end
                            end
                            found && break
                        else # ej to ei (only matching edge)
                            # if matching edge
                            match_to = matching_ej[node]
                            # there has to be a matching edge otherwise we would have find an 
                            # augmenting path
                            @assert match_to != 0
                            if !used_ei[match_to]
                                used_ei[match_to] = true
                                pend += 1
                                depths[pend] = depth+1
                                process_nodes[pend] = match_to
                                parents[pend] = pstart
                            end
                        end
                        pstart += 1
                    end
                end
                if !found
                    used_ei .= false
                    used_ej .= false
                    process_nodes .= 0
                    depths        .= 0
                    parents       .= 0
                end
                found && break
            end
            if found
                match_len += 1
                if match_len < m
                    used_ei .= false
                    used_ej .= false
                    process_nodes .= 0
                    depths        .= 0
                    parents       .= 0
                end
                found = false
            else 
                break
            end
        end
    end
    return BipartiteMatching(match_len, matching_ei)
end

