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