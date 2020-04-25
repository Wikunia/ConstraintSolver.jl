is_empty(bitset::RSparseBitSet) = bitset.last_ptr == 0

function clear_mask(bitset::RSparseBitSet)
    indices = bitset.indices
    mask = bitset.mask
    @inbounds for i=1:bitset.last_ptr
        idx = indices[i]
        mask[idx] = UInt64(0)
    end
end

function clear_temp_mask(bitset::RSparseBitSet)
    indices = bitset.indices
    temp_mask = bitset.temp_mask
    @inbounds for i=1:length(indices)
        idx = indices[i]
        temp_mask[idx] = UInt64(0)
    end
end

function full_mask(bitset::RSparseBitSet)
    indices = bitset.indices
    mask = bitset.mask
    @inbounds for i=1:length(indices)
        idx = indices[i]
        mask[idx] = typemax(UInt64)
    end
end

function invert_mask(bitset::RSparseBitSet)
    indices = bitset.indices
    mask = bitset.mask
    @inbounds for i=1:bitset.last_ptr
        idx = indices[i]
        mask[idx] = ~mask[idx]
    end
end

function add_to_mask(bitset::RSparseBitSet, add::Vector{UInt64})
    mask = bitset.mask
    indices = bitset.indices
    @inbounds for i=1:bitset.last_ptr
        idx = indices[i]
        mask[idx] |= add[idx] 
    end
end

function add_to_temp_mask(bitset::RSparseBitSet, add::Vector{UInt64})
    indices = bitset.indices
    temp_mask = bitset.temp_mask
    @inbounds for i=1:length(indices)
        idx = indices[i]
        temp_mask[idx] |= add[idx] 
    end
end

function intersect_mask_with_mask(bitset::RSparseBitSet, intersect_mask::Vector{UInt64})
    indices = bitset.indices
    mask = bitset.mask
    @inbounds for i=1:bitset.last_ptr
        idx = indices[i]
        mask[idx] &= intersect_mask[idx] 
    end
end

function intersect_with_mask_feasible(bitset::RSparseBitSet)
    words = bitset.words
    mask = bitset.mask
    indices = bitset.indices
    @inbounds for i=bitset.last_ptr:-1:1
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
    @inbounds for i=bitset.last_ptr:-1:1
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

function rev_intersect_with_mask(bitset::RSparseBitSet)
    words = bitset.words
    mask = bitset.mask
    indices = bitset.indices
    @inbounds for i=1:length(words)
        idx = indices[i]
        w = words[idx] | mask[idx]
        if w != words[idx]
            if words[idx] == zero(UInt64) && i == bitset.last_ptr+1
                bitset.last_ptr += 1
            elseif words[idx] == zero(UInt64)
                @assert i > bitset.last_ptr
                indices[i] = indices[bitset.last_ptr+1]
                indices[bitset.last_ptr+1] = idx
                bitset.last_ptr += 1
            end
            words[idx] = w
        end
    end
end
    
function intersect_index(bitset::RSparseBitSet, mask::Vector{UInt64})
    words = bitset.words
    indices = bitset.indices
    @inbounds for i=1:bitset.last_ptr
        idx = indices[i]
        w = words[idx] & mask[idx]
        if w != zero(UInt64)
            return idx
        end
    end
    return 0
end
