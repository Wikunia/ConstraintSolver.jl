module ConstraintSolver

using MatrixNetworks

CS = ConstraintSolver

mutable struct CSInfo
    pre_backtrack_calls :: Int
    backtracked         :: Bool
    backtrack_counter   :: Int
    in_backtrack_calls  :: Int
end

function Base.show(io::IO, csinfo::CSInfo)
    println("Info: ")
    for name in fieldnames(CSInfo)
        println(io, "$name = $(getfield(csinfo, name))")
    end
end

mutable struct Constraint
    idx                 :: Int
    fct                 :: Function
    indices             :: Union{CartesianIndices,Vector{CartesianIndex}}
end

mutable struct ConstraintOutput
    feasible            :: Bool
    idx_changed         :: Dict{CartesianIndex, Bool}
    pruned              :: Dict{CartesianIndex,Vector{Int}}
    fixed               :: Dict{CartesianIndex, Bool}
end

mutable struct CoM
    grid                :: AbstractArray
    search_space        :: Dict{CartesianIndex,Dict{Int,Bool}}
    subscription        :: Dict{CartesianIndex,Vector{Int}} 
    constraints         :: Vector{Constraint}
    pvals               :: Vector{Int}
    not_val             :: Int
    info                :: CSInfo
    
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

function build_search_space!(com::CS.CoM, grid::AbstractArray, pvals::Vector{Int}, if_val::Int)
    com.grid                = grid
    com.constraints         = Vector{Constraint}()
    com.subscription        = Dict{CartesianIndex,Vector}()
    com.search_space        = Dict{CartesianIndex,Dict{Int,Bool}}()
    com.pvals               = pvals
    com.not_val             = if_val
    com.info                = CSInfo(0, false, 0, 0)

    for i in keys(grid)
        if grid[i] == if_val
            com.search_space[i] = arr2dict(pvals)
        end
        com.subscription[i] = Int[]
    end
end

function fulfills_constraints(com::CS.CoM, index, value)
    constraints = com.constraints[com.subscription[index]]
    feasible = true
    for constraint in constraints
        feasible = constraint.fct(com, constraint.indices, value)
        if !feasible
            break
        end
    end
    return feasible
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
    fixed_vs_unfixed(grid, not_val, indices)

Returns the fixed_vals as well as the unfixed_indices
"""
function fixed_vs_unfixed(grid, not_val, indices)
    # get all values which are fixed
    fixed_vals = Int[]
    unfixed_indices = CartesianIndex[]
    for i in indices
        if grid[i] != not_val
            push!(fixed_vals, grid[i])
        else
            push!(unfixed_indices, i)
        end
    end
    return fixed_vals, unfixed_indices
end

"""
    add_constraint!(com::CS.CoM, fct, indices)

Add a constraint using a function name and the indices 
i.e
all_different on CartesianIndices corresponding to the grid structure
"""
function add_constraint!(com::CS.CoM, fct, indices)
    current_constraint_number = length(com.constraints)+1
    constraint = Constraint(current_constraint_number, fct, indices)
    push!(com.constraints, constraint)
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
    biggest_dependent = typemax(Int)
    found = false
    for ind in keys(com.grid)
        if com.grid[ind] == com.not_val
            num_pvals = length(com.search_space[ind])
            if num_pvals <= lowest_num_pvals
                dependent = 0
                constraints = com.constraints[com.subscription[ind]]
                for constraint in constraints
                    for cind in constraint.indices
                        if haskey(com.search_space, cind)
                            dependent += length(com.search_space[cind])
                        end
                    end
                end
                if dependent > biggest_dependent || num_pvals < lowest_num_pvals
                    lowest_num_pvals = num_pvals
                    biggest_dependent = dependent
                    best_ind = ind
                    found = true
                end
            end
        end
    end
    return found, best_ind
end

"""
    prune!(com, constraints, constraint_outputs)

Prune based on previous constraint_outputs.
Add new constraints and constraint outputs to the corresponding inputs.
Returns feasible, constraints, constraint_outputs
"""
function prune!(com, constraints, constraint_outputs; pre_backtrack=false)
    feasible = true
    co_idx = 1
    constraint_idxs_dict = Dict{Int, Bool}()
    # get all constraints which need to be called (only once)
    while co_idx < length(constraint_outputs)
        constraint_output = constraint_outputs[co_idx]
        for changed_idx in keys(constraint_output.idx_changed)
            inner_constraints = com.constraints[com.subscription[changed_idx]]
            for constraint in inner_constraints
                constraint_idxs_dict[constraint.idx] = true
            end
        end
        co_idx += 1
    end
    constraint_idxs = collect(keys(constraint_idxs_dict))
    con_counter = 0
    # while we haven't called every constraint
    while length(constraint_idxs_dict) > 0
        con_counter += 1
        constraint = com.constraints[constraint_idxs[con_counter]]
        delete!(constraint_idxs_dict, constraint.idx)
        if findfirst(v->v == com.not_val, com.grid[constraint.indices]) === nothing
            continue
        end
        constraint_output = constraint.fct(com, constraint.indices; logs = false)
        if !pre_backtrack
            com.info.in_backtrack_calls += 1
            push!(constraint_outputs, constraint_output)
            push!(constraints, constraint)
        else
            com.info.pre_backtrack_calls += 1
        end
        
        if !constraint_output.feasible
            feasible = false
            break
        end

        # if we fixed another value => add the corresponding constraint to the list
        # iff the constraint will not be called anyway in the list 
        for ind in keys(constraint_output.idx_changed)
            for constraint in com.constraints[com.subscription[ind]]
                if !haskey(constraint_idxs_dict, constraint.idx)
                    constraint_idxs_dict[constraint.idx] = true
                    push!(constraint_idxs, constraint.idx)
                end
            end
        end
    end
    return feasible, constraints, constraint_outputs
end

"""
    reverse_pruning!(com, constraints, constraint_outputs)

Reverse the changes made by constraints using their ConstraintOutputs
"""
function reverse_pruning!(com::CS.CoM, constraints, constraint_outputs)
    for cidx = 1:length(constraint_outputs)
        constraint = constraints[cidx]
        constraint_output = constraint_outputs[cidx]
        for local_ind in constraint.indices
            if !haskey(constraint_output.pruned, local_ind)
                continue
            end

            if haskey(constraint_output.fixed, local_ind)
                com.grid[local_ind] = com.not_val
            end
            if !haskey(com.search_space, local_ind) && length(constraint_output.pruned[local_ind]) > 0
                com.search_space[local_ind] = Dict{Int,Bool}()
            end
            for pval in constraint_output.pruned[local_ind]
                com.search_space[local_ind][pval] = true
            end
        end
    end
end

function rec_backtrack!(com::CS.CoM)
    found, ind = get_weak_ind(com)
    if !found 
        empty!(com.search_space)
        return :Solved
    end
    com.info.backtrack_counter += 1

    pvals = keys(com.search_space[ind])
    for pval in pvals
        # check if this value is still possible
        constraints = com.constraints[com.subscription[ind]]
        feasible = true
        for constraint in constraints
            feasible = constraint.fct(com, constraint.indices, pval)
            if !feasible
                break
            end
        end
        if !feasible
            continue
        end
        # value is still possible => set it
        com.grid[ind] = pval
        constraint_outputs = ConstraintOutput[]
        for constraint in constraints
            constraint_output = constraint.fct(com, constraint.indices; logs = false)
            push!(constraint_outputs, constraint_output)
            if !constraint_output.feasible
                feasible = false
                break
            end
        end
        if !feasible
            reverse_pruning!(com, constraints, constraint_outputs)
            continue
        end

         # prune on fixed vals
         feasible, constraints, constraint_outputs = prune!(com, constraints, constraint_outputs)
         
         if !feasible
             reverse_pruning!(com, constraints, constraint_outputs)
             continue
         end

        status = rec_backtrack!(com)
        if status == :Solved
            return :Solved
        else 
            # we changed the search space and fixed values but didn't turn out well
            # -> move back to the previous state
            reverse_pruning!(com, constraints, constraint_outputs)
        end
    end
    com.grid[ind] = com.not_val
    return :Infeasible
end

function solve!(com::CS.CoM; backtrack=true)
    if length(com.search_space) == 0
        return :Solved
    end

    changed = Dict{CartesianIndex, Bool}()
    feasible = true
    constraint_outputs = ConstraintOutput[]
    for constraint in com.constraints
        com.info.pre_backtrack_calls += 1
        constraint_output = constraint.fct(com, constraint.indices)
        push!(constraint_outputs, constraint_output)
        merge!(changed, constraint_output.idx_changed)
        if !constraint_output.feasible
            feasible = false
            break
        end
    end

    if !feasible
        return :Infeasible
    end

    if length(com.search_space) == 0
        return :Solved
    end

    feasible, constraints, constraint_outputs = prune!(com, com.constraints, constraint_outputs
                                                        ;pre_backtrack=true)


    if !feasible 
        return :Infeasible
    end
    
    if length(com.search_space) == 0
        return :Solved
    end
    if backtrack
        com.info.backtracked = true
        return rec_backtrack!(com)
    else
        @info "Backtracking is turned off."
        return :NotSolved
    end
end

end # module
