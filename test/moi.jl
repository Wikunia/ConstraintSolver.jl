@testset "MOI Tests" begin
    @testset "Supports and SolverName" begin
        optimizer = CSTestOptimizer(; branch_strategy = :ABS)
        @test MOI.get(optimizer, MOI.SolverName()) == "ConstraintSolver"
        @test MOI.supports_constraint(
            optimizer,
            MOI.VectorOfVariables,
            CS.CPE.AllDifferent,
        )
        @test MOI.supports_constraint(optimizer, MOI.VectorOfVariables, CS.EqualSetInternal)
        @test MOI.supports_constraint(optimizer, MOI.VectorOfVariables, CS.TableSetInternal)
        @test MOI.supports_constraint(optimizer, MOI.SingleVariable, MOI.ZeroOne)
        @test MOI.supports_constraint(optimizer, MOI.SingleVariable, MOI.Integer)
        @test MOI.supports_constraint(optimizer, MOI.SingleVariable, MOI.LessThan{Float64})
        @test MOI.supports_constraint(optimizer, MOI.SingleVariable, CS.Integers)
        @test MOI.supports_constraint(
            optimizer,
            MOI.SingleVariable,
            MOI.GreaterThan{Float64},
        )
        @test MOI.supports_constraint(optimizer, MOI.SingleVariable, MOI.EqualTo{Float64})
        @test MOI.supports_constraint(optimizer, MOI.SingleVariable, MOI.Interval{Float64})

        @test MOI.supports_constraint(
            optimizer,
            MOI.ScalarAffineFunction{Float64},
            MOI.EqualTo{Float64},
        )
        @test MOI.supports_constraint(
            optimizer,
            MOI.ScalarAffineFunction{Float64},
            MOI.LessThan{Float64},
        )
        @test MOI.supports_constraint(
            optimizer,
            MOI.ScalarAffineFunction{Float64},
            CS.NotEqualTo{Float64},
        )

        f = MOI.VectorAffineFunction(
            [
                MOI.VectorAffineTerm(1, MOI.ScalarAffineTerm(1.0, MOI.VariableIndex(1))),
                MOI.VectorAffineTerm(2, MOI.ScalarAffineTerm(1.0, MOI.VariableIndex(2))),
                MOI.VectorAffineTerm(2, MOI.ScalarAffineTerm(1.0, MOI.VariableIndex(3))),
            ],
            [0.0, 0.0],
        )
        indicator_set = MOI.IndicatorSet{MOI.ACTIVATE_ON_ONE}(MOI.LessThan(9.0))
        @test MOI.supports_constraint(optimizer, typeof(f), typeof(indicator_set))
        indicator_set = MOI.IndicatorSet{MOI.ACTIVATE_ON_ONE}(MOI.GreaterThan(9.0))
        @test MOI.supports_constraint(optimizer, typeof(f), typeof(indicator_set))
        indicator_set = MOI.IndicatorSet{MOI.ACTIVATE_ON_ONE}(MOI.EqualTo(9.0))
        @test MOI.supports_constraint(optimizer, typeof(f), typeof(indicator_set))

        indicator_set = CS.IndicatorSet{MOI.ACTIVATE_ON_ONE, typeof(f)}(CS.CPE.AllDifferent(2))
        @test !MOI.supports_constraint(optimizer, typeof(f), typeof(indicator_set))
        indicator_set = CS.IndicatorSet{MOI.ACTIVATE_ON_ZERO, typeof(f)}(CS.TableSetInternal(2, [1 2; ]))
        @test !MOI.supports_constraint(optimizer, typeof(f), typeof(indicator_set))

        @test MOI.supports_constraint(
            optimizer,
            typeof(f),
            CS.ReifiedSet{MOI.ACTIVATE_ON_ONE,MOI.ScalarAffineFunction{Float64},MOI.LessThan{Float64}},
        )

        @test MOI.supports_constraint(
            optimizer,
            MOI.VectorOfVariables,
            CS.ReifiedSet{MOI.ACTIVATE_ON_ZERO,MOI.VectorOfVariables,CS.CPE.AllDifferent},
        )

        # TimeLimit
        @test MOI.supports(optimizer, MOI.TimeLimitSec())

        # objective
        @test MOI.supports(optimizer, MOI.ObjectiveSense())
        @test MOI.supports(optimizer, MOI.ObjectiveFunction{MOI.SingleVariable}())
        @test MOI.supports(
            optimizer,
            MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
        )

        @test MOI.supports(optimizer, MOI.RawParameter("backtrack"))

        @test MOI.get(optimizer, MOI.ObjectiveSense()) == MOI.FEASIBILITY_SENSE
    end

    @testset "Small MOI tests" begin
        optimizer = CSTestOptimizer()
        @assert MOI.supports_constraint(
            optimizer,
            MOI.VectorOfVariables,
            CS.CPE.AllDifferent,
        )

        x1 = MOI.add_constrained_variable(optimizer, MOI.ZeroOne())
        x2 = MOI.add_constrained_variable(optimizer, MOI.Interval(1.0, 2.0))
        x3 = MOI.add_constrained_variable(optimizer, MOI.Interval(2.0, 3.0))

        # [1] to get the index
        MOI.add_constraint(optimizer, x2[1], MOI.Integer())
        MOI.add_constraint(optimizer, x3[1], MOI.Integer())

        affine_terms = Vector{MOI.ScalarAffineTerm{Float64}}()
        push!(affine_terms, MOI.ScalarAffineTerm{Float64}(1, MOI.VariableIndex(1)))
        push!(affine_terms, MOI.ScalarAffineTerm{Float64}(1, MOI.VariableIndex(2)))
        MOI.add_constraint(
            optimizer,
            MOI.ScalarAffineFunction(affine_terms, 0.0),
            MOI.EqualTo(3.0),
        )
        MOI.add_constraint(
            optimizer,
            MOI.VectorOfVariables([x1[1], x2[1], x3[1]]),
            CS.CPE.AllDifferent(3),
        )

        MOI.optimize!(optimizer)
        @test MOI.get(optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
        @test MOI.get(optimizer, MOI.VariablePrimal(), x1[1]) == 1
        @test MOI.get(optimizer, MOI.VariablePrimal(), x2[1]) == 2
        @test MOI.get(optimizer, MOI.VariablePrimal(), x3[1]) == 3
    end

    @testset "ErrorHandling" begin
        optimizer = CSTestOptimizer()
        @test_throws ErrorException MOI.add_constrained_variable(
            optimizer,
            MOI.Interval(NaN, 2.0),
        )
        @test_throws ErrorException MOI.add_constrained_variable(
            optimizer,
            MOI.Interval(1.0, NaN),
        )

        optimizer = CSTestOptimizer()
        x = MOI.add_constrained_variable(optimizer, MOI.Interval(1.0, 2.0))
        @test_logs (:error, r"Upper bound .* exists") MOI.add_constraint(
            optimizer,
            MOI.SingleVariable(MOI.VariableIndex(1)),
            MOI.LessThan(2.0),
        )
        @test_logs (:error, r"Lower bound .* exists") MOI.add_constraint(
            optimizer,
            MOI.SingleVariable(MOI.VariableIndex(1)),
            MOI.GreaterThan(1.0),
        )

        optimizer = CSTestOptimizer()
        x1 = MOI.add_constrained_variable(optimizer, MOI.Interval(1.0, 2.0))
        x2 = MOI.add_constrained_variable(optimizer, MOI.Interval(1.0, 2.0))
        # All should be integer
        @test_throws ErrorException MOI.optimize!(optimizer)

        # non existing option
        @test_logs (:error, r"option abc doesn't exist") Model(optimizer_with_attributes(
            CS.Optimizer,
            "abc" => 1,
        ))
        @test_logs (:error, r"option abc doesn't exist") model = CS.Optimizer(abc = 1)
    end

end
