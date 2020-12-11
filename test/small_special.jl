@testset "Small special tests" begin
    @testset "Fix variable" begin
        m = Model(CSJuMPTestOptimizer())
        @variable(m, 1 <= x <= 9, Int)
        @variable(m, y == 2, Int)
        # should just return optimal with any 1-9 for x and y is fixed
        optimize!(m)

        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test 1 <= JuMP.value(x) <= 9 && length(CS.values(m, x)) == 1
        @test JuMP.value(y) == 2

        m = Model(CSJuMPTestOptimizer())
        @variable(m, 1 <= x <= 9, Int)
        @variable(m, y == 2, Int)
        @constraint(m, x + y == 10)
        optimize!(m)

        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.value(x) == 8
        @test JuMP.value(y) == 2
    end

    @testset "LessThan constraints JuMP" begin
        m = Model(CSJuMPTestOptimizer())
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
        m = Model(CSJuMPTestOptimizer())
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
        m = Model(CSJuMPTestOptimizer())
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

    @testset "Knapsack problems" begin
        m = Model(CSJuMPTestOptimizer())

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
        m = Model(CSJuMPTestOptimizer())

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
        m = Model(CSJuMPTestOptimizer())

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
        m = Model(CSJuMPTestOptimizer())

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

        m = Model(CSJuMPTestOptimizer())
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
        m = Model(CSJuMPTestOptimizer())
        # must be an Integer upper bound
        @variable(m, 1 <= x[1:5] <= NaN, Int)
        @test_throws ErrorException optimize!(m)

        m = Model(CSJuMPTestOptimizer())
        # must be an Integer lower bound
        @variable(m, NaN <= x[1:5] <= 2, Int)
        @test_throws ErrorException optimize!(m)

        m = Model(CSJuMPTestOptimizer())
        @variable(m, 1 <= x[1:5] <= 2, Int)

        m = Model(CSJuMPTestOptimizer())
        @variable(m, 1 <= x[1:5] <= 2, Int)

        m = Model(CSJuMPTestOptimizer())
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
        m = Model(CSJuMPTestOptimizer())

        @variable(m, 1 <= x <= 10, Int)
        @variable(m, 1 <= y <= 1, Int)
        @variable(m, 1 <= z <= 10, Int)
        @constraint(m, x != 2 - 1) # != 1
        @constraint(m, 2x != 4) # != 2
        @constraint(m, π / 3 * x != π) # != 3
        @constraint(m, 2.2x != 8.8) # != 4
        @constraint(m, 4x + 5y != 25) # != 5
        @constraint(m, 4x + π * y != 10) # just some random stuff
        @constraint(m, x + y + z - π != 10)
        @constraint(m, x + y + z + 2 != 10)
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
        m = Model(CSJuMPTestOptimizer())
        @variable(m, x, CS.Integers([1, 2, 4]))
        @variable(m, y, CS.Integers([2, 3, 5, 6]))
        @constraint(m, x == y)
        @objective(m, Max, x)
        optimize!(m)
        @test JuMP.value(x) ≈ 2
        @test JuMP.value(y) ≈ 2
        @test JuMP.objective_value(m) ≈ 2

        m = Model(optimizer_with_attributes(CS.Optimizer, "backtrack" => false))
        @variable(m, x, CS.Integers([1, 2, 4]))
        optimize!(m)
        com = JuMP.backend(m).optimizer.model.inner
        @test !CS.has(com.search_space[1], 3)
        @test sort(CS.values(com.search_space[1])) == [1, 2, 4]

        m = Model(optimizer_with_attributes(CS.Optimizer, "backtrack" => false))
        @variable(m, y, CS.Integers([2, 5, 6, 3]))
        optimize!(m)
        com = JuMP.backend(m).optimizer.model.inner
        @test !CS.has(com.search_space[1], 1)
        @test !CS.has(com.search_space[1], 4)
        @test sort(CS.values(com.search_space[1])) == [2, 3, 5, 6]
    end

    @testset "Biggest cube square number up to 100" begin
        m = Model(CSJuMPTestOptimizer())
        @variable(m, x, CS.Integers([i^2 for i = 1:20 if i^2 < 100]))
        @variable(m, y, CS.Integers([i^3 for i = 1:20 if i^3 < 100]))
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
        @variable(m, x[1:3], CS.Integers([i^2 for i in 1:50]))
        @constraint(m, x[1] + x[2] == x[3])
        @constraint(m, x[1] <= x[2])
        optimize!(m)
        com = JuMP.backend(m).optimizer.model.inner
        @test is_solved(com)
        @test MOI.get(m, MOI.ResultCount()) == 20
    end

    @testset "Infeasible by fixing variable to outside domain" begin
        m = Model(CSJuMPTestOptimizer())
        @variable(m, x, CS.Integers([1, 2, 4]))
        @constraint(m, x == 3)
        optimize!(m)
        @test JuMP.termination_status(m) == MOI.INFEASIBLE
    end

    @testset "Infeasible by fixing variable to two values" begin
        m = Model(CSJuMPTestOptimizer())
        @variable(m, x, CS.Integers([1, 2, 4]))
        @constraint(m, x == 1)
        @constraint(m, x == 2)
        optimize!(m)
        @test JuMP.termination_status(m) == MOI.INFEASIBLE
    end

    @testset "5 variables all equal" begin
        m = Model(optimizer_with_attributes(
            CS.Optimizer,
            "all_solutions" => true,
            "logging" => [],
        ))

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
        @test JuMP.value(x) ==
              JuMP.value(y) ==
              JuMP.value(z) ==
              JuMP.value(a) ==
              JuMP.value(b)
        @test JuMP.value(x; result = 2) ==
              JuMP.value(y; result = 2) ==
              JuMP.value(z; result = 2) ==
              JuMP.value(a; result = 2) ==
              JuMP.value(b; result = 2)
        @test JuMP.value(x) == 6 || JuMP.value(x) == 7
        @test JuMP.value(x; result = 2) == 6 || JuMP.value(x; result = 2) == 7
        @test JuMP.value(x) != JuMP.value(x; result = 2)
    end

    @testset "x[1] <= x[1]" begin
        model = Model(CSJuMPTestOptimizer())
        n = 4
        @variable(model, 1 <= x[1:n] <= n, Int)
        for i in 1:n
            @constraint(model, x[1] <= x[i])
        end

        optimize!(model)
        status = JuMP.termination_status(model)
        @test status == MOI.OPTIMAL
        com = JuMP.backend(model).optimizer.model.inner
        @test is_solved(com)
    end

    @testset "x[1] <= x[1] - 1 " begin
        model = Model(CSJuMPTestOptimizer())
        n = 4
        @variable(model, 1 <= x[1:n] <= n, Int)
        for i in 1:n
            @constraint(model, x[1] <= x[i] - 1)
        end

        optimize!(model)
        status = JuMP.termination_status(model)
        @test status == MOI.INFEASIBLE
    end

    @testset "x[1] == x[1]" begin
        model = Model(CSJuMPTestOptimizer())
        n = 4
        @variable(model, 1 <= x[1:n] <= n, Int)
        for i in 1:n
            @constraint(model, x[1] == x[i])
        end

        optimize!(model)
        status = JuMP.termination_status(model)
        @test status == MOI.OPTIMAL
        com = JuMP.backend(model).optimizer.model.inner
        @test is_solved(com)
    end

    @testset "x[1] == x[1] - 1 " begin
        model = Model(CSJuMPTestOptimizer())
        n = 4
        @variable(model, 1 <= x[1:n] <= n, Int)
        for i in 1:n
            @constraint(model, x[1] == x[i] - 1)
        end

        optimize!(model)
        status = JuMP.termination_status(model)
        @test status == MOI.INFEASIBLE
    end

    @testset "x[1] == x[1] - 1 in reified" begin
        model = Model(CSJuMPTestOptimizer())
        n = 4
        @variable(model, 1 <= x[1:n] <= n, Int)
        @variable(model, b[1:n], Bin)
        for i in 1:n
            @constraint(model, b[i] := {x[1] == x[i] - 1})
        end
        @objective(model, Max, sum(b))
        optimize!(model)
        status = JuMP.termination_status(model)
        @test status == MOI.OPTIMAL
        @test JuMP.objective_value(model) ≈ 3
        @test JuMP.value(b[1]) ≈ 0
    end

    @testset "x[1] == x[1] - 1 in indicator" begin
        model = Model(CSJuMPTestOptimizer())
        n = 4
        @variable(model, 1 <= x[1:n] <= n, Int)
        @variable(model, b[1:n], Bin)
        for i in 1:n
            @constraint(model, b[i] => {x[1] == x[i] - 1})
        end
        @objective(model, Max, sum(b))
        optimize!(model)
        status = JuMP.termination_status(model)
        @test status == MOI.OPTIMAL
        @test JuMP.objective_value(model) ≈ 3
        @test JuMP.value(b[1]) ≈ 0
    end

    @testset "Infeasible all different in indicator" begin
        model = Model(CSJuMPTestOptimizer())
        n = 4
        @variable(model, 1 <= x[1:n] <= n-1, Int)
        @variable(model, b, Bin)
        @constraint(model, b => {x in CS.AllDifferentSet()})
        @objective(model, Max, b)
        optimize!(model)
        status = JuMP.termination_status(model)
        @test status == MOI.OPTIMAL
        @test JuMP.objective_value(model) ≈ 0
        @test JuMP.value(b) ≈ 0
    end

    @testset "Infeasible all different in reified" begin
        model = Model(CSJuMPTestOptimizer())
        n = 4
        @variable(model, 1 <= x[1:n] <= n-1, Int)
        @variable(model, b, Bin)
        @constraint(model, b := {x in CS.AllDifferentSet()})
        @objective(model, Max, b)
        optimize!(model)
        status = JuMP.termination_status(model)
        @test status == MOI.OPTIMAL
        @test JuMP.objective_value(model) ≈ 0
        @test JuMP.value(b) ≈ 0
    end

    @testset "Infeasible table in indicator" begin
        model = Model(CSJuMPTestOptimizer())
        n = 4
        @variable(model, 1 <= x[1:n] <= n-1, Int)
        @variable(model, b, Bin)
        @constraint(model, b => {x in CS.TableSet([
            10 20
            11 5
        ])})
        @objective(model, Max, b)
        optimize!(model)
        status = JuMP.termination_status(model)
        @test status == MOI.OPTIMAL
        @test JuMP.objective_value(model) ≈ 0
        @test JuMP.value(b) ≈ 0
    end

    @testset "Infeasible table in reified" begin
        model = Model(CSJuMPTestOptimizer())
        n = 4
        @variable(model, 1 <= x[1:n] <= n-1, Int)
        @variable(model, b, Bin)
        @constraint(model, b := {x in CS.TableSet([
            10 20
            11 5
        ])})
        @objective(model, Max, b)
        optimize!(model)
        status = JuMP.termination_status(model)
        @test status == MOI.OPTIMAL
        @test JuMP.objective_value(model) ≈ 0
        @test JuMP.value(b) ≈ 0
    end
end
