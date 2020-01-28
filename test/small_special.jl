@testset "Small special tests" begin
@testset "Sum" begin
    com = CS.ConstraintSolverModel()

    com_grid = Array{CS.Variable, 1}(undef, 8)
    com_grid[1] = CS.add_var!(com, 1, 9)
    com_grid[2] = CS.add_var!(com, 1, 9; fix=5)
    com_grid[3] = CS.add_var!(com, 1, 9)
    com_grid[4] = CS.add_var!(com, 1, 9)
    com_grid[5] = CS.add_var!(com, 1, 9)

    com_grid[6] = CS.add_var!(com, 1, 2)
    com_grid[7] = CS.add_var!(com, 3, 5)

    com_grid[8] = CS.add_var!(com, 3, 5)
    

    CS.rm!(com, com_grid[4], 5)
    CS.remove_above!(com, com_grid[5], 2)

    CS.add_constraint!(com, sum([com_grid[CartesianIndex(ind)] for ind in [1,2]]) == 11)
    CS.add_constraint!(com, sum([com_grid[CartesianIndex(ind)] for ind in [3,4]]) == 11)
    CS.add_constraint!(com, sum([com_grid[CartesianIndex(ind)] for ind in [2,5]]) ==  6)
    # testing coefficients from left and right
    CS.add_constraint!(com, com_grid[6]*1+2*com_grid[7] ==  7)
    CS.add_constraint!(com, com_grid[6]+com_grid[7]-com_grid[8] ==  0)
        
    options = Dict{Symbol, Any}()
    options[:backtrack] = false
    options[:keep_logs] = true

    options = CS.combine_options(options)
    status = CS.solve!(com, options)
    # remove without pruning
    CS.remove_above!(com, com_grid[3], 5)

    # should also work for a fixed variable
    @test CS.compress_var_string(com_grid[1]) == "6"

    str_output = CS.get_str_repr(com_grid)
    @test str_output[1] == "6, 5, 2:5, [2, 3, 4, 6, 7, 8, 9], 1, 1, 3, 4"

    com_grid_2D = [com_grid[1] com_grid[2]; com_grid[3] com_grid[4]]
    str_output = CS.get_str_repr(com_grid_2D)
    @test str_output[1] == "          6                    2:5          "
    @test str_output[2] == "          5           [2, 3, 4, 6, 7, 8, 9] "

    println(com_grid)

    @test status != :Infeasible
    @test CS.isfixed(com_grid[1])
    @test CS.value(com_grid[1]) == 6
    @test CS.isfixed(com_grid[5])
    @test CS.value(com_grid[5]) == 1
    @test !CS.has(com_grid[3], 6)

    @test CS.isfixed(com_grid[6])
    @test CS.value(com_grid[6]) == 1

    @test CS.isfixed(com_grid[7])
    @test CS.value(com_grid[7]) == 3

    @test CS.isfixed(com_grid[8])
    @test CS.value(com_grid[8]) == 4
end

@testset "Reordering sum constraint" begin
    com = CS.ConstraintSolverModel()

    x = CS.add_var!(com, 0, 9)
    y = CS.add_var!(com, 0, 9)
    z = CS.add_var!(com, 0, 9)

    c1 = 2x+3x == 5
    @test length(c1.indices) == 1
    @test c1.indices[1] == 1
    @test c1.fct.terms[1].coefficient == 5
    @test c1.set.value == 5
    
    CS.add_constraint!(com, 2x+3x == 5)
    CS.add_constraint!(com, 2x-3y+6+x == z)
    CS.add_constraint!(com, x+2 == z)
    CS.add_constraint!(com, z-2 == x)
    CS.add_constraint!(com, 2x+x == z+3y-6)

    options = CS.SolverOptions()
    status = CS.solve!(com, options)
    @test status == :Solved 
    @test CS.isfixed(x) && CS.value(x) == 1
    @test 2*CS.value(x)-3*CS.value(y)+6+CS.value(x) == CS.value(z)
    @test CS.value(x)+2 == CS.value(z)
end

@testset "Infeasible coeff sum" begin
    com = CS.ConstraintSolverModel()

    com_grid = Array{CS.Variable, 1}(undef, 3)
    com_grid[1] = CS.add_var!(com, 1, 9)
    com_grid[2] = CS.add_var!(com, 1, 9)
    com_grid[3] = CS.add_var!(com, 1, 9)
    
    CS.rm!(com, com_grid[2], 2)
    CS.rm!(com, com_grid[2], 3)
    CS.rm!(com, com_grid[2], 4)
    CS.rm!(com, com_grid[2], 6)
    CS.rm!(com, com_grid[2], 8)
        
    CS.add_constraint!(com, com_grid[2]*2+5*com_grid[1]+0*com_grid[3] == 21)
    
    options = Dict{Symbol, Any}()
    options[:backtrack] = true

    options = CS.combine_options(options)
    status = CS.solve!(com, options)
    @test status == :Infeasible
end

@testset "Negative coeff sum" begin
    com = CS.ConstraintSolverModel()

    com_grid = Array{CS.Variable, 1}(undef, 3)
    com_grid[1] = CS.add_var!(com, 1, 9)
    com_grid[2] = CS.add_var!(com, 1, 9)
    com_grid[3] = CS.add_var!(com, 1, 9)
    
    CS.remove_above!(com, com_grid[3], 3)

    CS.add_constraint!(com, sum([7,5,-10].*com_grid) == -13)
    
    options = Dict{Symbol, Any}()
    options[:backtrack] = true

    options = CS.combine_options(options)
    status = CS.solve!(com, options)

    @test status == :Solved
    @test CS.isfixed(com_grid[1]) && CS.value(com_grid[1]) == 1
    @test CS.isfixed(com_grid[2]) && CS.value(com_grid[2]) == 2
    @test CS.isfixed(com_grid[3]) && CS.value(com_grid[3]) == 3

    com = CS.ConstraintSolverModel()

    com_grid = Array{CS.Variable, 1}(undef, 3)
    com_grid[1] = CS.add_var!(com, 1, 5)
    com_grid[2] = CS.add_var!(com, 1, 2)
    com_grid[3] = CS.add_var!(com, 1, 9)
    
    CS.add_constraint!(com, sum([7,5,-10].*com_grid) == -13)
    
    options = Dict{Symbol, Any}()
    options[:backtrack] = true

    options = CS.combine_options(options)
    status = CS.solve!(com, options)
    @test status == :Solved
    @test CS.isfixed(com_grid[1]) && CS.value(com_grid[1]) == 1
    @test CS.isfixed(com_grid[2]) && CS.value(com_grid[2]) == 2
    @test CS.isfixed(com_grid[3]) && CS.value(com_grid[3]) == 3

    com = CS.ConstraintSolverModel()

    v1 = CS.add_var!(com, 1, 5)
    v2 = CS.add_var!(com, 5, 10)
    
    CS.add_constraint!(com, v1-v2 == 0)
    
    options = Dict{Symbol, Any}()
    options[:backtrack] = false

    options = CS.combine_options(options)
    status = CS.solve!(com, options)
    @test status == :Solved
    @test CS.isfixed(v1) && CS.value(v1) == 5
    @test CS.isfixed(v2) && CS.value(v2) == 5
end

@testset "Equal constraint" begin
    # nothing to do
    com = CS.ConstraintSolverModel()

    v1 = CS.add_var!(com, 1, 2; fix=2)
    v2 = CS.add_var!(com, 1, 2; fix=2)

    CS.add_constraint!(com, v1 == v2)

    options = Dict{Symbol, Any}()

    options = CS.combine_options(options)
    status = CS.solve!(com, options)

    @test status == :Solved
    @test !com.info.backtracked
    @test CS.isfixed(v1) && CS.value(v1) == 2
    @test CS.isfixed(v2) && CS.value(v2) == 2

    # normal
    com = CS.ConstraintSolverModel()

    v1 = CS.add_var!(com, 1, 2)
    v2 = CS.add_var!(com, 1, 2; fix=2)

    CS.add_constraint!(com, v1 == v2)

    options = Dict{Symbol, Any}()

    options = CS.combine_options(options)
    status = CS.solve!(com, options)

    @test status == :Solved
    @test !com.info.backtracked
    @test CS.isfixed(v1) && CS.value(v1) == 2
    @test CS.isfixed(v2) && CS.value(v2) == 2

    # set but infeasible
    com = CS.ConstraintSolverModel()

    v1 = CS.add_var!(com, 1, 2)
    v2 = CS.add_var!(com, 1, 2; fix=2)

    CS.add_constraint!(com, v1 == v2)
    CS.add_constraint!(com, CS.all_different([v1, v2]))

    options = Dict{Symbol, Any}()

    options = CS.combine_options(options)
    status = CS.solve!(com, options)

    @test status == :Infeasible
    @test !com.info.backtracked

    # set but infeasible reversed
    com = CS.ConstraintSolverModel()

    v1 = CS.add_var!(com, 1, 2)
    v2 = CS.add_var!(com, 1, 2; fix=2)

    CS.add_constraint!(com, v2 == v1)
    CS.add_constraint!(com, CS.all_different([v1, v2]))

    options = Dict{Symbol, Any}()

    options = CS.combine_options(options)
    status = CS.solve!(com, options)

    @test status == :Infeasible
    @test !com.info.backtracked

    # reversed
    com = CS.ConstraintSolverModel()

    v1 = CS.add_var!(com, 1, 2)
    v2 = CS.add_var!(com, 1, 2; fix=2)

    CS.add_constraint!(com, v2 == v1)

    options = Dict{Symbol, Any}()

    options = CS.combine_options(options)
    status = CS.solve!(com, options)

    @test status == :Solved
    @test !com.info.backtracked
    @test CS.isfixed(v1) && CS.value(v1) == 2
    @test CS.isfixed(v2) && CS.value(v2) == 2

    # test with more
    com = CS.ConstraintSolverModel()

    v1 = CS.add_var!(com, 1, 2)
    v2 = CS.add_var!(com, 1, 2; fix=2)
    v3 = CS.add_var!(com, 1, 2)
    v4 = CS.add_var!(com, 1, 2)

    CS.add_constraint!(com, v1 == v2)
    CS.add_constraint!(com, v1 == v4)
    CS.add_constraint!(com, v1 == v3)

    options = Dict{Symbol, Any}()

    options = CS.combine_options(options)
    status = CS.solve!(com, options)

    @test status == :Solved
    @test !com.info.backtracked
    @test CS.isfixed(v1) && CS.value(v1) == 2
    @test CS.isfixed(v2) && CS.value(v2) == 2
    @test CS.isfixed(v3) && CS.value(v3) == 2
    @test CS.isfixed(v4) && CS.value(v4) == 2
end

@testset "NotSolved or infeasible" begin
    # NotSolved without backtracking
    com = CS.ConstraintSolverModel()

    v1 = CS.add_var!(com, 1, 2)
    v2 = CS.add_var!(com, 1, 2)

    CS.add_constraint!(com, v2 == v1)

    options = Dict{Symbol, Any}()
    options[:backtrack] = false

    options = CS.combine_options(options)
    status = CS.solve!(com, options)

    @test status == :NotSolved
    @test !com.info.backtracked

    # Infeasible without backtracking
    com = CS.ConstraintSolverModel()

    v1 = CS.add_var!(com, 1, 2; fix=1)
    v2 = CS.add_var!(com, 1, 2; fix=2)

    CS.add_constraint!(com, v2 == v1)

    options = Dict{Symbol, Any}()

    options = CS.combine_options(options)
    status = CS.solve!(com, options)

    @test status == :Infeasible
    @test !com.info.backtracked

    # Infeasible without backtracking reverse
    com = CS.ConstraintSolverModel()

    v1 = CS.add_var!(com, 1, 2; fix=1)
    v2 = CS.add_var!(com, 1, 2; fix=2)

    CS.add_constraint!(com, v1 == v2)

    options = Dict{Symbol, Any}()

    options = CS.combine_options(options)
    status = CS.solve!(com, options)

    @test status == :Infeasible
    @test !com.info.backtracked
end

@testset "Test Equals()" begin
    # test using equal
    com = CS.ConstraintSolverModel()

    v1 = CS.add_var!(com, 1, 2)
    v2 = CS.add_var!(com, 1, 2; fix=2)
    v3 = CS.add_var!(com, 1, 2)
    v4 = CS.add_var!(com, 1, 2)

    CS.add_constraint!(com, CS.equal([v1,v2,v3,v4]))

    options = Dict{Symbol, Any}()

    options = CS.combine_options(options)
    status = CS.solve!(com, options)

    @test status == :Solved
    @test !com.info.backtracked
    @test CS.isfixed(v1) && CS.value(v1) == 2
    @test CS.isfixed(v2) && CS.value(v2) == 2
    @test CS.isfixed(v3) && CS.value(v3) == 2
    @test CS.isfixed(v4) && CS.value(v4) == 2
end

@testset "Test Equals() NotSolved/Infeasible" begin
    # test using equal
    com = CS.ConstraintSolverModel()

    v1 = CS.add_var!(com, 1, 2)
    v2 = CS.add_var!(com, 1, 2; fix=2)
    v3 = CS.add_var!(com, 1, 2)
    v4 = CS.add_var!(com, 1, 3; fix=3)

    CS.add_constraint!(com, CS.equal([v1,v2,v3,v4]))

    options = Dict{Symbol, Any}()

    options = CS.combine_options(options)
    status = CS.solve!(com, options)

    @test status == :Infeasible
    @test !com.info.backtracked
    @test CS.isfixed(v2) && CS.value(v2) == 2
    @test CS.isfixed(v4) && CS.value(v4) == 3

    # test using equal
    com = CS.ConstraintSolverModel()

    v1 = CS.add_var!(com, 1, 2)
    v2 = CS.add_var!(com, 1, 2)
    v3 = CS.add_var!(com, 1, 2)
    v4 = CS.add_var!(com, 1, 2)

    CS.add_constraint!(com, CS.equal([v1,v2,v3,v4]))

    options = Dict{Symbol, Any}()
    options[:backtrack] = false

    options = CS.combine_options(options)
    status = CS.solve!(com, options)

    @test status == :NotSolved
    @test !com.info.backtracked
    @test !CS.isfixed(v2)
    @test !CS.isfixed(v4)
end

@testset "Graph coloring small" begin
    com = CS.ConstraintSolverModel()

    # cover from numberphile video
    v1 = CS.add_var!(com, 1, 4)
    v2 = CS.add_var!(com, 1, 4)
    v3 = CS.add_var!(com, 1, 4)
    v4 = CS.add_var!(com, 1, 4)
    v5 = CS.add_var!(com, 1, 4)
    v6 = CS.add_var!(com, 1, 4)
    v7 = CS.add_var!(com, 1, 4)
    v8 = CS.add_var!(com, 1, 4)
    v9 = CS.add_var!(com, 1, 4)

    CS.add_constraint!(com, v1 != v2)
    CS.add_constraint!(com, v1 != v3)
    CS.add_constraint!(com, v1 != v4)
    CS.add_constraint!(com, v1 != v5)
    CS.add_constraint!(com, v2 != v3)
    CS.add_constraint!(com, v2 != v5)
    CS.add_constraint!(com, v4 != v3)
    CS.add_constraint!(com, v4 != v5)
    CS.add_constraint!(com, v2 != v6)
    CS.add_constraint!(com, v2 != v7)
    CS.add_constraint!(com, v3 != v7)
    CS.add_constraint!(com, v3 != v8)
    CS.add_constraint!(com, v4 != v8)
    CS.add_constraint!(com, v4 != v9)
    CS.add_constraint!(com, v5 != v9)
    CS.add_constraint!(com, v5 != v6)
    CS.add_constraint!(com, v5 != v6)
    CS.add_constraint!(com, v6 != v9)
    CS.add_constraint!(com, v6 != v9)
    CS.add_constraint!(com, v6 != v7)
    CS.add_constraint!(com, v8 != v9)
    CS.add_constraint!(com, v8 != v7)

    options = Dict{Symbol, Any}()

    options = CS.combine_options(options)
    status = CS.solve!(com, options)

    @test status == :Solved
    @test com.info.backtracked

    # Infeasible with 3 colors
    com = CS.ConstraintSolverModel()
    v1 = CS.add_var!(com, 1, 3)
    v2 = CS.add_var!(com, 1, 3)
    v3 = CS.add_var!(com, 1, 3)
    v4 = CS.add_var!(com, 1, 3)
    v5 = CS.add_var!(com, 1, 3)
    v6 = CS.add_var!(com, 1, 3)
    v7 = CS.add_var!(com, 1, 3)
    v8 = CS.add_var!(com, 1, 3)
    v9 = CS.add_var!(com, 1, 3)

    CS.add_constraint!(com, v1 != v2)
    CS.add_constraint!(com, v1 != v3)
    CS.add_constraint!(com, v1 != v4)
    CS.add_constraint!(com, v1 != v5)
    CS.add_constraint!(com, v2 != v3)
    CS.add_constraint!(com, v2 != v5)
    CS.add_constraint!(com, v4 != v3)
    CS.add_constraint!(com, v4 != v5)
    CS.add_constraint!(com, v2 != v6)
    CS.add_constraint!(com, v2 != v7)
    CS.add_constraint!(com, v3 != v7)
    CS.add_constraint!(com, v3 != v8)
    CS.add_constraint!(com, v4 != v8)
    CS.add_constraint!(com, v4 != v9)
    CS.add_constraint!(com, v5 != v9)
    CS.add_constraint!(com, v5 != v6)
    CS.add_constraint!(com, v5 != v6)
    CS.add_constraint!(com, v6 != v9)
    CS.add_constraint!(com, v6 != v9)
    CS.add_constraint!(com, v6 != v7)
    CS.add_constraint!(com, v8 != v9)
    CS.add_constraint!(com, v8 != v7)

    options = Dict{Symbol, Any}()

    options = CS.combine_options(options)
    status = CS.solve!(com, options)

    @test status == :Infeasible
    @test com.info.backtracked


    # very simple
    com = CS.ConstraintSolverModel()

    v1 = CS.add_var!(com, 1, 2; fix=1)
    v2 = CS.add_var!(com, 1, 2)

    CS.add_constraint!(com, v1 != v2)

    options = Dict{Symbol, Any}()
    options[:backtrack] = false

    options = CS.combine_options(options)
    status = CS.solve!(com, options)

    @test status == :Solved
    @test !com.info.backtracked
    @test CS.isfixed(v1) && CS.value(v1) == 1
    @test CS.isfixed(v2) && CS.value(v2) == 2

    # infeasible at beginning
    com = CS.ConstraintSolverModel()

    v1 = CS.add_var!(com, 1, 2; fix=1)
    v2 = CS.add_var!(com, 1, 2; fix=1)

    CS.add_constraint!(com, v1 != v2)

    options = Dict{Symbol, Any}()
    options[:backtrack] = false

    options = CS.combine_options(options)
    status = CS.solve!(com, options)

    @test status == :Infeasible
    @test !com.info.backtracked

    # Error not implemented
    com = CS.ConstraintSolverModel()

    v1 = CS.add_var!(com, 1, 2; fix=1)
    v2 = CS.add_var!(com, 1, 2)
    v3 = CS.add_var!(com, 1, 2)

    @test_throws ErrorException CS.add_constraint!(com, !CS.equal([v1,v2,v3]))
    @test_throws ErrorException CS.add_constraint!(com, !CS.all_different([v1,v2,v3]))
end

@testset "Fix variable" begin
    m = Model(with_optimizer(CS.Optimizer))
    @variable(m, 1 <= x <= 9, Int)
    @variable(m, y == 2, Int)
    # should just return optimal with any 1-9 for x and y is fixed
    optimize!(m)

    @test JuMP.termination_status(m) == MOI.OPTIMAL
    @test 1 <= JuMP.value(x) <= 9 && length(CS.values(m, x)) == 1
    @test JuMP.value(y) == 2

    m = Model(with_optimizer(CS.Optimizer))
    @variable(m, 1 <= x <= 9, Int)
    @variable(m, y == 2, Int)
    @constraint(m, x+y == 10)
    optimize!(m)
    
    @test JuMP.termination_status(m) == MOI.OPTIMAL
    @test JuMP.value(x) == 8
    @test JuMP.value(y) == 2
end

@testset "Not supported constraints" begin
    m = Model(with_optimizer(CS.Optimizer))
    # must be an Integer upper bound
    @variable(m, 1 <= x[1:5] <= NaN, Int)
    @test_throws ErrorException optimize!(m)

    m = Model(with_optimizer(CS.Optimizer))
    # must be an Integer lower bound
    @variable(m, NaN <= x[1:5] <= 2, Int)
    @test_throws ErrorException optimize!(m)

    m = Model(with_optimizer(CS.Optimizer))
    @variable(m, 1 <= x[1:5] <= 2, Int)
    # constraint not supported
    @constraint(m, x[1]-x[2] != 2)
    @test_throws ErrorException optimize!(m)

    m = Model(with_optimizer(CS.Optimizer))
    @variable(m, 1 <= x[1:5] <= 2, Int)
    # constraint not supported
    @constraint(m, x[1]-x[2]-x[3] != 0)
    @test_throws ErrorException optimize!(m)

    m = Model(with_optimizer(CS.Optimizer))
    @variable(m, 1 <= x[1:5] <= 2, Int)
    # constraint currently not supported
    @constraint(m, 2x[1]-x[2] != 0)
    @test_throws ErrorException optimize!(m)

    m = Model(with_optimizer(CS.Optimizer))
    @variable(m, 1 <= x[1:5] <= 2, Int)
    # constraint not supported
    @constraint(m, x[1] <= x[2]-2)
    @test_throws ErrorException optimize!(m)

    m = Model(with_optimizer(CS.Optimizer))
    @variable(m, 1 <= x[1:5] <= 2, Int)
    # constraint not supported
    @constraint(m, x[1]-x[2]-x[3] <= 0)
    @test_throws ErrorException optimize!(m)

    m = Model(with_optimizer(CS.Optimizer))
    @variable(m, 1 <= x[1:5] <= 2, Int)
    # constraint currently not supported
    @constraint(m, 2x[1]-x[2] <= 0)
    @test_throws ErrorException optimize!(m)
end

@testset "Bipartite matching" begin
    match = CS.bipartite_cardinality_matching([2,1,3],[1,2,3], 3, 3)
    @test match.weight == 3
    @test match.match == [2,1,3]
end

@testset "Not equal constant" begin
    m = Model(with_optimizer(CS.Optimizer))

    @variable(m, 1 <= x <= 10, Int)
    @constraint(m, x != 2-1) # != 1
    @constraint(m, 2x != 4) # != 2
    @constraint(m, π/3*x != π) # != 3
    @constraint(m, 2.2x != 8.8) # != 4
    @objective(m, Min, x)
    optimize!(m)

    @test JuMP.objective_value(m) == 5
    @test JuMP.termination_status(m) == MOI.OPTIMAL
    @test JuMP.value(x) == 5
    @test length(CS.values(m,x)) == 1 # the value should be fixed
end

end