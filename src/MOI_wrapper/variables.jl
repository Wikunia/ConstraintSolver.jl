"""
Single variable bound constraints
"""
# MOI.supports_constraint(::Optimizer, ::Type{SVF}, ::Type{AbstractVector{<:MOI.AbstractScalarSet}}) = true
MOI.supports_constraint(
    ::Optimizer, 
    ::Type{SVF}, 
    ::Type{MOI.LessThan{T}}
) where {T<:Real} = true

MOI.supports_constraint(
    ::Optimizer,
    ::Type{SVF},
    ::Type{MOI.GreaterThan{T}},
) where {T<:Real} = true

MOI.supports_constraint(
    ::Optimizer,
    ::Type{SVF}, 
    ::Type{MOI.EqualTo{T}}
) where {T<:Real} = true

MOI.supports_constraint(
    ::Optimizer,
    ::Type{SVF}, 
    ::Type{MOI.Interval{T}}
) where {T<:Real} = true


MOI.supports_constraint(
    ::Optimizer,
    ::Type{SVF},
    ::Type{Integers},
) = true

"""
Binary/Integer variable support
"""
MOI.supports_constraint(::Optimizer, ::Type{SVF}, ::Type{<:VAR_TYPES}) = true

"""
    check_var_bounds(model)

Checks whether all variables are integral and bounded on both sides. If not an error is throws
"""
function check_var_bounds(model::Optimizer)
    for var in model.variable_info
        if !var.has_lower_bound || !var.has_upper_bound || !var.is_integer
            throw(ErrorException("Each variable must be an integer and bounded. Currently the variable index $(var.idx) doesn't fulfill this requirements."))
        end
    end
end

"""
    addupd_var_in_inner_model(model::Optimizer, var_index::Int)

Adds all variables to model.inner.search_space
"""
function addupd_var_in_inner_model(model::Optimizer, var_index::Int)
    if length(model.inner.search_space) < var_index
        push!(model.inner.search_space, model.variable_info[var_index])
    else
        model.inner.search_space[var_index] = model.variable_info[var_index]
    end
end

"""
    MOI.add_variable(model::Optimizer)
"""
function MOI.add_variable(model::Optimizer)
    index = length(model.variable_info) + 1
    push!(model.variable_info, Variable(index))
    changes = changes = Vector{Vector{Tuple{Symbol,Int,Int,Int}}}()
    push!(changes, Vector{Tuple{Symbol,Int,Int,Int}}())
    model.variable_info[index].changes = changes
    push!(model.inner.subscription, Int[])
    push!(model.inner.bt_infeasible, 0)
    addupd_var_in_inner_model(model, index)
    return MOI.VariableIndex(index)
end

MOI.add_variables(model::Optimizer, n::Int) = [MOI.add_variable(model) for i = 1:n]

function check_inbounds(model::Optimizer, vi::VI)
    num_variables = length(model.variable_info)
    if !(1 <= vi.value <= num_variables)
        @error "Invalid variable index $vi. ($num_variables variables in the model.)"
    end
    return
end

check_inbounds(model::Optimizer, var::SVF) = check_inbounds(model, var.variable)

has_upper_bound(model::Optimizer, vi::VI) = model.variable_info[vi.value].has_upper_bound

has_lower_bound(model::Optimizer, vi::VI) = model.variable_info[vi.value].has_lower_bound

is_fixed(model::Optimizer, vi::VI) = model.variable_info[vi.value].is_fixed

function MOI.add_constraint(model::Optimizer, v::SVF, t::MOI.Integer)
    vi = v.variable
    model.variable_info[vi.value].is_integer = true

    cindex = length(model.var_constraints) + 1
    push!(model.var_constraints, (vi.value, :int, typemin(Int), typemax(Int)))

    addupd_var_in_inner_model(model, vi.value)
    return MOI.ConstraintIndex{SVF,MOI.Integer}(cindex)
end

function MOI.add_constraint(model::Optimizer, v::SVF, t::MOI.ZeroOne)
    vi = v.variable
    model.variable_info[vi.value].is_integer = true

    model.variable_info[vi.value].upper_bound = 1
    model.variable_info[vi.value].max = 1
    model.variable_info[vi.value].has_upper_bound = true
    model.variable_info[vi.value].lower_bound = 0
    model.variable_info[vi.value].min = 0
    model.variable_info[vi.value].has_lower_bound = true
    model.variable_info[vi.value].values = [0, 1]
    model.variable_info[vi.value].init_vals = [0, 1]
    model.variable_info[vi.value].init_val_to_index = 1:2
    model.variable_info[vi.value].offset = 1
    model.variable_info[vi.value].indices = 1:2
    model.variable_info[vi.value].first_ptr = 1
    model.variable_info[vi.value].last_ptr = 2
    addupd_var_in_inner_model(model, vi.value)

    cindex = length(model.var_constraints) + 1
    push!(model.var_constraints, (vi.value, :bin, typemin(Int), typemax(Int)))
    return MOI.ConstraintIndex{SVF,MOI.ZeroOne}(cindex)
end

function MOI.add_constraint(model::Optimizer, v::SVF, t::Integers)
    vi = v.variable
    model.variable_info[vi.value].is_integer = true

    set_vals = t.values
    set_variable_from_integers!(model.variable_info[vi.value], set_vals)

    addupd_var_in_inner_model(model, vi.value)
    min_val, max_val = model.variable_info[vi.value].min, model.variable_info[vi.value].max

    cindex = length(model.var_constraints) + 1
    # TODO: If we want to do something with var_constraints later we need to save the actual input values
    push!(model.var_constraints, (vi.value, :integers, min_val, max_val))
    return MOI.ConstraintIndex{SVF,Integers}(cindex)
end

#=
Populating Variable bounds
=#
function MOI.add_constraint(
    model::Optimizer,
    v::SVF,
    interval::MOI.Interval{T},
) where {T<:Real}
    vi = v.variable
    check_inbounds(model, vi)
    isnan(interval.upper) &&
    throw(ErrorException("The interval bounds can not contain NaN and must be an Integer. Currently it has an upper bound of $(interval.upper)"))
    has_upper_bound(model, vi) && @error "Upper bound on variable $vi exists already."
    isnan(interval.lower) &&
    throw(ErrorException("The interval bounds can not contain NaN and must be an Integer. Currently it has a lower bound of $(interval.lower)"))
    has_lower_bound(model, vi) && @error "Lower bound on variable $vi exists already."
    is_fixed(model, vi) && @error "Variable $vi is fixed. Cannot also set upper bound."

    model.variable_info[vi.value].upper_bound = interval.upper
    model.variable_info[vi.value].max = interval.upper
    model.variable_info[vi.value].has_upper_bound = true
    model.variable_info[vi.value].lower_bound = interval.lower
    model.variable_info[vi.value].offset = 1 - interval.lower
    model.variable_info[vi.value].min = interval.lower
    model.variable_info[vi.value].has_lower_bound = true

    model.variable_info[vi.value].values =
        model.variable_info[vi.value].min:model.variable_info[vi.value].max
    num_vals = model.variable_info[vi.value].max - model.variable_info[vi.value].min + 1
    model.variable_info[vi.value].indices = 1:num_vals
    model.variable_info[vi.value].first_ptr = 1
    model.variable_info[vi.value].last_ptr = num_vals
    model.variable_info[vi.value].init_vals = copy(model.variable_info[vi.value].values)
    model.variable_info[vi.value].init_val_to_index = copy(model.variable_info[vi.value].indices)

    addupd_var_in_inner_model(model, vi.value)

    cindex = length(model.var_constraints) + 1
    push!(model.var_constraints, (vi.value, :interval, interval.lower, interval.upper))
    return MOI.ConstraintIndex{SVF,MOI.Interval{T}}(cindex)
end

function MOI.add_constraint(model::Optimizer, v::SVF, lt::MOI.LessThan{T}) where {T<:Real}
    vi = v.variable
    check_inbounds(model, vi)
    isnan(lt.upper) &&
    throw(ErrorException("The variable bounds can not contain NaN and must be an Integer. Currently it has an upper bound of $(lt.upper)"))
    has_upper_bound(model, vi) && @error "Upper bound on variable $vi already exists."
    is_fixed(model, vi) && @error "Variable $vi is fixed. Cannot also set upper bound."

    model.variable_info[vi.value].upper_bound = lt.upper
    model.variable_info[vi.value].max = lt.upper
    model.variable_info[vi.value].has_upper_bound = true

    if has_lower_bound(model, vi)
        model.variable_info[vi.value].values =
            model.variable_info[vi.value].min:model.variable_info[vi.value].max
        num_vals = model.variable_info[vi.value].max - model.variable_info[vi.value].min + 1
        model.variable_info[vi.value].indices = 1:num_vals
        model.variable_info[vi.value].first_ptr = 1
        model.variable_info[vi.value].last_ptr = num_vals
        model.variable_info[vi.value].init_vals = copy(model.variable_info[vi.value].values)
        model.variable_info[vi.value].init_val_to_index = copy(model.variable_info[vi.value].indices)
    end

    addupd_var_in_inner_model(model, vi.value)

    cindex = length(model.var_constraints) + 1
    push!(model.var_constraints, (vi.value, :leq, typemin(Int), lt.upper))
    return MOI.ConstraintIndex{SVF,MOI.LessThan{T}}(cindex)
end

function MOI.add_constraint(
    model::Optimizer,
    v::SVF,
    gt::MOI.GreaterThan{T},
) where {T<:Real}
    vi = v.variable
    check_inbounds(model, vi)
    isnan(gt.lower) &&
    throw(ErrorException("The variable bounds can not contain NaN and must be an Integer. Currently it has an upper bound of $(gt.upper)"))
    has_lower_bound(model, vi) && @error "Lower bound on variable $vi already exists."
    is_fixed(model, vi) && @error "Variable $vi is fixed. Cannot also set lower bound."

    model.variable_info[vi.value].lower_bound = gt.lower
    model.variable_info[vi.value].min = gt.lower
    model.variable_info[vi.value].offset = 1 - gt.lower
    model.variable_info[vi.value].has_lower_bound = true

    if has_upper_bound(model, vi)
        model.variable_info[vi.value].values =
            model.variable_info[vi.value].min:model.variable_info[vi.value].max
        num_vals = model.variable_info[vi.value].max - model.variable_info[vi.value].min + 1
        model.variable_info[vi.value].indices = 1:num_vals
        model.variable_info[vi.value].first_ptr = 1
        model.variable_info[vi.value].last_ptr = num_vals
        model.variable_info[vi.value].init_vals = copy(model.variable_info[vi.value].values)
        model.variable_info[vi.value].init_val_to_index = copy(model.variable_info[vi.value].indices)
    end
    addupd_var_in_inner_model(model, vi.value)

    cindex = length(model.var_constraints) + 1
    push!(model.var_constraints, (vi.value, :geq, gt.lower, typemax(Int)))
    return MOI.ConstraintIndex{SVF,MOI.GreaterThan{T}}(cindex)
end

function MOI.add_constraint(model::Optimizer, v::SVF, eq::MOI.EqualTo{T}) where {T<:Real}
    vi = v.variable
    check_inbounds(model, vi)
    isnan(eq.value) && @error "Invalid fixed value $(eq.value)."
    has_lower_bound(model, vi) && @error "Variable $vi has a lower bound. Cannot be fixed."
    has_upper_bound(model, vi) && @error "Variable $vi has an upper bound. Cannot be fixed."
    is_fixed(model, vi) && @error "Variable $vi is already fixed."
    model.variable_info[vi.value].lower_bound = eq.value
    model.variable_info[vi.value].upper_bound = eq.value
    model.variable_info[vi.value].is_fixed = true
    model.variable_info[vi.value].has_lower_bound = true
    model.variable_info[vi.value].has_upper_bound = true
    model.variable_info[vi.value].min = eq.value
    model.variable_info[vi.value].max = eq.value
    model.variable_info[vi.value].values = [eq.value]
    model.variable_info[vi.value].indices = [1]
    model.variable_info[vi.value].first_ptr = 1
    model.variable_info[vi.value].last_ptr = 1
    model.variable_info[vi.value].init_vals = copy(model.variable_info[vi.value].values)
    model.variable_info[vi.value].init_val_to_index = copy(model.variable_info[vi.value].indices)
    addupd_var_in_inner_model(model, vi.value)

    cindex = length(model.var_constraints) + 1
    push!(model.var_constraints, (vi.value, :eq, eq.value, eq.value))
    return MOI.ConstraintIndex{SVF,MOI.EqualTo{T}}(cindex)
end

function set_variable_from_integers!(var::Variable, set_vals)
    min_val, max_val = extrema(set_vals)
    range = max_val-min_val+1
    vals = copy(set_vals)
    append!(vals, zeros(Int, range-length(vals)))

    # fill the indices such that 1:length(set_vals) map to set_vals
    indices = zeros(Int, range)
    # .- needed for the offset
    indices[set_vals .- (min_val-1)] = 1:length(set_vals)
    j = length(set_vals)+1
    for i=1:range
        if indices[i] == 0
            indices[i] = j
            j += 1
        end
    end

    var.upper_bound = max_val
    var.max = max_val
    var.has_upper_bound = true
    var.lower_bound = min_val
    var.min = min_val
    var.has_lower_bound = true
    var.values = vals
    var.init_vals = copy(vals)
    var.offset = 1 - min_val
    var.indices = indices
    # needs copy to be different
    var.init_val_to_index = copy(indices)
    var.first_ptr = 1
    var.last_ptr = length(set_vals)
end

"""
    set_init_fixes!(com::CS.CoM)

Redefines variables if they are fixed to a specific value
"""
function set_init_fixes!(com::CS.CoM)
    for fixes in com.init_fixes
        var_idx = fixes[1]
        val = fixes[2]
        var = com.search_space[var_idx]
        set_variable_from_integers!(var, [val])
    end
end