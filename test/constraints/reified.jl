@testset "ReifiedConstraint" begin
@testset "Basic ==" begin
    m = Model(CSJuMPTestOptimizer())
    @variable(m, x, CS.Integers([1,2,4]))
    @variable(m, y, CS.Integers([3,4]))
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

@testset "Basic == where not active" begin
    m = Model(CSJuMPTestOptimizer())
    @variable(m, x, CS.Integers([1,2,4,5]))
    @variable(m, y, CS.Integers([3,4]))
    @variable(m, b, Bin)
    @constraint(m, b := {x + y == 7})
    @objective(m, Max, b+x+y)
    optimize!(m)
    @test JuMP.termination_status(m) == MOI.OPTIMAL
    @test JuMP.objective_value(m) ≈ 9.0
    @test JuMP.value(b) ≈ 0.0
    @test JuMP.value(x) ≈ 5
    @test JuMP.value(y) ≈ 4
    com = JuMP.backend(m).optimizer.model.inner
    @test is_solved(com)
end

@testset "Alldifferent" begin
    m = Model(CSJuMPTestOptimizer())
    @variable(m, x, CS.Integers([1,2,4]))
    @variable(m, y, CS.Integers([2,3,4]))
    @variable(m, b, Bin)
    @constraint(m, b := {[x,y] in CS.AllDifferentSet()})
    @objective(m, Max, 0.9*b+x+y)
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
    @variable(m, x, CS.Integers([1,2,4]))
    @variable(m, y, CS.Integers([1,2,3,4]))
    @variable(m, b, Bin)
    @constraint(m, !b := {[x,y] in CS.AllDifferentSet()})
    @objective(m, Min, 0.9*b+x+y)
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
    @variable(m, x, CS.Integers([1,2,4]))
    @variable(m, y, CS.Integers([2,4]))
    @variable(m, b, Bin)
    @constraint(m, b := {[x,y] in CS.AllDifferentSet()})
    @objective(m, Max, 5b+x+y)
    optimize!(m)
    @test JuMP.termination_status(m) == MOI.OPTIMAL
    @test JuMP.objective_value(m) ≈ 11.0
    @test JuMP.value(b) ≈ 1.0
    @test JuMP.value(x) ≈ 2 || JuMP.value(y) ≈ 2
    @test JuMP.value(x) ≈ 4 || JuMP.value(y) ≈ 4
    com = JuMP.backend(m).optimizer.model.inner
    @test is_solved(com)
end
end