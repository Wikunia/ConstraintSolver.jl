
@testset "Stable set" begin
@testset "positive coefficients MAX" begin
    matrix = [
        0 1 1 0
        1 0 1 0
        1 1 0 1
        0 0 1 0
    ]
    model = CS.Optimizer()
    x = [MOI.add_constrained_variable(model, MOI.ZeroOne()) for _ in 1:4]
    for i in 1:4, j in 1:4
        if matrix[i,j] == 1 && i < j
            (z, _) = MOI.add_constrained_variable(model, MOI.GreaterThan(0.0))
            MOI.add_constraint(model, z, MOI.Integer())
            MOI.add_constraint(model, z, MOI.LessThan(1.0))
            f = MOI.ScalarAffineFunction(
                [
                    MOI.ScalarAffineTerm(1.0, x[i][1]),
                    MOI.ScalarAffineTerm(1.0, x[j][1]),
                    MOI.ScalarAffineTerm(1.0, z),
                ], 0.0
            )
            MOI.add_constraint(model, f, MOI.EqualTo(1.0))
        end
    end
    weights = [0.2, 0.1, 0.2, 0.1]
    saf = MOI.ScalarAffineFunction{Float64}([MOI.ScalarAffineTerm(weights[i], x[i][1]) for i in eachindex(x)], 0.0)
    MOI.set(model, MOI.ObjectiveFunction{MOI.ScalarAffineFunction}(), saf)
    MOI.set(model, MOI.ObjectiveSense(), MOI.MAX_SENSE)
    MOI.optimize!(model)
    @test MOI.get(model, MOI.VariablePrimal(), x[4][1]) == 1
    @test MOI.get(model, MOI.VariablePrimal(), x[1][1]) == 1
    @test MOI.get(model, MOI.ObjectiveValue()) ≈ 0.3
end

@testset "negative/postive coefficients MIN with JuMP" begin
    matrix = [
        0 1 0 1
        1 0 1 0
        0 1 0 1
        1 0 1 0
    ]
    m = Model(with_optimizer(CS.Optimizer))
    @variable(m, x[1:4], Bin)
    for i in 1:4, j in 1:4
        if matrix[i,j] == 1 && i < j
            z = @variable(m, lower_bound = 0.0, upper_bound = 1.0, integer = true)
            @constraint(m, x[i]+x[j]+z == 1.0)
        end
    end
    weights = [-0.2, -0.1, 0.2, -0.11]
    @objective(m, Min, sum(weights.*x))
    optimize!(m)
    @test JuMP.value(x[4]) == 1
    @test JuMP.value(x[2]) == 1
    @test JuMP.objective_value(m) ≈ -0.21
end
end
