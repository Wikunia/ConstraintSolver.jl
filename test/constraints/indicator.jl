@testset "IndicatorConstraint" begin
@testset "Basic ==" begin
    m = Model(CSJuMPTestOptimizer())
    @variable(m, x, CS.Integers([1,2,4]))
    @variable(m, y, CS.Integers([3,4]))
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
    @test is_solved(com)
end

@testset "Basic == infeasible" begin
    m = Model(CSJuMPTestOptimizer())
    @variable(m, x, CS.Integers([1,4]))
    @variable(m, y, CS.Integers([3,4]))
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
    @variable(m, x, CS.Integers([1,2,4]))
    @variable(m, y, CS.Integers([3,4]))
    @variable(m, b, Bin)
    @constraint(m, b => {x + y != 8})
    @objective(m, Max, x+y)
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
    @variable(m, x, CS.Integers([1,2,4]))
    @variable(m, y, CS.Integers([3,4]))
    @variable(m, b, Bin)
    @constraint(m, b => {x + y >= 6})
    @objective(m, Min, x+y)
    optimize!(m)
    @test JuMP.termination_status(m) == MOI.OPTIMAL
    @test JuMP.objective_value(m) ≈ 4.0
    @test JuMP.value(b) ≈ 0.0
    @test JuMP.value(x) ≈ 1
    @test JuMP.value(y) ≈ 3

    m = Model(CSJuMPTestOptimizer())
    @variable(m, x, CS.Integers([1,2,4]))
    @variable(m, y, CS.Integers([3,4]))
    @variable(m, b, Bin)
    @constraint(m, b == 1)
    @constraint(m, b => {x + y >= 6})
    @objective(m, Min, x+y)
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
    @variable(m, x, CS.Integers([1,2,4]))
    @variable(m, y, CS.Integers([3,4]))
    @variable(m, b, Bin)
    @constraint(m, b => {x + y <= 4})
    @objective(m, Max, x+y)
    optimize!(m)
    @test JuMP.termination_status(m) == MOI.OPTIMAL
    @test JuMP.objective_value(m) ≈ 8.0
    @test JuMP.value(b) ≈ 0.0
    @test JuMP.value(x) ≈ 4
    @test JuMP.value(y) ≈ 4

    m = Model(CSJuMPTestOptimizer())
    @variable(m, x, CS.Integers([1,2,4]))
    @variable(m, y, CS.Integers([3,4]))
    @variable(m, b, Bin)
    @constraint(m, b == 1)
    @constraint(m, b => {x + y <= 4})
    @objective(m, Max, x+y)
    optimize!(m)
    @test JuMP.termination_status(m) == MOI.OPTIMAL
    @test JuMP.objective_value(m) ≈ 4.0
    @test JuMP.value(b) ≈ 1.0
    @test JuMP.value(x) ≈ 1
    @test JuMP.value(y) ≈ 3
    com = JuMP.backend(m).optimizer.model.inner
    @test is_solved(com)
end
end