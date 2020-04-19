using Test
using ConstraintSolver
using JSON
using MathOptInterface, JuMP, Cbc, GLPK, Combinatorics

const MOI = MathOptInterface
const CS = ConstraintSolver
const MOIU = MOI.Utilities

CSTestSolver() = CS.Optimizer(logging = [])
CSJuMPTestSolver() = JuMP.optimizer_with_attributes(CS.Optimizer, "logging" => [])

test_stime = time()
include("docs.jl")
include("fcts.jl")
include("options.jl")
include("moi.jl")
include("constraints/table.jl")

include("lp_solver.jl")

include("stable_set.jl")
include("sudoku_fcts.jl")
include("small_special.jl")
include("maximum_weight_matching.jl")
include("small_eq_sum_real.jl")
include("sudoku.jl")
include("str8ts.jl")
include("killer_sudoku.jl")
include("graph_color.jl")
println("Time for all tests $(time()-test_stime)")
