@testset "IndicatorConstraint" begin
@testset "Basic I" begin
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
end

@testset "Basic II" begin
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
end
end