function _build_and_constraint(
    _error::Function,
    lhs,
    rhs,
)
    lhs_set = JuMP.moi_set(lhs)
    rhs_set = JuMP.moi_set(rhs)

    lhs_jump_func = JuMP.jump_function(lhs)
    rhs_jump_func = JuMP.jump_function(rhs)

    lhs_func = JuMP.moi_function(lhs)
    rhs_func = JuMP.moi_function(rhs)

    vov = [lhs_jump_func..., rhs_jump_func...]
    return JuMP.VectorConstraint(
            vov, AndSet(lhs_set, rhs_set, lhs_func, rhs_func, 2)
    )
end


function JuMP.parse_constraint_head(_error::Function, ::Val{:(&&)}, lhs, rhs)
    _error1 = deepcopy(_error)
    lhs_vectorized, lhs_parsecode, lhs_buildcall =
        JuMP.parse_constraint_expr(_error, lhs)

    if lhs_vectorized
        _error("`$(lhs)` should be non vectorized. There is currently no vectorized support for `and` constraints. Please open an issue at ConstraintSolver.jl")
    end

    rhs_vectorized, rhs_parsecode, rhs_buildcall =
        JuMP.parse_constraint_expr(_error1, rhs)

    if rhs_vectorized
        _error("`$(rhs)` should be non vectorized. There is currently no vectorized support for `and` constraints. Please open an issue at ConstraintSolver.jl")
    end

    # TODO implement vectorized version
    vectorized = false
    complete_parsecode = quote
        $lhs_parsecode
        $rhs_parsecode
    end

    buildcall = :($(esc(:(CS._build_and_constraint)))(
        $_error,
        $lhs_buildcall,
        $rhs_buildcall
    ))
    return vectorized, complete_parsecode, buildcall
end
