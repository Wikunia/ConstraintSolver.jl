using Test
using ConstraintSolver
using JSON
using Random
using MathOptInterface, JuMP, Cbc, GLPK, Combinatorics

const MOI = MathOptInterface
const CS = ConstraintSolver
const MOIU = MOI.Utilities

CSTestOptimizer() = CS.Optimizer(logging = [])
CSJuMPTestOptimizer() = JuMP.optimizer_with_attributes(CS.Optimizer, "logging" => [])
cbc_optimizer = optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0)
CSCbcJuMPTestOptimizer() = JuMP.optimizer_with_attributes(CS.Optimizer, "logging" => [], "lp_optimizer" => cbc_optimizer)

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
