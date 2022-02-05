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
    @constraint(m, idx in CS.AllDifferent())
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

    m = Model(optimizer_with_attributes(CS.Optimizer, "logging" => []))
    c = collect(1:5)
    @variable(m, b, Bin)
    @constraint(m, b > 0.5)
    @variable(m, 1 <= idx <= length(c), Int)
    @constraint(m, b := {idx < 2 || (c[idx] == 2 && idx >= 3)})
    @objective(m, Max, idx)
    optimize!(m)

    @test JuMP.termination_status(m) == MOI.OPTIMAL
    @test convert(Int, JuMP.value(idx)) == 1

    m = Model(optimizer_with_attributes(CS.Optimizer, "logging" => [], "all_optimal_solutions"=>true))
    c = collect(1:5)
    crev = collect(5:-1:1)
    @variable(m, b, Bin)
    @constraint(m, b < 0.5)
    @variable(m, 1 <= idx <= length(c), Int)
    @constraint(m, b := {c[idx] == crev[idx]})
    optimize!(m)

    @test JuMP.termination_status(m) == MOI.OPTIMAL
    num_sols = MOI.get(m, MOI.ResultCount())
    @test num_sols == 4
    for i in 1:num_sols
        idx_var = convert.(Int, JuMP.value.(idx; result=i));
        @test c[idx_var] != crev[idx_var]
    end
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

@testset "element in OrConstraint outside activator constraint" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "logging" => []))
    c = collect(1:5)
    crev = reverse(c)
    @variable(m, 1 <= idx <= length(c), Int)
    @constraint(m, (c[idx] == crev[idx] && idx <= 2) || idx >= 4)
    @objective(m, Min, idx)
    optimize!(m)

    @test JuMP.termination_status(m) == MOI.OPTIMAL
    @test convert(Int, JuMP.value(idx)) == 4

    m = Model(optimizer_with_attributes(CS.Optimizer, "logging" => []))
    c = collect(1:5)
    crev = reverse(c)
    @variable(m, 1 <= idx <= length(c), Int)
    @constraint(m, idx <= 2 || (idx >= 2 && c[idx] == crev[idx]))
    @objective(m, Max, idx)
    optimize!(m)

    @test JuMP.termination_status(m) == MOI.OPTIMAL
    @test convert(Int, JuMP.value(idx)) == 3
end

@testset "element in AndConstraint outside activator constraint" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "logging" => []))
    c1 = [1,2,3,4,5,6,7]
    c2 = [1,3,2,4,6,5,7]
    @variable(m, 1 <= idx <= length(c1), Int)
    @constraint(m, (c1[idx] == c2[idx] && idx != 7))
    @objective(m, Max, idx)
    optimize!(m)

    @test JuMP.termination_status(m) == MOI.OPTIMAL
    @test convert(Int, JuMP.value(idx)) == 4
end

@testset "Element in XorConstraint inside activator" begin 
    m = Model(optimizer_with_attributes(CS.Optimizer, "logging" => [], "all_optimal_solutions" => true))
    c1 = [1,2,3,4,5,6,7]
    c2 = [1,3,2,4,6,5,7]
    @variable(m, b, Bin)
    @variable(m, 1 <= idx <= length(c1), Int)
    @constraint(m, b := { (c1[idx] == c2[idx]) ⊻ (idx != 6)})
    @objective(m, Max, idx+b)
    optimize!(m)

    @test JuMP.termination_status(m) == MOI.OPTIMAL
    @test convert(Int, JuMP.value(idx)) == 7
    @test convert(Int, JuMP.value(b)) == 0
    @test JuMP.result_count(m) == 1

    # minimize
    m = Model(optimizer_with_attributes(CS.Optimizer, "logging" => [], "all_optimal_solutions" => true))
    c1 = [1,2,3,4,5,6,7]
    c2 = [1,3,2,4,6,5,7]
    @variable(m, b, Bin)
    @variable(m, 1 <= idx <= length(c1), Int)
    @constraint(m, b := { (c1[idx] == c2[idx]) ⊻ (idx == 1)})
    @objective(m, Min, idx)
    optimize!(m)

    @test JuMP.termination_status(m) == MOI.OPTIMAL
    @test convert(Int, JuMP.value(idx)) == 1
    @test convert(Int, JuMP.value(b)) == 0
    @test JuMP.result_count(m) == 1
end

end
