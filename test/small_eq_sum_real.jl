@testset "Real coefficients" begin
@testset "Basic all true" begin
    m = Model(with_optimizer(CS.Optimizer))
    @variable(m, x[1:4], Bin)
    weights = [1.7, 0.7, 0.3, 1.3]
    @variable(m, 0 <= max_val <= 10, Int)
    @constraint(m, sum(weights.*x) == max_val)
    @objective(m, Max, max_val)
    optimize!(m)
    @test JuMP.termination_status(m) == MOI.OPTIMAL
    @test JuMP.objective_value(m) == 4
    @test JuMP.value.(x) == [1,1,1,1]
end

@testset "Some true some false" begin
    # disallow that x1 and x2 are both allowed
    m = Model(with_optimizer(CS.Optimizer))
    @variable(m, x[1:4], Bin)
    @variable(m, z, Bin)
    # x[1]+x[2] <= 1
    @constraint(m, x[1]+x[2]+z == 1)

    weights = [1.7, 0.7, 0.3, 1.3]
    @variable(m, 0 <= max_val <= 10, Int)
    @constraint(m, sum(weights.*x) == max_val)
    @objective(m, Max, max_val)
    optimize!(m)
    @test JuMP.termination_status(m) == MOI.OPTIMAL
    @test JuMP.objective_value(m) == 3
    @test JuMP.value.(x) == [1,0,0,1]
end

@testset "Negative coefficients" begin
    # must use negative coefficient for optimum
    m = Model(with_optimizer(CS.Optimizer))
    @variable(m, x[1:4], Bin)
    @variable(m, z, Bin)
    # x[1]+x[2] <= 1
    @constraint(m, x[1]+x[2]+z == 1)

    weights = [1.7, 0.7, -0.3, 1.6]
    @variable(m, 0 <= max_val <= 10, Int)
    @constraint(m, sum(weights.*x) == max_val)
    @objective(m, Max, max_val)
    optimize!(m)
    @test JuMP.termination_status(m) == MOI.OPTIMAL
    @test JuMP.objective_value(m) == 3
    @test JuMP.value.(x) == [1,0,1,1]
end

@testset "Minimization negative coefficients" begin
    # must use negative coefficient for optimum
    m = Model(with_optimizer(CS.Optimizer))
    @variable(m, x[1:4], Bin)
    @variable(m, z, Bin)
    # x[1]+x[2] <= 1
    @constraint(m, x[1]+x[2]+z == 1)

    weights = [0.3, 0.7, -0.3, 1.6]
    @variable(m, 1 <= max_val <= 10, Int)
    @constraint(m, sum(weights.*x) == max_val)
    @objective(m, Min, max_val)
    optimize!(m)
    @test JuMP.termination_status(m) == MOI.OPTIMAL
    @test JuMP.objective_value(m) == 2
    @test JuMP.value.(x) == [0,1,1,1]
end

end