struct BipartiteMatching
    weight :: Int
    match  :: Vector{Int}
end


function bipartite_cardinality_matching(l_in::Vector{Int}, r_in::Vector{Int}, m, n; l_sorted=false, matching_init=nothing)
    @assert length(l_in) == length(r_in)
    @assert m <= n
    l = l_in
    r = r_in
    if !l_sorted
        if matching_init === nothing 
            perm = sortperm(l_in)
        else 
            perm = sortperm(l_in[1:matching_init.l_in_len])
        end
        l = l_in[perm]
        r = r_in[perm]
    end

    if matching_init === nothing
        len = length(l)
    else
        len = matching_init.l_in_len
    end
    if matching_init === nothing
        matching_l = zeros(Int, m)
        matching_r = zeros(Int, n)
    else
        matching_l = matching_init.matching_l
        matching_r = matching_init.matching_r
        matching_l .= 0
        matching_r .= 0
    end

    # create initial matching
    match_len = 0
    for i = 1:len
        li, ri = l[i], r[i]
        if matching_l[li] == 0 && matching_r[ri] == 0
            matching_l[li] = ri
            matching_r[ri] = li
            match_len += 1
        end
    end


    if match_len < m
        # creating indices be able to get edges a vertex is connected to
        # only works if l is sorted
        if matching_init === nothing
            index_l = zeros(Int, m+1)
        else
            index_l = matching_init.index_l
        end
        last = l[1]
        c = 2
        for i = 2:len
            if l[i] != last
                index_l[last+1] = c
                last = l[i]
            end
            c += 1
        end
        index_l[l[len]+1] = c

        index_l[1] = 1

        if matching_init === nothing
            process_nodes = zeros(Int, m+n)
            depths = zeros(Int, m+n)
            parents = zeros(Int, m+n)
            used_l = zeros(Bool, m)
            used_r = zeros(Bool, n)
        else
            process_nodes = matching_init.process_nodes
            depths = matching_init.depths
            parents = matching_init.parents
            used_l = matching_init.used_l
            used_r = matching_init.used_r
            process_nodes .= 0
            depths .= 0
            parents .= 0
            used_l .= false
            used_r .= false
        end
        found = false

        # find augmenting path
        while match_len < m
            pend = 1
            pstart = 1
            for i=1:len
                li = l[i]
                # free vertex
                if matching_l[li] == 0
                    process_nodes[pstart] = li
                    depths[pstart] = 1
                    break
                end
            end

            while pstart <= pend
                node = process_nodes[pstart]
                depth = depths[pstart]

                # from left to right
                if depth % 2 == 1
                    used_l[node] = true
                    # only works if l is sorted
                    for ri=index_l[node]:index_l[node+1]-1
                        child_node = r[ri]
                        # don't use matching edge
                        if matching_r[child_node] != node && !used_r[child_node]
                            used_r[child_node] = true
                            pend += 1
                            depths[pend] = depth+1
                            process_nodes[pend] = child_node
                            parents[pend] = pstart
                        end
                    end
                else # right to left (only matching edge)
                    # if matching edge
                    match_to = matching_r[node]
                    if match_to != 0
                        if !used_l[match_to]
                            used_l[match_to] = true
                            pend += 1
                            depths[pend] = depth+1
                            process_nodes[pend] = match_to
                            parents[pend] = pstart
                        end
                    else
                        # found augmenting path
                        parent = pstart
                        last = 0
                        c = 0
                        while parent != 0
                            current = process_nodes[parent]
                            if last != 0
                                if c % 2 == 1
                                    matching_r[last] = current
                                    matching_l[current] = last
                                end
                            end
                            c += 1
                            last = current
                            parent = parents[parent]
                        end
                        # break because we found a path
                        found = true
                        break
                    end
                end
                pstart += 1
            end
            if found
                match_len += 1
                if match_len < m
                    used_l .= false
                    used_r .= false
                end
                found = false
            else
                break
            end
        end
    end
    return BipartiteMatching(match_len, matching_l)
end
