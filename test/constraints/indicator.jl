@testset "IndicatorConstraint" begin
    @testset "Basic ==" begin
        m = Model(CSJuMPTestOptimizer())
        @variable(m, x, CS.Integers([1, 2, 4]))
        @variable(m, y, CS.Integers([3, 4]))
        @variable(m, b, Bin)
        @constraint(m, b => {x + y == 7})
        @objective(m, Max, b)
        optimize!(m)
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.objective_value(m) ≈ 1.0
        @test JuMP.value(b) ≈ 1.0
        @test JuMP.value(x) ≈ 4
        @test JuMP.value(y) ≈ 3
        com = JuMP.backend(m).optimizer.model.inner
        @test !com.constraints[1].indicator_in_inner
        @test is_solved(com)
    end

    @testset "Basic == Active on zero" begin
        m = Model(CSJuMPTestOptimizer())
        @variable(m, x, CS.Integers([1, 2, 4]))
        @variable(m, y, CS.Integers([3, 4]))
        @variable(m, b, Bin)
        @constraint(m, !b => {x + y == 9})
        @objective(m, Min, b)
        optimize!(m)
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.objective_value(m) ≈ 1.0
        @test JuMP.value(b) ≈ 1.0
        com = JuMP.backend(m).optimizer.model.inner
        @test is_solved(com)
    end

    @testset "Basic == infeasible" begin
        m = Model(CSJuMPTestOptimizer())
        @variable(m, x, CS.Integers([1, 4]))
        @variable(m, y, CS.Integers([3, 4]))
        @variable(m, b, Bin)
        @constraint(m, b == 1)
        @constraint(m, b => {x + y == 6})
        optimize!(m)
        @test JuMP.termination_status(m) == MOI.INFEASIBLE
        com = JuMP.backend(m).optimizer.model.inner
        @test !is_solved(com)
    end

    @testset "Basic !=" begin
        m = Model(CSJuMPTestOptimizer())
        @variable(m, x, CS.Integers([1, 2, 4]))
        @variable(m, y, CS.Integers([3, 4]))
        @variable(m, b, Bin)
        @constraint(m, b => {x + y != 8})
        @objective(m, Max, x + y)
        optimize!(m)
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.objective_value(m) ≈ 8.0
        @test JuMP.value(b) ≈ 0.0
        @test JuMP.value(x) ≈ 4
        @test JuMP.value(y) ≈ 4
        com = JuMP.backend(m).optimizer.model.inner
        @test is_solved(com)
    end

    @testset "Basic >=" begin
        m = Model(CSJuMPTestOptimizer())
        @variable(m, x, CS.Integers([1, 2, 4]))
        @variable(m, y, CS.Integers([3, 4]))
        @variable(m, b, Bin)
        @constraint(m, b => {x + y >= 6})
        @objective(m, Min, x + y)
        optimize!(m)
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.objective_value(m) ≈ 4.0
        @test JuMP.value(b) ≈ 0.0
        @test JuMP.value(x) ≈ 1
        @test JuMP.value(y) ≈ 3

        m = Model(CSJuMPTestOptimizer())
        @variable(m, x, CS.Integers([1, 2, 4]))
        @variable(m, y, CS.Integers([3, 4]))
        @variable(m, b, Bin)
        @constraint(m, b == 1)
        @constraint(m, b => {x + y >= 6})
        @objective(m, Min, x + y)
        optimize!(m)
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.objective_value(m) ≈ 6.0
        @test JuMP.value(b) ≈ 1.0
        @test JuMP.value(x) ≈ 2
        @test JuMP.value(y) ≈ 4
        com = JuMP.backend(m).optimizer.model.inner
        @test is_solved(com)
    end

    @testset "Basic <=" begin
        m = Model(CSJuMPTestOptimizer())
        @variable(m, x, CS.Integers([1, 2, 4]))
        @variable(m, y, CS.Integers([3, 4]))
        @variable(m, b, Bin)
        @constraint(m, b => {x + y <= 4})
        @objective(m, Max, x + y)
        optimize!(m)
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.objective_value(m) ≈ 8.0
        @test JuMP.value(b) ≈ 0.0
        @test JuMP.value(x) ≈ 4
        @test JuMP.value(y) ≈ 4

        m = Model(CSJuMPTestOptimizer())
        @variable(m, x, CS.Integers([1, 2, 4]))
        @variable(m, y, CS.Integers([3, 4]))
        @variable(m, b, Bin)
        @constraint(m, b == 1)
        @constraint(m, b => {x + y <= 4})
        @objective(m, Max, x + y)
        optimize!(m)
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.objective_value(m) ≈ 4.0
        @test JuMP.value(b) ≈ 1.0
        @test JuMP.value(x) ≈ 1
        @test JuMP.value(y) ≈ 3
        com = JuMP.backend(m).optimizer.model.inner
        @test is_solved(com)
    end

    @testset "Basic AllDifferent" begin
        m = Model(CSJuMPTestOptimizer())
        @variable(m, 0 <= x <= 1, Int)
        @variable(m, 0 <= y <= 1, Int)
        @variable(m, a, Bin)
        @constraint(m, x + y <= 1)
        @constraint(m, [a, x] in CS.AllDifferentSet())
        @constraint(m, a => {[a, x, y] in CS.AllDifferentSet()})
        @objective(m, Max, a)
        optimize!(m)
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.objective_value(m) ≈ 0.0
        @test JuMP.value(a) ≈ 0.0
        com = JuMP.backend(m).optimizer.model.inner
        num_indicator = 0
        for i in 1:length(com.constraints)
            if com.constraints[i] isa CS.IndicatorConstraint
                @test com.constraints[i].indicator_in_inner
                num_indicator += 1
            end
        end
        @test num_indicator == 1
        @test is_solved(com)
    end

    @testset "Basic AllDifferent achievable" begin
        m = Model(CSJuMPTestOptimizer())
        @variable(m, 0 <= x <= 1, Int)
        @variable(m, 0 <= y <= 1, Int)
        @variable(m, a, Bin)
        @constraint(m, x + y <= 1)
        @constraint(m, [a, x] in CS.AllDifferentSet())
        @constraint(m, a => {[x, y] in CS.AllDifferentSet()})
        @objective(m, Max, a)
        optimize!(m)
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.objective_value(m) ≈ 1.0
        @test JuMP.value(a) ≈ 1.0
        @test JuMP.value(y) ≈ 1.0
        @test JuMP.value(x) ≈ 0.0
        com = JuMP.backend(m).optimizer.model.inner
        @test is_solved(com)
    end

    @testset "Basic AllDifferent negated" begin
        m = Model(CSJuMPTestOptimizer())
        @variable(m, 0 <= x <= 1, Int)
        @variable(m, 0 <= y <= 1, Int)
        @variable(m, a, Bin)
        @constraint(m, x + y <= 1)
        @constraint(m, [a, x] in CS.AllDifferentSet())
        @constraint(m, !a => {[x, y] in CS.AllDifferentSet()})
        @objective(m, Min, a)
        optimize!(m)
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.objective_value(m) ≈ 0.0
        @test JuMP.value(a) ≈ 0.0
        @test JuMP.value(y) ≈ 0.0
        @test JuMP.value(x) ≈ 1.0
        com = JuMP.backend(m).optimizer.model.inner
        @test is_solved(com)
    end

    @testset "Basic Table" begin
        m = Model(CSJuMPTestOptimizer())
        @variable(m, 0 <= x <= 3, Int)
        @variable(m, 0 <= y <= 3, Int)
        @variable(m, a, Bin)
        @constraint(m, x + y >= 2)
        @constraint(m, a => {[x, y] in CS.TableSet([
            0 1
            1 1
            4 4
            3 2
            2 2
            2 3
        ])})
        @objective(m, Max, a + 1.1x + 0.5y)
        optimize!(m)
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.objective_value(m) ≈ 1.0 + 3.3 + 1.0
        @test JuMP.value(a) ≈ 1.0
        @test JuMP.value(x) ≈ 3.0
        @test JuMP.value(y) ≈ 2.0
        com = JuMP.backend(m).optimizer.model.inner
        @test is_solved(com)
    end

    @testset "Basic Table optimization" begin
        m = Model(CSCbcJuMPTestOptimizer())
        @variable(m, 0 <= x <= 9, Int)
        @variable(m, 0 <= y <= 9, Int)
        @variable(m, a, Bin)
        @constraint(
            m,
            a => {
                [x, y] in CS.TableSet([
                    1 1
                    1 2
                    1 3
                    1 4
                    1 5
                    1 6
                    1 7
                    1 8
                    1 9
                    2 1
                    2 2
                    2 3
                    2 4
                    2 5
                    2 6
                    2 7
                    2 8
                    2 9
                    3 1
                    3 2
                    3 3
                    3 4
                    3 5
                    3 6
                    3 7
                    3 8
                    3 9
                    4 1
                    4 2
                    4 3
                    4 4
                    4 5
                    4 6
                    4 7
                    4 8
                    4 9
                ]),
            }
        )
        @objective(m, Max, a + 1.1x + 0.5y)
        optimize!(m)
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.objective_value(m) ≈ 9.9 + 4.5
        @test JuMP.value(a) ≈ 0.0
        @test JuMP.value(x) ≈ 9.0
        @test JuMP.value(y) ≈ 9.0
        com = JuMP.backend(m).optimizer.model.inner
        @test is_solved(com)
    end
end
