function is_empty(bitset::RSparseBitSet)
    for i=1:bitset.last_ptr
        idx = bitset.indices[i]
        if bitset.words[idx] != UInt64(0)
            return false
        end
    end
    return true
    # TODO use last_ptr
    # return bitset.last_ptr == 0
end

function clear_mask(bitset::RSparseBitSet)
    for i=1:bitset.last_ptr
        idx = bitset.indices[i]
        bitset.mask[idx] = UInt64(0)
    end
end

function clear_temp_mask(bitset::RSparseBitSet)
    for i=1:bitset.last_ptr
        idx = bitset.indices[i]
        bitset.temp_mask[idx] = UInt64(0)
    end
end

function full_mask(bitset::RSparseBitSet)
    for i=1:bitset.last_ptr
        idx = bitset.indices[i]
        bitset.mask[idx] = typemax(UInt64)
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

function add_to_temp_mask(bitset::RSparseBitSet, add::Vector{UInt64})
    for i=1:bitset.last_ptr
        idx = bitset.indices[i]
        bitset.temp_mask[idx] |= add[idx] 
    end
end

function intersect_mask_with_mask(bitset::RSparseBitSet, intersect_mask::Vector{UInt64})
    for i=1:bitset.last_ptr
        idx = bitset.indices[i]
        bitset.mask[idx] &= intersect_mask[idx] 
    end
end

function intersect_with_mask_feasible(bitset::RSparseBitSet)
    words = bitset.words
    mask = bitset.mask
    for i=bitset.last_ptr:-1:1
        idx = bitset.indices[i]
        w = words[idx] & mask[idx]
        if w != UInt64(0)
           return true # is feasible
        end
    end
    return false
end

function intersect_with_mask(bitset::RSparseBitSet)
    words = bitset.words
    mask = bitset.mask
    for i=bitset.last_ptr:-1:1
        idx = bitset.indices[i]
        w = words[idx] & mask[idx]
        if w != words[idx]
            words[idx] = w
            # TODO: Change last_ptr here later
        end
    end
end

function rev_intersect_with_mask(bitset::RSparseBitSet)
    words = bitset.words
    mask = bitset.mask
    for i=bitset.last_ptr:-1:1
        idx = bitset.indices[i]
        w = words[idx] | mask[idx]
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
