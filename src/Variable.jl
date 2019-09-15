mutable struct Variable
    idx         :: Int
    from        :: Int
    to          :: Int
    first_ptr   :: Int
    last_ptr    :: Int
    values      :: Vector{Int}
    indices     :: Vector{Int}
    offset      :: Int 
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

function rm!(v::CS.Variable, x::Int)
    ind = v.indices[x+v.offset]
    v.indices[x+v.offset], v.indices[v.values[v.last_ptr]+v.offset] = v.indices[v.values[v.last_ptr]+v.offset], v.indices[x+v.offset]
    v.values[ind], v.values[v.last_ptr] = v.values[v.last_ptr], v.values[ind]
    v.last_ptr -= 1
end

function fix!(v::CS.Variable, x::Int)
    ind = v.indices[x+v.offset]
    v.last_ptr = ind
    v.first_ptr = ind
end

function isfixed(v::CS.Variable)
    return v.last_ptr == v.first_ptr
end