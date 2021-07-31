@testset "EqualTo Constraint" begin
    @testset "digits form a number (Issue 200)" begin
        use_diff = false
        model = Model(optimizer_with_attributes(
            CS.Optimizer,
            "traverse_strategy" => :DBFS,
            "branch_split" => :InHalf,
            "logging" => [],
        ))

        @variable(model, 0 <= x[1:10] <= 9, Int)
        @variable(model, 10000 <= v[1:2] <= 99999, Int) # ABCDE and FGHIJ
        if use_diff
            @variable(model, 0 <= diff <= 999, Int) # adding this is much slower than using v[1:2] only
        end

        a, b, c, d, e, f, g, h, i, j = x
        @constraint(model, x in CS.AllDifferent())
        @constraint(model, v[1] == 10000 * a + 1000 * b + 100 * c + 10 * d + e) # ABCDE
        @constraint(model, v[2] == 10000 * f + 1000 * g + 100 * h + 10 * i + j) # FGHIJ

        # Using diff is slower
        if use_diff
            @constraint(model, diff == v[1] - v[2])  # much slower
            @constraint(model, diff >= 1)
        else
            @constraint(model, v[1] - v[2] >= 1)
        end

        if use_diff
            @objective(model, Min, diff) # slower
        else
            @objective(model, Min, v[1] - v[2])
        end

        # Solve the problem
        optimize!(model)

        status = JuMP.termination_status(model)
        @test status == MOI.OPTIMAL
        x_vals = convert.(Int, JuMP.value.(x))
        @test x_vals == [5, 0, 1, 2, 3, 4, 9, 8, 7, 6]
    end
end
