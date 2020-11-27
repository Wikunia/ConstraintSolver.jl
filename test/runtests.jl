using Test
using ConstraintSolver
using JSON
using Random
using MathOptInterface, JuMP, Cbc, GLPK, Combinatorics
using ReferenceTests

const MOI = MathOptInterface
const CS = ConstraintSolver
const MOIU = MOI.Utilities

CSTestOptimizer() = CS.Optimizer(logging = [], seed=1)
CSJuMPTestOptimizer() = JuMP.optimizer_with_attributes(CS.Optimizer, "logging" => [], "seed"=>1)
cbc_optimizer = optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0)
CSCbcJuMPTestOptimizer() = JuMP.optimizer_with_attributes(CS.Optimizer, "logging" => [], "seed"=>1, "lp_optimizer" => cbc_optimizer)

macro test_macro_throws(errortype, m)
    # See https://discourse.julialang.org/t/test-throws-with-macros-after-pr-23533/5878
    :(@test_throws $(esc(errortype)) try @eval $m catch err; throw(err.error) end)
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
include("constraints/table.jl")
include("constraints/indicator.jl")
include("constraints/reified.jl")

include("lp_solver.jl")

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
