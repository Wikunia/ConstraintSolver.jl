@testset "MOI Tests" begin
@testset "Supports and SolverName" begin
    optimizer = CS.Optimizer()
    @test MOI.get(optimizer, MOI.SolverName()) == "ConstraintSolver"
    @test MOI.supports_constraint(optimizer, MOI.VectorOfVariables, CS.AllDifferentSet)
    @test MOI.supports_constraint(optimizer, MOI.VectorOfVariables, CS.EqualSet)
    @test MOI.supports_constraint(optimizer, MOI.SingleVariable, MOI.ZeroOne)
    @test MOI.supports_constraint(optimizer, MOI.SingleVariable, MOI.Integer)
    @test MOI.supports_constraint(optimizer, MOI.SingleVariable, MOI.LessThan{Float64})
    @test MOI.supports_constraint(optimizer, MOI.SingleVariable, MOI.GreaterThan{Float64})
    @test MOI.supports_constraint(optimizer, MOI.SingleVariable, MOI.EqualTo{Float64})
    @test MOI.supports_constraint(optimizer, MOI.SingleVariable, MOI.Interval{Float64})

    @test MOI.supports_constraint(optimizer, MOI.ScalarAffineFunction{Float64}, MOI.EqualTo{Float64})
    @test MOI.supports_constraint(optimizer, MOI.ScalarAffineFunction{Float64}, MOI.LessThan{Float64})
    @test MOI.supports_constraint(optimizer, MOI.ScalarAffineFunction{Float64}, CS.NotEqualSet{Float64})

    # objective
    @test MOI.supports(optimizer, MOI.ObjectiveSense())
    @test MOI.supports(optimizer, MOI.ObjectiveFunction{MOI.SingleVariable}())
    @test MOI.supports(optimizer, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}())

    @test MOI.supports(optimizer, MOI.RawParameter("backtrack"))

    @test MOI.get(optimizer, MOI.ObjectiveSense()) == MOI.FEASIBILITY_SENSE
end

@testset "Small MOI tests" begin
    optimizer = CS.Optimizer()
    @assert MOI.supports_constraint(optimizer, MOI.VectorOfVariables, CS.AllDifferentSet)

    x1 = MOI.add_constrained_variable(optimizer, MOI.ZeroOne())
    x2 = MOI.add_constrained_variable(optimizer, MOI.Interval(1.0, 2.0))
    x3 = MOI.add_constrained_variable(optimizer, MOI.Interval(2.0, 3.0))

    # [1] to get the index
    MOI.add_constraint(optimizer, x2[1], MOI.Integer())
    MOI.add_constraint(optimizer, x3[1], MOI.Integer())

    affine_terms = Vector{MOI.ScalarAffineTerm{Float64}}()
    push!(affine_terms,  MOI.ScalarAffineTerm{Float64}(1,MOI.VariableIndex(1)))
    push!(affine_terms,  MOI.ScalarAffineTerm{Float64}(1,MOI.VariableIndex(2)))
    MOI.add_constraint(optimizer, MOI.ScalarAffineFunction(affine_terms,0.0), MOI.EqualTo(3.0))
    MOI.add_constraint(optimizer, MOI.VectorOfVariables([x1[1], x2[1], x3[1]]), CS.AllDifferentSet(3))

    MOI.optimize!(optimizer)
    @test MOI.get(optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
    @test MOI.get(optimizer, MOI.VariablePrimal(), x1[1]) == 1
    @test MOI.get(optimizer, MOI.VariablePrimal(), x2[1]) == 2
    @test MOI.get(optimizer, MOI.VariablePrimal(), x3[1]) == 3
end

@testset "ErrorHandling" begin
    optimizer = CS.Optimizer()
    @test_throws ErrorException MOI.add_constrained_variable(optimizer, MOI.Interval(NaN, 2.0))
    @test_throws ErrorException MOI.add_constrained_variable(optimizer, MOI.Interval(1.0, NaN))

    optimizer = CS.Optimizer()
    x = MOI.add_constrained_variable(optimizer, MOI.Interval(1.0, 2.0))
    @test_logs (:error, r"Upper bound .* exists") MOI.add_constraint(optimizer, MOI.SingleVariable(MOI.VariableIndex(1)), MOI.LessThan(2.0))
    @test_logs (:error, r"Lower bound .* exists") MOI.add_constraint(optimizer, MOI.SingleVariable(MOI.VariableIndex(1)), MOI.GreaterThan(1.0))

    optimizer = CS.Optimizer()
    x1 = MOI.add_constrained_variable(optimizer, MOI.Interval(1.0, 2.0))
    x2 = MOI.add_constrained_variable(optimizer, MOI.Interval(1.0, 2.0))
    # All should be integer
    @test_throws ErrorException MOI.optimize!(optimizer)

    # non existing option
    @test_logs (:error, r"option abc doesn't exist") Model(optimizer_with_attributes(CS.Optimizer, "abc"=>1))
    @test_logs (:error, r"option abc doesn't exist") model = CS.Optimizer(abc = 1)
end

end
