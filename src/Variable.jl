mutable struct Variable
    idx         :: Int
    from        :: Int
    to          :: Int
    first_ptr   :: Int
    last_ptr    :: Int
    values      :: Vector{Int}
    indices     :: Vector{Int}
    offset      :: Int 
    min         :: Int
    max         :: Int
end

function nvalues(v::CS.Variable)
    return v.last_ptr-v.first_ptr+1
end

function value(v::CS.Variable)
    return v.values[v.last_ptr]
end

function values(v::CS.Variable)
    return v.values[v.first_ptr:v.last_ptr]
end

function issetto(v::CS.Variable, x::Int)
    if !isfixed(v) 
        return false
    else
        return x == value(v)
    end
end

function has(v::CS.Variable, x::Int)
    if x > v.to || x < v.from
        return false
    end
    ind = v.indices[x+v.offset]
    return v.first_ptr <= ind <= v.last_ptr
end

function rm!(v::CS.Variable, x::Int; set_min_max=true)
    ind = v.indices[x+v.offset]
    v.indices[x+v.offset], v.indices[v.values[v.last_ptr]+v.offset] = v.indices[v.values[v.last_ptr]+v.offset], v.indices[x+v.offset]
    v.values[ind], v.values[v.last_ptr] = v.values[v.last_ptr], v.values[ind]
    v.last_ptr -= 1
    if set_min_max 
        vals = values(v)
        if length(vals) > 0
            if x == v.min 
                v.min = minimum(vals)
            end
            if x == v.max
                v.max = maximum(vals)
            end
        end
    end
end

function fix!(v::CS.Variable, x::Int)
    ind = v.indices[x+v.offset]
    v.last_ptr = ind
    v.first_ptr = ind
    v.min = x
    v.max = x
end

function isfixed(v::CS.Variable)
    return v.last_ptr == v.first_ptr
end

function remove_below(var::CS.Variable, val::Int)
    vals = values(var)
    nremoved = 0
    for v in vals
        if v < val
            rm!(var, v; set_min_max = false)
            nremoved += 1
        end
    end
    if nremoved > 0 && feasible(var)
        var.min = minimum(values(var))
    end
    return nremoved
end

function remove_above(var::CS.Variable, val::Int)
    vals = values(var)
    nremoved = 0
    for v in vals
        if v > val
            rm!(var, v; set_min_max = false)
            nremoved += 1
        end
    end
    if nremoved > 0 && feasible(var)
        var.max = maximum(values(var))
    end
    return nremoved
end

function feasible(var::CS.Variable)
    return var.last_ptr >= var.first_ptr
end