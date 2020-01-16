function isapprox_discrete(com::CS.CoM, val)
    return isapprox(val, round(val); atol=com.options.atol, rtol=com.options.rtol)
end

function isapprox_divisible(com::CS.CoM, val, divider)
    modulo_near_0 = isapprox(val % divider, 0; atol=com.options.atol, rtol=com.options.rtol)
    modulo_near_divider = isapprox(val % divider, divider; atol=com.options.atol, rtol=com.options.rtol)
    return modulo_near_0 || modulo_near_divider
end

function get_approx_discrete(val)
    return convert(Int, round(val))
end

function get_safe_upper_threshold(com::CS.CoM, val, divider)
    floor_threshold = fld(val, divider)
    float_threshold = val/divider
    threshold = convert(Int, floor_threshold)
    # if the difference is almost 1 we round in the other direction to provide a safe upper bound
    if isapprox(float_threshold-floor_threshold, 1.0; rtol=com.options.rtol, atol=com.options.atol)
        threshold = convert(Int, cld(val, divider))
    end
    return threshold
end

function get_safe_lower_threshold(com::CS.CoM, val, divider)
    ceil_threshold = cld(val, divider)
    float_threshold = val/divider
    threshold = convert(Int, ceil_threshold)
    # if the difference is almost 1 we round in the other direction to provide a safe lower bound
    if isapprox(ceil_threshold-float_threshold, 1.0; rtol=com.options.rtol, atol=com.options.atol)
        threshold = convert(Int, fld(val, divider))
    end
    return threshold
end

"""
    var_vector_to_moi(vars::Vector{Variable})

Convert a vector of variables to MOI.VectorOfVariables
"""
function var_vector_to_moi(vars::Vector{Variable})
    return MOI.VectorOfVariables([MOI.VariableIndex(v.idx) for v in vars])
end

"""
    linear_combination_to_saf(lc::LinearCombination)

Convert a LinearCombination to a ScalarAffineFunction and return the SAF + the used type
"""
function linear_combination_to_saf(lc::LinearCombination)
    T = eltype(lc.coeffs)
    sat = [MOI.ScalarAffineTerm{T}(lc.coeffs[i],MOI.VariableIndex(lc.indices[i])) for i=1:length(lc.indices)]
    return SAF{T}(sat, zero(T)), T
end