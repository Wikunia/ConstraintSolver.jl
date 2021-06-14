using Test
using ConstraintSolver
using JSON
using Random
using MathOptInterface, JuMP, Cbc, GLPK, Combinatorics
using ReferenceTests
using LinearAlgebra

const MOI = MathOptInterface
const CS = ConstraintSolver
const MOIU = MOI.Utilities

function CSTestOptimizer(; branch_strategy = :Auto)
    CS.Optimizer(logging = [], seed = 1, branch_strategy = branch_strategy)
end
function CSJuMPTestOptimizer(; branch_strategy = :Auto)
    JuMP.optimizer_with_attributes(
        CS.Optimizer,
        "logging" => [],
        "seed" => 4,
        "branch_strategy" => branch_strategy,
    )
end
cbc_optimizer = optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0)
function CSCbcJuMPTestOptimizer(; branch_strategy = :Auto)
    JuMP.optimizer_with_attributes(
        CS.Optimizer,
        "logging" => [],
        "lp_optimizer" => cbc_optimizer,
        "seed" => 2,
        "branch_strategy" => branch_strategy,
    )
end

macro test_macro_throws(errortype, m)
    # See https://discourse.julialang.org/t/test-throws-with-macros-after-pr-23533/5878
    :(@test_throws $(esc(errortype)) try
        @eval $m
    catch err
        throw(err.error)
    end)
end

"""
    test_string(arr::AbstractArray)

In Julia 1.0 string(arr) starts with Array{Int, 1} or something. In 1.5 it doesn't.
This function removes Array{...} and starts with `[`. Additionally all white spaces are removed.
"""
function test_string(arr::AbstractArray)
    s = string(arr)
    if startswith(s, "Array")
        p = first(findfirst("[", s))
        s = s[p:end]
    end
    s = replace(s, " " => "")
    return s
end

test_stime = time()

include("general.jl")
include("sudoku_fcts.jl")

include("docs.jl")
include("fcts.jl")
include("unit/index.jl")
include("options.jl")
include("moi.jl")
include("scheduling.jl")
include("constraints/table.jl")
include("constraints/xor.jl")
include("constraints/indicator.jl")
include("constraints/reified.jl")
include("constraints/equal_to.jl")
include("constraints/element1Dconst.jl")

include("lp_solver.jl")

include("steiner.jl")
include("stable_set.jl")
include("small_special.jl")
include("maximum_weight_matching.jl")
include("small_eq_sum_real.jl")
include("sudoku.jl")
include("str8ts.jl")
include("eternity.jl")
include("killer_sudoku.jl")
include("graph_color.jl")
println("Time for all tests $(time()-test_stime)")
