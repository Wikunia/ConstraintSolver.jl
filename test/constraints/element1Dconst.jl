@testset "Element1DConstConstraint" begin
@testset "Simple" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "all_solutions" => true, "logging" => []))
    c = [1,2,3,7,9,10, 12, 15]
    @variable(m, 1 <= idx <= 12, Int)
    @variable(m, -12 <= val <= 12, Int)
    @constraint(m, [val, idx] in CS.Element1DConst(c))
    optimize!(m)

    status = JuMP.termination_status(m)
    @test status == MOI.OPTIMAL
    num_sols = MOI.get(m, MOI.ResultCount())
    @test num_sols == 7
    possible_sols = Tuple[]

    for sol in 1:num_sols
        idx_val = convert.(Integer,JuMP.value.(idx; result=sol))
        val_val = convert.(Integer,JuMP.value.(val; result=sol))
        push!(possible_sols, (idx_val, val_val))
    end
    @test (1,1) in possible_sols
    @test (2,2) in possible_sols
    @test (3,3) in possible_sols
    @test (4,7) in possible_sols
    @test (5,9) in possible_sols
    @test (6,10) in possible_sols
    @test (7,12) in possible_sols
end

@testset "Sorting" begin
    m = Model(CSJuMPTestOptimizer())
    seed = rand(1:10000)
    println("Seed for sorting test: ", seed)
    Random.seed!(seed)
    c = rand(1:1000, 50)
    @variable(m, 1 <= idx[1:length(c)] <= length(c), Int)
    @variable(m, minimum(c) <= val[1:length(c)] <= maximum(c), Int)
    for i in 1:length(c)-1
        @constraint(m, val[i] <= val[i+1])
    end
    for i in 1:length(c)
        @constraint(m, c[idx[i]] == val[i])
    end
    @constraint(m, idx in CS.AllDifferentSet())
    optimize!(m)
    @test JuMP.termination_status(m) == MOI.OPTIMAL
    vals = convert.(Int, JuMP.value.(val))
    idxs = convert.(Int, JuMP.value.(idx))
    @test issorted(vals)
    @test c[idxs] == vals
end

@testset "Two Element in indicator " begin
    m = Model(CSJuMPTestOptimizer())
    c = collect(1:5)
    crev = reverse(c)
    @variable(m, b, Bin)
    @constraint(m, b > 0.5)
    @variable(m, 1 <= idx <= length(c), Int)
    @constraint(m, b => {c[idx] == crev[idx]})
    optimize!(m)
    @test JuMP.termination_status(m) == MOI.OPTIMAL
    idx_val = convert(Int, JuMP.value(idx))
    @test c[idx_val] == crev[idx_val]
end

@testset "Two Element in reified" begin
    m = Model(CSJuMPTestOptimizer())
    c = collect(1:5)
    crev = reverse(c)
    @variable(m, b, Bin)
    @constraint(m, b > 0.5)
    @variable(m, 1 <= idx <= length(c), Int)
    @constraint(m, b := {c[idx] == crev[idx]})
    optimize!(m)
    @test JuMP.termination_status(m) == MOI.OPTIMAL
    idx_val = convert(Int, JuMP.value(idx))
    @test c[idx_val] == crev[idx_val]
end

@testset "element in indicator/reified with or" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "logging" => []))
    c = collect(1:5)
    crev = reverse(c)
    @variable(m, b, Bin)
    @constraint(m, b > 0.5)
    @variable(m, 1 <= idx <= length(c), Int)
    @constraint(m, b := {c[idx] == crev[idx] || idx >= 2})
    @objective(m, Min, idx)
    optimize!(m)

    @test JuMP.termination_status(m) == MOI.OPTIMAL
    @test convert(Int, JuMP.value(idx)) == 2 

    m = Model(optimizer_with_attributes(CS.Optimizer, "logging" => []))
    c = collect(1:5)
    crev = reverse(c)
    @variable(m, b, Bin)
    @constraint(m, b > 0.5)
    @variable(m, 1 <= idx <= length(c), Int)
    @constraint(m, b := {idx <= 2 || c[idx] == crev[idx]})
    @objective(m, Max, idx)
    optimize!(m)

    @test JuMP.termination_status(m) == MOI.OPTIMAL
    @test convert(Int, JuMP.value(idx)) == 3
end

@testset "element in indicator/reified with and + or" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "logging" => []))
    c = collect(1:5)
    crev = reverse(c)
    @variable(m, b, Bin)
    @constraint(m, b > 0.5)
    @variable(m, 1 <= idx <= length(c), Int)
    @constraint(m, b := {c[idx] == crev[idx] && idx <= 2 || idx >= 4})
    @objective(m, Min, idx)
    optimize!(m)

    @test JuMP.termination_status(m) == MOI.OPTIMAL
    @test convert(Int, JuMP.value(idx)) == 4

    m = Model(optimizer_with_attributes(CS.Optimizer, "logging" => []))
    c = collect(1:5)
    crev = reverse(c)
    @variable(m, b, Bin)
    @constraint(m, b > 0.5)
    @variable(m, 1 <= idx <= length(c), Int)
    @constraint(m, b := {idx <= 2 || idx >= 2 && c[idx] == crev[idx]})
    @objective(m, Max, idx)
    optimize!(m)

    @test JuMP.termination_status(m) == MOI.OPTIMAL
    @test convert(Int, JuMP.value(idx)) == 3
end
end