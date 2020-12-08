is_empty(bitset::RSparseBitSet) = bitset.last_ptr == 0

function clear_mask(bitset::RSparseBitSet)
    indices = bitset.indices
    mask = bitset.mask
    @inbounds for i in 1:(bitset.last_ptr)
        idx = indices[i]
        mask[idx] = UInt64(0)
    end
end

function full_mask(bitset::RSparseBitSet)
    indices = bitset.indices
    mask = bitset.mask
    @inbounds for i in 1:length(indices)
        idx = indices[i]
        mask[idx] = typemax(UInt64)
    end
end

function invert_mask(bitset::RSparseBitSet)
    indices = bitset.indices
    mask = bitset.mask
    @inbounds for i in 1:(bitset.last_ptr)
        idx = indices[i]
        mask[idx] = ~mask[idx]
    end
end

function add_to_mask(bitset::RSparseBitSet, add)
    mask = bitset.mask
    indices = bitset.indices
    @inbounds for i in 1:(bitset.last_ptr)
        idx = indices[i]
        mask[idx] |= add[idx]
    end
end

function intersect_mask_with_mask(bitset::RSparseBitSet, intersect_mask)
    indices = bitset.indices
    mask = bitset.mask
    @inbounds for i in 1:(bitset.last_ptr)
        idx = indices[i]
        mask[idx] &= intersect_mask[idx]
    end
end

function intersect_with_mask_feasible(bitset::RSparseBitSet)
    words = bitset.words
    mask = bitset.mask
    indices = bitset.indices
    @inbounds for i in (bitset.last_ptr):-1:1
        idx = indices[i]
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
    indices = bitset.indices
    @inbounds for i in (bitset.last_ptr):-1:1
        idx = indices[i]
        w = words[idx] & mask[idx]
        if w != words[idx]
            words[idx] = w
            if w == zero(UInt64)
                indices[i] = indices[bitset.last_ptr]
                indices[bitset.last_ptr] = idx
                bitset.last_ptr -= 1
            end
        end
    end
end

function intersect_index(bitset::RSparseBitSet, mask)
    words = bitset.words
    indices = bitset.indices
    @inbounds for i in 1:(bitset.last_ptr)
        idx = indices[i]
        w = words[idx] & mask[idx]
        if w != zero(UInt64)
            return idx
        end
    end
    return 0
end
