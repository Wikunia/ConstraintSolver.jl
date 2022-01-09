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

"""
    transform_binary_expr(sym::Symbol)

Transform a symbol to a constraint of the form Symbol == 1
"""
function transform_binary_expr(sym::Symbol)
    return :($sym == 1) 
end

"""
    transform_binary_expr(expr::Expr)

Transform a ! (symbol) to a constraint of the form Symbol == 0
or x[...] to x[...] == 1 
"""
function transform_binary_expr(expr::Expr)
    if expr.head == :ref
        expr = :($expr == 1)
    elseif expr.head == :call && expr.args[1] == :! && (expr.args[2] isa Symbol || expr.args[2].head == :ref)
        expr = :($(expr.args[2]) == 0)
    end
    return expr
end

function parse_bool_constraint(_error, bool_val::BOOL_VALS, lhs, rhs)
    _error1 = deepcopy(_error)
    # allow a || b instead of a == 1 || b == 1
    lhs = transform_binary_expr(lhs)
    
    lhs_vectorized, lhs_parsecode, lhs_buildcall =
        JuMP.parse_constraint_expr(_error, lhs)

    if lhs_vectorized
        _error("`$(lhs)` should be non vectorized. There is currently no vectorized support for `and` constraints. Please open an issue at ConstraintSolver.jl")
    end

    rhs = transform_binary_expr(rhs)
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