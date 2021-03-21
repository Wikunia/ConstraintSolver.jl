function _build_anti_constraint(
    _error::Function,
    constraint,
)
    set = JuMP.moi_set(constraint)

    jump_func = JuMP.jump_function(constraint)

    return JuMP.VectorConstraint(
        jump_func, AntiSet(set, MOI.dimension(set))
    )
end


function JuMP.parse_one_operator_constraint(_error::Function, vectorized::Bool, ::Val{:!}, constraint)
    _error1 = deepcopy(_error)
    if vectorized
        _error("`$(constraint)` should be non vectorized. There is currently no vectorized support for `anti` constraints. Please open an issue at ConstraintSolver.jl")
    end

    vectorized, inner_parsecode, inner_buildcall = JuMP.parse_constraint_expr(_error1, constraint)

    buildcall = :($(esc(:(CS._build_anti_constraint)))(
        $_error,
        $inner_buildcall,
    ))

    return inner_parsecode,buildcall
end