function clear_mask(bitset::RSparseBitSet)
    for i=1:bitset.last_ptr
        idx = bitset.indices[i]
        bitset.mask[idx] = UInt64(0)
    end
end

function invert_mask(bitset::RSparseBitSet)
    for i=1:bitset.last_ptr
        idx = bitset.indices[i]
        bitset.mask[idx] = ~bitset.mask[idx]
    end
end

function add_to_mask(bitset::RSparseBitSet, add::Vector{UInt64})
    for i=1:bitset.last_ptr
        idx = bitset.indices[i]
        bitset.mask[idx] |= add[idx] 
    end
end

function intersect_with_mask(bitset::RSparseBitSet)
    words = bitset.words
    mask = bitset.mask
    for i=bitset.last_ptr:-1:1
        idx = bitset.indices[i]
        w = words[idx] & mask[idx]
        println("words[idx]: $(words[idx]) & mask[idx]: $(mask[idx]) => $w")
        if w != words[idx]
            words[idx] = w
            # TODO: Change last_ptr here later
        end
    end
end
    
function intersect_index(bitset::RSparseBitSet, mask::Vector{UInt64})
    words = bitset.words
    for i=1:bitset.last_ptr
        idx = bitset.indices[i]
        w = words[idx] & mask[idx]
        if w != zero(UInt64)
            return idx
        end
    end
    return 0
end