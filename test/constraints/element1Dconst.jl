@testset "Element1DConstConstraint" begin
@testset "Simple" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "all_solutions" => true))
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
end