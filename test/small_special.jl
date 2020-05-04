@testset "Small special tests" begin
    @testset "Sum" begin
        com = CS.ConstraintSolverModel()

        com_grid = Array{CS.Variable,1}(undef, 8)
        com_grid[1] = CS.add_var!(com, 1, 9)
        com_grid[2] = CS.add_var!(com, 1, 9; fix = 5)
        com_grid[3] = CS.add_var!(com, 1, 9)
        com_grid[4] = CS.add_var!(com, 1, 9)
        com_grid[5] = CS.add_var!(com, 1, 9)

        com_grid[6] = CS.add_var!(com, 1, 2)
        com_grid[7] = CS.add_var!(com, 3, 5)

        com_grid[8] = CS.add_var!(com, 3, 5)


        CS.rm!(com, com_grid[4], 5)
        CS.remove_above!(com, com_grid[5], 2)

        CS.add_constraint!(
            com,
            sum([com_grid[CartesianIndex(ind)] for ind in [1, 2]]) == 11,
        )
        CS.add_constraint!(
            com,
            sum([com_grid[CartesianIndex(ind)] for ind in [3, 4]]) == 11,
        )
        CS.add_constraint!(com, sum([com_grid[CartesianIndex(ind)] for ind in [2, 5]]) == 6)
        # testing coefficients from left and right
        CS.add_constraint!(com, com_grid[6] * 1 + 2 * com_grid[7] == 7)
        CS.add_constraint!(com, com_grid[6] + com_grid[7] - com_grid[8] == 0)

        options = Dict{Symbol,Any}()
        options[:logging] = Symbol[]
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

        c1 = 2x + 3x == 5
        @test length(c1.std.indices) == 1
        @test c1.std.indices[1] == 1
        @test c1.std.fct.terms[1].coefficient == 5
        @test c1.std.set.value == 5

        CS.add_constraint!(com, 2x + 3x == 5)
        CS.add_constraint!(com, 2x - 3y + 6 + x == z)
        CS.add_constraint!(com, x + 2 == z)
        CS.add_constraint!(com, z - 2 == x)
        CS.add_constraint!(com, 2x + x == z + 3y - 6)

        options = CS.SolverOptions()
        status = CS.solve!(com, options)
        @test status == :Solved
        @test CS.isfixed(x) && CS.value(x) == 1
        @test 2 * CS.value(x) - 3 * CS.value(y) + 6 + CS.value(x) == CS.value(z)
        @test CS.value(x) + 2 == CS.value(z)
    end

    @testset "Infeasible coeff sum" begin
        com = CS.ConstraintSolverModel()

        com_grid = Array{CS.Variable,1}(undef, 3)
        com_grid[1] = CS.add_var!(com, 1, 9)
        com_grid[2] = CS.add_var!(com, 1, 9)
        com_grid[3] = CS.add_var!(com, 1, 9)

        CS.rm!(com, com_grid[2], 2)
        CS.rm!(com, com_grid[2], 3)
        CS.rm!(com, com_grid[2], 4)
        CS.rm!(com, com_grid[2], 6)
        CS.rm!(com, com_grid[2], 8)

        CS.add_constraint!(com, com_grid[2] * 2 + 5 * com_grid[1] + 0 * com_grid[3] == 21)

        options = Dict{Symbol,Any}()
        options[:backtrack] = true
        options[:logging] = []

        options = CS.combine_options(options)
        status = CS.solve!(com, options)
        @test status == :Infeasible
    end

    @testset "Negative coeff sum" begin
        com = CS.ConstraintSolverModel()

        com_grid = Array{CS.Variable,1}(undef, 3)
        com_grid[1] = CS.add_var!(com, 1, 9)
        com_grid[2] = CS.add_var!(com, 1, 9)
        com_grid[3] = CS.add_var!(com, 1, 9)

        CS.remove_above!(com, com_grid[3], 3)

        CS.add_constraint!(com, sum([7, 5, -10] .* com_grid) == -13)

        options = Dict{Symbol,Any}()
        options[:logging] = []
        options[:backtrack] = true

        options = CS.combine_options(options)
        status = CS.solve!(com, options)

        @test status == :Solved
        @test CS.isfixed(com_grid[1]) && CS.value(com_grid[1]) == 1
        @test CS.isfixed(com_grid[2]) && CS.value(com_grid[2]) == 2
        @test CS.isfixed(com_grid[3]) && CS.value(com_grid[3]) == 3

        com = CS.ConstraintSolverModel()

        com_grid = Array{CS.Variable,1}(undef, 3)
        com_grid[1] = CS.add_var!(com, 1, 5)
        com_grid[2] = CS.add_var!(com, 1, 2)
        com_grid[3] = CS.add_var!(com, 1, 9)

        CS.add_constraint!(com, sum([7, 5, -10] .* com_grid) == -13)

        options = Dict{Symbol,Any}()
        options[:backtrack] = true
        options[:logging] = []

        options = CS.combine_options(options)
        status = CS.solve!(com, options)
        @test status == :Solved
        @test CS.isfixed(com_grid[1]) && CS.value(com_grid[1]) == 1
        @test CS.isfixed(com_grid[2]) && CS.value(com_grid[2]) == 2
        @test CS.isfixed(com_grid[3]) && CS.value(com_grid[3]) == 3

        com = CS.ConstraintSolverModel()

        v1 = CS.add_var!(com, 1, 5)
        v2 = CS.add_var!(com, 5, 10)

        CS.add_constraint!(com, v1 - v2 == 0)

        options = Dict{Symbol,Any}()
        options[:backtrack] = false
        options[:logging] = []

        options = CS.combine_options(options)
        status = CS.solve!(com, options)
        @test status == :Solved
        @test CS.isfixed(v1) && CS.value(v1) == 5
        @test CS.isfixed(v2) && CS.value(v2) == 5
    end

    @testset "Equal constraint" begin
        # nothing to do
        com = CS.ConstraintSolverModel()

        v1 = CS.add_var!(com, 1, 2; fix = 2)
        v2 = CS.add_var!(com, 1, 2; fix = 2)

        CS.add_constraint!(com, v1 == v2)

        options = Dict{Symbol,Any}()
        options[:logging] = []

        options = CS.combine_options(options)
        status = CS.solve!(com, options)

        @test status == :Solved
        @test !com.info.backtracked
        @test CS.isfixed(v1) && CS.value(v1) == 2
        @test CS.isfixed(v2) && CS.value(v2) == 2

        # normal
        com = CS.ConstraintSolverModel()

        v1 = CS.add_var!(com, 1, 2)
        v2 = CS.add_var!(com, 1, 2; fix = 2)

        CS.add_constraint!(com, v1 == v2)

        options = Dict{Symbol,Any}()
        options[:logging] = []

        options = CS.combine_options(options)
        status = CS.solve!(com, options)

        @test status == :Solved
        @test !com.info.backtracked
        @test CS.isfixed(v1) && CS.value(v1) == 2
        @test CS.isfixed(v2) && CS.value(v2) == 2

        # set but infeasible
        com = CS.ConstraintSolverModel()

        v1 = CS.add_var!(com, 1, 2)
        v2 = CS.add_var!(com, 1, 2; fix = 2)

        CS.add_constraint!(com, v1 == v2)
        CS.add_constraint!(com, CS.all_different([v1, v2]))

        options = Dict{Symbol,Any}()
        options[:logging] = []

        options = CS.combine_options(options)
        status = CS.solve!(com, options)

        @test status == :Infeasible
        @test !com.info.backtracked

        # set but infeasible reversed
        com = CS.ConstraintSolverModel()

        v1 = CS.add_var!(com, 1, 2)
        v2 = CS.add_var!(com, 1, 2; fix = 2)

        CS.add_constraint!(com, v2 == v1)
        CS.add_constraint!(com, CS.all_different([v1, v2]))

        options = Dict{Symbol,Any}()
        options[:logging] = []

        options = CS.combine_options(options)
        status = CS.solve!(com, options)

        @test status == :Infeasible
        @test !com.info.backtracked

        # reversed
        com = CS.ConstraintSolverModel()

        v1 = CS.add_var!(com, 1, 2)
        v2 = CS.add_var!(com, 1, 2; fix = 2)

        CS.add_constraint!(com, v2 == v1)

        options = Dict{Symbol,Any}()
        options[:logging] = []

        options = CS.combine_options(options)
        status = CS.solve!(com, options)

        @test status == :Solved
        @test !com.info.backtracked
        @test CS.isfixed(v1) && CS.value(v1) == 2
        @test CS.isfixed(v2) && CS.value(v2) == 2

        # test with more
        com = CS.ConstraintSolverModel()

        v1 = CS.add_var!(com, 1, 2)
        v2 = CS.add_var!(com, 1, 2; fix = 2)
        v3 = CS.add_var!(com, 1, 2)
        v4 = CS.add_var!(com, 1, 2)

        CS.add_constraint!(com, v1 == v2)
        CS.add_constraint!(com, v1 == v4)
        CS.add_constraint!(com, v1 == v3)

        options = Dict{Symbol,Any}()
        options[:logging] = []

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

        options = Dict{Symbol,Any}()
        options[:backtrack] = false
        options[:logging] = []

        options = CS.combine_options(options)
        status = CS.solve!(com, options)

        @test status == :NotSolved
        @test !com.info.backtracked

        # Infeasible without backtracking
        com = CS.ConstraintSolverModel()

        v1 = CS.add_var!(com, 1, 2; fix = 1)
        v2 = CS.add_var!(com, 1, 2; fix = 2)

        CS.add_constraint!(com, v2 == v1)

        options = Dict{Symbol,Any}()
        options[:logging] = []

        options = CS.combine_options(options)
        status = CS.solve!(com, options)

        @test status == :Infeasible
        @test !com.info.backtracked

        # Infeasible without backtracking reverse
        com = CS.ConstraintSolverModel()

        v1 = CS.add_var!(com, 1, 2; fix = 1)
        v2 = CS.add_var!(com, 1, 2; fix = 2)

        CS.add_constraint!(com, v1 == v2)

        options = Dict{Symbol,Any}()
        options[:logging] = []

        options = CS.combine_options(options)
        status = CS.solve!(com, options)

        @test status == :Infeasible
        @test !com.info.backtracked
    end

    @testset "Test Equals()" begin
        # test using equal
        com = CS.ConstraintSolverModel()

        v1 = CS.add_var!(com, 1, 2)
        v2 = CS.add_var!(com, 1, 2; fix = 2)
        v3 = CS.add_var!(com, 1, 2)
        v4 = CS.add_var!(com, 1, 2)

        CS.add_constraint!(com, CS.equal([v1, v2, v3, v4]))

        options = Dict{Symbol,Any}()
        options[:logging] = []

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
        v2 = CS.add_var!(com, 1, 2; fix = 2)
        v3 = CS.add_var!(com, 1, 2)
        v4 = CS.add_var!(com, 1, 3; fix = 3)

        CS.add_constraint!(com, CS.equal([v1, v2, v3, v4]))

        options = Dict{Symbol,Any}()
        options[:logging] = []

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

        CS.add_constraint!(com, CS.equal([v1, v2, v3, v4]))

        options = Dict{Symbol,Any}()
        options[:backtrack] = false
        options[:logging] = []

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

        options = Dict{Symbol,Any}()
        options[:logging] = []

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

        options = Dict{Symbol,Any}()
        options[:logging] = []

        options = CS.combine_options(options)
        status = CS.solve!(com, options)

        @test status == :Infeasible
        @test com.info.backtracked


        # very simple
        com = CS.ConstraintSolverModel()

        v1 = CS.add_var!(com, 1, 2; fix = 1)
        v2 = CS.add_var!(com, 1, 2)

        CS.add_constraint!(com, v1 != v2)

        options = Dict{Symbol,Any}()
        options[:backtrack] = false
        options[:logging] = []

        options = CS.combine_options(options)
        status = CS.solve!(com, options)

        @test status == :Solved
        @test !com.info.backtracked
        @test CS.isfixed(v1) && CS.value(v1) == 1
        @test CS.isfixed(v2) && CS.value(v2) == 2

        # infeasible at beginning
        com = CS.ConstraintSolverModel()

        v1 = CS.add_var!(com, 1, 2; fix = 1)
        v2 = CS.add_var!(com, 1, 2; fix = 1)

        CS.add_constraint!(com, v1 != v2)

        options = Dict{Symbol,Any}()
        options[:backtrack] = false
        options[:logging] = []

        options = CS.combine_options(options)
        status = CS.solve!(com, options)

        @test status == :Infeasible
        @test !com.info.backtracked

        # Error not implemented
        com = CS.ConstraintSolverModel()

        v1 = CS.add_var!(com, 1, 2; fix = 1)
        v2 = CS.add_var!(com, 1, 2)
        v3 = CS.add_var!(com, 1, 2)

        @test_throws ErrorException CS.add_constraint!(com, !CS.equal([v1, v2, v3]))
    end

    @testset "Fix variable" begin
        m = Model(CSJuMPTestSolver())
        @variable(m, 1 <= x <= 9, Int)
        @variable(m, y == 2, Int)
        # should just return optimal with any 1-9 for x and y is fixed
        optimize!(m)

        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test 1 <= JuMP.value(x) <= 9 && length(CS.values(m, x)) == 1
        @test JuMP.value(y) == 2

        m = Model(CSJuMPTestSolver())
        @variable(m, 1 <= x <= 9, Int)
        @variable(m, y == 2, Int)
        @constraint(m, x + y == 10)
        optimize!(m)

        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.value(x) == 8
        @test JuMP.value(y) == 2
    end

    @testset "LessThan constraints JuMP" begin
        m = Model(CSJuMPTestSolver())
        @variable(m, 1 <= x[1:5] <= 9, Int)
        @constraint(m, sum(x) <= 25)
        @constraint(m, sum(x) >= 20)
        weights = [1, 2, 3, 4, 5]
        @objective(m, Max, sum(weights .* x))
        optimize!(m)

        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.value.(x) == [1, 1, 5, 9, 9]
        @test JuMP.objective_value(m) == 99

        # minimize
        m = Model(CSJuMPTestSolver())
        @variable(m, 1 <= x[1:5] <= 9, Int)
        @constraint(m, sum(x) <= 25)
        @constraint(m, sum(x) >= 20)
        weights = [1, 2, 3, 4, 5]
        @objective(m, Min, sum(weights .* x))
        optimize!(m)

        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.value.(x) == [9, 8, 1, 1, 1]
        @test JuMP.objective_value(m) == 37

        # minimize with negative and positive real weights
        m = Model(CSJuMPTestSolver())
        @variable(m, 1 <= x[1:5] <= 9, Int)
        @constraint(m, sum(x) <= 25)
        weights = [-0.1, 0.2, -0.3, 0.4, 0.5]
        @constraint(m, sum(x[i] for i = 1:5 if weights[i] > 0) >= 15)
        @objective(m, Min, sum(weights .* x))
        optimize!(m)

        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.value.(x) == [1, 9, 9, 5, 1]
        @test JuMP.objective_value(m) ≈ 1.5
    end

    @testset "LessThan constraints CS" begin
        com = CS.ConstraintSolverModel()

        x = [CS.add_var!(com, 1, 9) for i = 1:5]
        CS.add_constraint!(com, sum(x) <= 25)
        CS.add_constraint!(com, sum(x) >= 20)
        CS.add_constraint!(com, x[1] + x[2] >= x[3])
        CS.add_constraint!(com, x[1] - x[2] <= x[3])
        CS.add_constraint!(com, x[1] + x[2] >= x[4] + x[5])

        options = Dict{Symbol,Any}()
        options[:logging] = []

        options = CS.combine_options(options)

        status = CS.solve!(com, options)

        @test status == :Solved
        @test 20 <= sum(CS.value.(x)) <= 25
        x_vals = CS.value.(x)
        @test x_vals[1] + x_vals[2] >= x_vals[3]
        @test x_vals[1] - x_vals[2] <= x_vals[3]
        @test x_vals[1] + x_vals[2] >= x_vals[4] + x_vals[5]
    end

    @testset "Knapsack problems" begin
        m = Model(CSJuMPTestSolver())

        @variable(m, 1 <= x[1:5] <= 9, Int)
        @constraint(m, sum(x) <= 25)
        @constraint(m, x[2] + 1.2 * x[4] - x[5] <= 12)
        weights = [1.2, 3.0, -0.3, -5.2, 2.7]
        @objective(m, Max, dot(weights, x))

        optimize!(m)

        @test JuMP.termination_status(m) == MOI.OPTIMAL
        x_vals = JuMP.value.(x)
        @test x_vals[1] ≈ 5
        @test x_vals[2] ≈ 9
        @test x_vals[3] ≈ 1
        @test x_vals[4] ≈ 1
        @test x_vals[5] ≈ 9
        @test JuMP.objective_value(m) ≈ 51.8

        # less variables in the objective
        m = Model(CSJuMPTestSolver())

        @variable(m, 1 <= x[1:5] <= 9, Int)
        @constraint(m, sum(x) <= 25)
        @constraint(m, x[2] + 1.2 * x[4] - x[5] <= 12)
        @constraint(m, -x[3] - 1.2 * x[4] + x[5] <= 12)
        weights = [1.2, 3.0, -0.3, -5.2, 2.7]
        @objective(m, Max, x[3] + 2.7 * x[4] - x[1])

        optimize!(m)

        @test JuMP.termination_status(m) == MOI.OPTIMAL
        x_vals = JuMP.value.(x)
        @test sum(x_vals) <= 25
        @test x_vals[2] + 1.2 * x_vals[4] - x_vals[5] <= 12
        @test JuMP.objective_value(m) ≈ 32.3

        # minimize
        m = Model(CSJuMPTestSolver())

        @variable(m, 1 <= x[1:5] <= 9, Int)
        @constraint(m, sum(x) >= 25)
        @constraint(m, x[2] + 1.2 * x[4] >= 12)
        weights = [1.2, 3.0, 0.3, 5.2, 2.7]
        @objective(m, Min, dot(weights, x))

        optimize!(m)

        @test JuMP.termination_status(m) == MOI.OPTIMAL
        x_vals = JuMP.value.(x)
        @test x_vals[1] ≈ 3
        @test x_vals[2] ≈ 9
        @test x_vals[3] ≈ 9
        @test x_vals[4] ≈ 3
        @test x_vals[5] ≈ 1
        @test JuMP.objective_value(m) ≈ 51.6

        # minimize only part of the weights and some are negative
        m = Model(CSJuMPTestSolver())

        @variable(m, 1 <= x[1:5] <= 9, Int)
        @constraint(m, sum(x) >= 25)
        @constraint(m, x[2] + 1.2 * x[4] - x[1] >= 12)
        @constraint(m, x[5] <= 7)
        @objective(m, Min, 3 * x[2] + 5 * x[1] - 2 * x[3])

        optimize!(m)

        @test JuMP.termination_status(m) == MOI.OPTIMAL
        x_vals = JuMP.value.(x)
        @test x_vals[1] ≈ 1
        @test x_vals[2] ≈ 3
        @test x_vals[3] ≈ 9
        @test x_vals[4] ≈ 9
        @test sum(x_vals) >= 25
        @test JuMP.objective_value(m) ≈ -4

        m = Model(CSJuMPTestSolver())
        @variable(m, 1 <= x[1:5] <= 9, Int)
        @constraint(m, sum(x) <= 25)
        @constraint(m, -x[1] - x[2] - x[3] + x[4] + x[5] >= 5)
        weights = [-1, 2, 3, 4, 5]
        @objective(m, Min, sum(weights[1:3] .* x[1:3]))

        optimize!(m)

        x_vals = JuMP.value.(x)
        @test sum(x_vals) <= 25
        @test -x_vals[1] - x_vals[2] - x_vals[3] + x_vals[4] + x_vals[5] >= 5
        @test JuMP.objective_value(m) ≈ -3
    end

    @testset "Not supported constraints" begin
        m = Model(CSJuMPTestSolver())
        # must be an Integer upper bound
        @variable(m, 1 <= x[1:5] <= NaN, Int)
        @test_throws ErrorException optimize!(m)

        m = Model(CSJuMPTestSolver())
        # must be an Integer lower bound
        @variable(m, NaN <= x[1:5] <= 2, Int)
        @test_throws ErrorException optimize!(m)

        m = Model(CSJuMPTestSolver())
        @variable(m, 1 <= x[1:5] <= 2, Int)

        m = Model(CSJuMPTestSolver())
        @variable(m, 1 <= x[1:5] <= 2, Int)

        m = Model(CSJuMPTestSolver())
        @variable(m, 1 <= x[1:5] <= 2, Int)
    end

    @testset "Bipartite matching" begin
        match = CS.bipartite_cardinality_matching([2, 1, 3], [1, 2, 3], 3, 3)
        @test match.weight == 3
        @test match.match == [2, 1, 3]

        # no perfect matching
        match = CS.bipartite_cardinality_matching(
            [1, 2, 3, 4, 1, 2, 3, 3],
            [1, 1, 2, 2, 2, 2, 3, 4],
            4,
            4,
        )
        @test match.weight == 3
        # 4 is zero and the rest should be different
        @test match.match[4] == 0
        @test allunique(match.match)


        # more values than indices 
        match = CS.bipartite_cardinality_matching(
            [1, 2, 3, 4, 1, 2, 3, 3, 2, 1, 2],
            [1, 1, 2, 2, 2, 2, 3, 4, 5, 5, 6],
            4,
            6,
        )
        @test match.weight == 4
        # all should be matched to different values
        @test allunique(match.match)
        # no unmatched vertex
        @test count(i -> i == 0, match.match) == 0

        # more values than indices with matching_init
        m = 4
        n = 6
        l = [1, 2, 3, 4, 1, 2, 3, 3, 2, 1, 2, 0, 0]
        r = [1, 1, 2, 2, 2, 2, 3, 4, 5, 5, 6, 0, 0]
        # don't use the zeros
        l_len = length(l) - 2
        matching_init = CS.MatchingInit(
            l_len,
            zeros(Int, m),
            zeros(Int, n),
            zeros(Int, m + 1),
            zeros(Int, m + n),
            zeros(Int, m + n),
            zeros(Int, m + n),
            zeros(Bool, m),
            zeros(Bool, n),
        )
        match = CS.bipartite_cardinality_matching(l, r, m, n; matching_init = matching_init)
        @test match.weight == 4
        # all should be matched to different values
        @test allunique(match.match)
        # no unmatched vertex
        @test count(i -> i == 0, match.match) == 0
    end

    @testset "Not equal" begin
        m = Model(CSJuMPTestSolver())

        @variable(m, 1 <= x <= 10, Int)
        @variable(m, 1 <= y <= 1, Int)
        @variable(m, 1 <= z <= 10, Int)
        @constraint(m, x != 2 - 1) # != 1
        @constraint(m, 2x != 4) # != 2
        @constraint(m, π / 3 * x != π) # != 3
        @constraint(m, 2.2x != 8.8) # != 4
        @constraint(m, 4x+5y != 25) # != 5
        @constraint(m, 4x+π*y != 10) # just some random stuff
        @constraint(m, x+y+z-π != 10)
        @constraint(m, x+y+z+2 != 10)
        @objective(m, Min, x)
        optimize!(m)

        @test JuMP.objective_value(m) == 6
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.value(x) == 6
        @test JuMP.value(y) == 1
        # the values should be fixed
        @test length(CS.values(m, x)) == 1 
        @test length(CS.values(m, y)) == 1 
        @test length(CS.values(m, z)) == 1 
        @test JuMP.value(x) + JuMP.value(y) + JuMP.value(z) + 2 != 10 
    end

    @testset "Integers basic" begin
        m = Model(CSJuMPTestSolver())
        @variable(m, x, CS.Integers([1,2,4]))
        @variable(m, y, CS.Integers([2,3,5,6]))
        @constraint(m, x == y)
        @objective(m, Max, x)
        optimize!(m)
        @test JuMP.value(x) ≈ 2
        @test JuMP.value(y) ≈ 2
        @test JuMP.objective_value(m) ≈ 2

        m = Model(optimizer_with_attributes(CS.Optimizer, "backtrack" => false))
        @variable(m, x, CS.Integers([1,2,4]))
        optimize!(m)
        com = JuMP.backend(m).optimizer.model.inner
        @test !CS.has(com.search_space[1], 3)
        @test sort(CS.values(com.search_space[1])) == [1,2,4]

        m = Model(optimizer_with_attributes(CS.Optimizer, "backtrack" => false))
        @variable(m, y, CS.Integers([2,5,6,3]))
        optimize!(m)
        com = JuMP.backend(m).optimizer.model.inner
        @test !CS.has(com.search_space[1], 1)
        @test !CS.has(com.search_space[1], 4)
        @test sort(CS.values(com.search_space[1])) == [2,3,5,6]
    end

    @testset "Biggest cube square number up to 100" begin
        m = Model(CSJuMPTestSolver())
        @variable(m, x, CS.Integers([i^2 for i=1:20 if i^2 < 100]))
        @variable(m, y, CS.Integers([i^3 for i=1:20 if i^3 < 100]))
        @constraint(m, x == y)
        @objective(m, Max, x)
        optimize!(m)
        @test JuMP.value(x) ≈ 64
        @test JuMP.value(y) ≈ 64
        @test JuMP.objective_value(m) ≈ 64
    end

    @testset "Pythagorean triples" begin
        m = Model(optimizer_with_attributes(
            CS.Optimizer,
            "all_solutions" => true,
            "logging" => [],
        ))
        @variable(m, x[1:3], CS.Integers([i^2 for i=1:50]))
        @constraint(m, x[1]+x[2] == x[3])
        @constraint(m, x[1] <= x[2])
        optimize!(m)
        @test MOI.get(m, MOI.ResultCount()) == 20
    end

    @testset "5 variables all equal" begin
        m = Model(optimizer_with_attributes(CS.Optimizer, "all_solutions" => true, "logging" => []))

        @variable(m, 5 <= x <= 10, Int)
        @variable(m, 2 <= y <= 15, Int)
        @variable(m, 1 <= z <= 7, Int)
        @variable(m, 2 <= a <= 9, Int)
        @variable(m, 6 <= b <= 10, Int)
        @constraint(m, x == y)
        # should not result in linking to x -> y -> x ... 
        @constraint(m, y == x)
        @constraint(m, x == y)
        
        @constraint(m, y == z)
        @constraint(m, a == z)
        @constraint(m, b == y)
        optimize!(m)

        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.value(x) == JuMP.value(y) == JuMP.value(z) == JuMP.value(a) == JuMP.value(b)
        @test JuMP.value(x; result=2) == JuMP.value(y; result=2) == JuMP.value(z; result=2) == JuMP.value(a; result=2) == JuMP.value(b; result=2)
        @test JuMP.value(x) == 6 || JuMP.value(x) == 7 
        @test JuMP.value(x; result=2) == 6 || JuMP.value(x; result=2) == 7 
        @test JuMP.value(x) != JuMP.value(x; result=2)
    end
end
