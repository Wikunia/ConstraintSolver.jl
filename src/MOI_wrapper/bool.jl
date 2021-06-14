const BOOL_VALS = Union{Val{:(&&)}, Val{:(||)}, Val{:(⊻)}}

bool_val_to_set(::Val{:(&&)}) = AndSet 
bool_val_to_set(::Val{:(||)}) = OrSet 
bool_val_to_set(::Val{:(⊻)}) = XorSet 

function _build_bool_constraint(
    _error::Function,
    lhs,
    rhs,
    set_type
)
    lhs_set = JuMP.moi_set(lhs)
    rhs_set = JuMP.moi_set(rhs)

    lhs_jump_func = JuMP.jump_function(lhs)
    rhs_jump_func = JuMP.jump_function(rhs)

    lhs_func = JuMP.moi_function(lhs)
    rhs_func = JuMP.moi_function(rhs)

    func = [lhs_jump_func..., rhs_jump_func...]
    return JuMP.VectorConstraint(
        func, set_type{typeof(lhs_func), typeof(rhs_func)}(lhs_set, rhs_set)
    )
end

function parse_bool_constraint(_error, bool_val::BOOL_VALS, lhs, rhs)
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

    bool_set = bool_val_to_set(bool_val)

    buildcall = :($(esc(:(CS._build_bool_constraint)))(
        $_error,
        $lhs_buildcall,
        $rhs_buildcall,
        $bool_set
    ))
    return vectorized, complete_parsecode, buildcall
end

function JuMP.parse_constraint_head(_error::Function, bool_val::BOOL_VALS, lhs, rhs)
    return parse_bool_constraint(_error, bool_val, lhs, rhs)
end

function JuMP.parse_one_operator_constraint(_error::Function, vectorized::Bool, bool_val::BOOL_VALS, lhs, rhs)
    @assert !vectorized
    v,c,b = parse_bool_constraint(_error, bool_val, lhs, rhs)
    return c,b
end