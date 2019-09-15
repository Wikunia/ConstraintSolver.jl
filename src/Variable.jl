mutable struct Variable
    idx         :: Int
    from        :: Int
    to          :: Int
    first_ptr   :: Int
    last_ptr    :: Int
    values      :: Vector{Int}
    indices     :: Vector{Int}
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
    if x > length(v.values) || x < 1
        return false
    end
    ind = v.indices[x]
    return v.first_ptr <= ind <= v.last_ptr
end

function rm!(v::CS.Variable, x::Int)
    ind = v.indices[x]
    v.indices[x], v.indices[v.values[v.last_ptr]] = v.indices[v.values[v.last_ptr]], v.indices[x]
    v.values[ind], v.values[v.last_ptr] = v.values[v.last_ptr], v.values[ind]
    v.last_ptr -= 1
end

function fix!(v::CS.Variable, x::Int)
    ind = v.indices[x]
    v.last_ptr = ind
    v.first_ptr = ind
end

function isfixed(v::CS.Variable)
    return v.last_ptr == v.first_ptr
end