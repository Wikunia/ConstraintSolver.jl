module ConstraintSolver

CS = ConstraintSolver

mutable struct CoM
    grid                :: AbstractArray
    search_space        :: Dict{CartesianIndex,Dict{Int,Bool}}
    subscription        :: Dict{CartesianIndex,Vector{Int}} 
    constraints         :: Vector{Tuple}
    changed             :: Dict{CartesianIndex, Bool}
    pvals               :: Vector{Int}
    not_val             :: Int
    
    CoM() = new()
end

include("all_different.jl")

function init()
    return CoM()
end

function arr2dict(arr)
    d = Dict{Int,Bool}()
    for v in arr
        d[v] = true
    end
    return d
end

function build_search_space(com::CS.CoM, grid::AbstractArray, pvals::Vector{Int}, if_val::Int)
    com.grid                = copy(grid)
    com.constraints         = Vector{Tuple}()
    com.subscription        = Dict{CartesianIndex,Vector}()
    com.search_space        = Dict{CartesianIndex,Dict{Int,Bool}}()
    com.changed             = Dict{CartesianIndex, Bool}()
    com.pvals               = pvals
    com.not_val             = if_val

    for i in keys(grid)
        if grid[i] == if_val
            com.search_space[i] = arr2dict(pvals)
        end
        com.subscription[i] = []
    end
end

function print_search_space(com::CS.CoM; max_length=:default)
    if max_length == :default
        if length(com.search_space) == 0
            max_length = ceil(log10(maximum(com.pvals)))+1
        else
            max_length = 2+2*length(com.pvals)
        end
    end

    grid = com.grid
    for y=1:size(grid)[1]
        line = ""
        for x=1:size(grid)[2]
            if grid[y,x] == com.not_val
                pstr = "-"
                if haskey(com.search_space, CartesianIndex((y,x)))
                    possible = sort(collect(keys(com.search_space[CartesianIndex((y,x))])))
                    pstr = join(possible, ",")
                end
                space_left  = floor(Int, (max_length-length(pstr))/2)
                space_right = ceil(Int, (max_length-length(pstr))/2)
                line *= repeat(" ", space_left)*pstr*repeat(" ", space_right)
            else
                pstr = string(grid[y,x])
                space_left  = floor(Int, (max_length-length(pstr))/2)
                space_right = ceil(Int, (max_length-length(pstr))/2)
                line *= repeat(" ", space_left)*pstr*repeat(" ", space_right)
            end
        end
        println(line)
    end
end 

"""
    fixed_vs_unfixed(com::CS.CoM, indices)

Returns the fixed_vals as well as the unfixed_indices
"""
function fixed_vs_unfixed(com::CS.CoM, indices)
    # get all values which are fixed
    fixed_vals = []
    unfixed_indices = []
    for i in indices
        if com.grid[i] != com.not_val
            push!(fixed_vals, com.grid[i])
        else
            push!(unfixed_indices, i)
        end
    end
    return fixed_vals, unfixed_indices
end

"""
    add_constraint(com::CS.CoM, func, indices)

Add a constraint using a function name and the indices 
i.e
all_different on CartesianIndices corresponding to the grid structure
"""
function add_constraint(com::CS.CoM, func, indices)
    push!(com.constraints, (func, indices))
    current_constraint_number = length(com.constraints)
    for i in indices
        # only if index is in search space
        if haskey(com.subscription, i)
            push!(com.subscription[i], current_constraint_number)
        end
    end
end

function get_weak_ind(com::CS.CoM)
    lowest_num_pvals = length(com.pvals)+1
    best_ind = CartesianIndex(-1,-1)
    found = false
    for ind in keys(com.grid)
        if com.grid[ind] == com.not_val
            num_pvals = length(com.search_space[ind])
            if num_pvals < lowest_num_pvals
                lowest_num_pvals = num_pvals
                best_ind = ind
                found = true
                if num_pvals == 2
                    return found, best_ind
                end
            end
        end
    end
    return found, best_ind
end

function backtrack(com::CS.CoM)
    found, ind = get_weak_ind(com)
    if !found 
        empty!(com.search_space)
        return :Solved
    end

    pvals = keys(com.search_space[ind])
    for pval in pvals
        # check if this value is still possible
        constraints = com.constraints[com.subscription[ind]]
        feasible = true
        for constraint in constraints
            fct, indices = constraint
            feasible = fct(com, indices, pval)
            if !feasible
                break
            end
        end
        if !feasible
            continue
        end
        # value is still possible => set it
        com.grid[ind] = pval
        status = backtrack(com)
        if status == :Solved
            return :Solved
        end
    end
    com.grid[ind] = com.not_val
    return :Infeasible
end

function solve(com::CS.CoM)
    if length(com.search_space) == 0
        return :Solved
    end
    feasible = true
    for constraint in com.constraints
        funcname, indices = constraint
        if findfirst(v->v == com.not_val, com.grid[indices]) === nothing 
            continue
        end
        feasible = funcname(com, indices)
        if !feasible
            break
        end
    end

    if length(com.search_space) == 0
        return :Solved
    end

    while length(com.changed) > 0 && feasible
        first_changed = collect(keys(com.changed))[1]
        delete!(com.changed, first_changed)
        constraints = com.constraints[com.subscription[first_changed]]
        for constraint in constraints
            funcname, indices = constraint
            if findfirst(v->v == com.not_val, com.grid[indices]) === nothing 
                continue
            end
            feasible = funcname(com, indices)
            if !feasible
                break
            end
        end
    end
    if !feasible
        return :Infeasible
    end

    status = backtrack(com)
    return status
end

end # module
