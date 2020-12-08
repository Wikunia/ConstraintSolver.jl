@testset "ReifiedConstraint" begin
    @testset "Basic ==" begin
        m = Model(CSJuMPTestOptimizer())
        @variable(m, x, CS.Integers([1, 2, 4]))
        @variable(m, y, CS.Integers([3, 4]))
        @variable(m, b, Bin)
        @constraint(m, b := {x + y == 7})
        @objective(m, Max, b)
        optimize!(m)
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.objective_value(m) ≈ 1.0
        @test JuMP.value(b) ≈ 1.0
        @test JuMP.value(x) ≈ 4
        @test JuMP.value(y) ≈ 3
        com = JuMP.backend(m).optimizer.model.inner
        @test is_solved(com)
    end

    @testset "Basic >=" begin
        m = Model(CSJuMPTestOptimizer())
        @variable(m, x, CS.Integers([1, 2, 4]))
        @variable(m, y, CS.Integers([3, 4]))
        @variable(m, b, Bin)
        @constraint(m, b := {x + y >= 6.1})
        @objective(m, Max, b)
        optimize!(m)
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.objective_value(m) ≈ 1.0
        @test JuMP.value(b) ≈ 1.0
        @test JuMP.value(x) ≈ 4
        @test JuMP.value(y) ≈ 3
        com = JuMP.backend(m).optimizer.model.inner
        @test is_solved(com)
    end

    @testset "Basic >=" begin
        m = Model(CSJuMPTestOptimizer())
        @variable(m, x, CS.Integers([1, 2, 4]))
        @variable(m, y, CS.Integers([3, 4]))
        @variable(m, b, Bin)
        # missing { }
        @test_macro_throws ErrorException begin
            @constraint(m, b := x + y >= 6.1)
        end

        # no vectorization support
        @test_macro_throws ErrorException begin
            @constraint(m, b := {[x, y] .>= 6.1})
        end
    end

    @testset "Basic == where not active" begin
        m = Model(CSJuMPTestOptimizer())
        @variable(m, x, CS.Integers([1, 2, 4, 5]))
        @variable(m, y, CS.Integers([3, 4]))
        @variable(m, b, Bin)
        @constraint(m, b := {x + y == 7})
        @objective(m, Max, b + x + y)
        optimize!(m)
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.objective_value(m) ≈ 9.0
        @test JuMP.value(b) ≈ 0.0
        @test JuMP.value(x) ≈ 5
        @test JuMP.value(y) ≈ 4
        com = JuMP.backend(m).optimizer.model.inner
        @test !com.constraints[1].reified_in_inner
        @test is_solved(com)
    end

    @testset "Alldifferent" begin
        m = Model(CSJuMPTestOptimizer())
        @variable(m, x, CS.Integers([1, 2, 4]))
        @variable(m, y, CS.Integers([2, 3, 4]))
        @variable(m, b, Bin)
        @constraint(m, b := {[x, y] in CS.AllDifferentSet()})
        @objective(m, Max, 0.9 * b + x + y)
        optimize!(m)
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.objective_value(m) ≈ 8.0
        @test JuMP.value(b) ≈ 0.0
        @test JuMP.value(x) ≈ 4
        @test JuMP.value(y) ≈ 4
        com = JuMP.backend(m).optimizer.model.inner
        @test is_solved(com)
    end

    @testset "Alldifferent minimize" begin
        m = Model(CSJuMPTestOptimizer())
        @variable(m, x, CS.Integers([1, 2, 4]))
        @variable(m, y, CS.Integers([1, 2, 3, 4]))
        @variable(m, b, Bin)
        @constraint(m, !b := {[x, y] in CS.AllDifferentSet()})
        @objective(m, Min, 0.9 * b + x + y)
        optimize!(m)
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.objective_value(m) ≈ 2.9
        @test JuMP.value(b) ≈ 1.0
        @test JuMP.value(x) ≈ 1
        @test JuMP.value(y) ≈ 1
        com = JuMP.backend(m).optimizer.model.inner
        @test is_solved(com)
    end

    @testset "Alldifferent where active" begin
        m = Model(CSJuMPTestOptimizer())
        @variable(m, x, CS.Integers([1, 2, 4]))
        @variable(m, y, CS.Integers([2, 4]))
        @variable(m, b, Bin)
        @constraint(m, b := {[x, y] in CS.AllDifferentSet()})
        @objective(m, Max, 5b + x + y)
        optimize!(m)
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.objective_value(m) ≈ 11.0
        @test JuMP.value(b) ≈ 1.0
        @test JuMP.value(x) ≈ 2 || JuMP.value(y) ≈ 2
        @test JuMP.value(x) ≈ 4 || JuMP.value(y) ≈ 4
        com = JuMP.backend(m).optimizer.model.inner
        @test is_solved(com)
    end

    @testset "TableConstraint where active" begin
        m = Model(optimizer_with_attributes(
            CS.Optimizer,
            "keep_logs" => true,
            "logging" => [],
        ))
        @variable(m, x, CS.Integers([1, 2, 4]))
        @variable(m, y, CS.Integers([2, 4]))
        @variable(m, 1 <= z <= 10, Int)
        @variable(m, b, Bin)
        @constraint(
            m,
            b := {
                [x, y, z] in CS.TableSet([
                    1 2 3
                    1 4 3
                    2 4 3
                    3 4 3
                    1 2 4
                    1 4 4
                    2 4 4
                    3 4 4
                ]),
            }
        )
        @objective(m, Max, 5b + x + y)
        optimize!(m)
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.objective_value(m) ≈ 5 + 2 + 4
        @test JuMP.value(b) ≈ 1.0
        @test JuMP.value(x) ≈ 2
        @test JuMP.value(y) ≈ 4
        com = JuMP.backend(m).optimizer.model.inner
        @test is_solved(com)
    end

    @testset "TableConstraint where inactive" begin
        m = Model(optimizer_with_attributes(
            CS.Optimizer,
            "keep_logs" => true,
            "logging" => [],
        ))
        @variable(m, x, CS.Integers([1, 2, 4]))
        @variable(m, y, CS.Integers([2, 4]))
        @variable(m, b, Bin)
        @constraint(m, !b := {[x, y] in CS.TableSet([
            1 2
            2 4
            3 4
            4 4
        ])})
        @objective(m, Max, 5b + x + y)
        optimize!(m)
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.objective_value(m) ≈ 5 + 4 + 2
        @test JuMP.value(b) ≈ 1.0
        @test JuMP.value(x) ≈ 4
        @test JuMP.value(y) ≈ 2
        com = JuMP.backend(m).optimizer.model.inner
        @test is_solved(com)
    end

    @testset "TableConstraint with optimization" begin
        cbc_optimizer = optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0)
        m = Model(optimizer_with_attributes(
            CS.Optimizer,
            "logging" => [],
            "lp_optimizer" => cbc_optimizer,
            "keep_logs" => true,
        ))
        @variable(m, 1 <= a <= 100, Int)
        @variable(m, 1 <= b <= 100, Int)
        @variable(m, 1 <= c <= 100, Int)
        @variable(m, reified, Bin)
        table = zeros(Int, (52, 3))
        r = 1
        for i in 1:100, j in i:100, k in j:100
            if i^2 + j^2 == k^2
                table[r, :] .= [i, j, k]
                r += 1
            end
            @constraint(m, reified := {[a, b, c] in CS.TableSet(table)})
            @objective(m, Max, 5 * reified + b + c)
            optimize!(m)
            @test JuMP.termination_status(m) == MOI.OPTIMAL
            @test JuMP.objective_value(m) ≈ 5 + 96 + 100
            @test JuMP.value(a) ≈ 28
            @test JuMP.value(b) ≈ 96
            @test JuMP.value(c) ≈ 100
            @test JuMP.value(reified) ≈ 1
            com = JuMP.backend(m).optimizer.model.inner
            @test is_solved(com)
        end
        @constraint(m, reified := {[a, b, c] in CS.TableSet(table)})
        @objective(m, Max, 5 * reified + b + c)
        optimize!(m)
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test JuMP.objective_value(m) ≈ 5 + 96 + 100
        @test JuMP.value(a) ≈ 28
        @test JuMP.value(b) ≈ 96
        @test JuMP.value(c) ≈ 100
        @test JuMP.value(reified) ≈ 1
        com = JuMP.backend(m).optimizer.model.inner
        @test is_solved(com)
        # @test general_tree_test(com) not working as we have less than 10 logs
    end

    @testset "all different != 0 (Issue 202)" begin
        n = 2
        model = Model(optimizer_with_attributes(
            CS.Optimizer,
            "all_solutions" => true,
            "logging" => [],
        ))
        @variable(model, 0 <= x[1:n] <= n, Int)
        b_len = length([1 for i in 2:n for j in 1:(i - 1) for k in 1:3])
        @variable(model, bs[1:b_len], Bin)
        c = 1
        for i in 2:n, j in 1:(i - 1)
            # b1: bs[c]
            # b2: bs[c+1]
            # b3: bs[c+2]
            @constraint(model, bs[c] := {x[i] != 0})
            @constraint(model, bs[c + 1] := {x[j] != 0})
            @constraint(model, bs[c + 2] := {bs[c] + bs[c + 1] == 2})
            @constraint(model, bs[c + 2] => {x[i] != x[j]})
            c += 3
        end

        optimize!(model)

        status = JuMP.termination_status(model)
        @test status == MOI.OPTIMAL
        num_sols = MOI.get(model, MOI.ResultCount())
        @test num_sols == 7

        xx_set = Set()
        for sol in 1:num_sols
            xx = convert.(Integer, JuMP.value.(x, result = sol))
            bss = convert.(Integer, JuMP.value.(bs, result = sol))
            push!(xx_set, (xx[1], xx[2]))
        end
        @test length(xx_set) == num_sols
        @test (0, 0) in xx_set
        @test (0, 1) in xx_set
        @test (0, 2) in xx_set
        @test (1, 0) in xx_set
        @test (1, 2) in xx_set
        @test (2, 0) in xx_set
        @test (2, 1) in xx_set
    end
end
