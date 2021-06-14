@testset "Xor" begin
@testset "Xor basic all solutions" begin
    m = Model(optimizer_with_attributes(
        CS.Optimizer,
        "all_solutions" => true,
        "logging" => [],
    ))
    @variable(m, 1 <= x <= 5, Int)
    @variable(m, 1 <= y <= 5, Int)
    @constraint(m, (x <= 2) ⊻ (y <= 2))
    optimize!(m)

    num_sols = MOI.get(m, MOI.ResultCount())
    @test num_sols == count((i <= 2) ⊻ (j <= 2) for i=1:5, j=1:5)
    for i in 1:num_sols
        xval = convert(Int, JuMP.value(x; result=i))
        yval = convert(Int, JuMP.value(y; result=i))
        @test (xval <= 2) ⊻ (yval <= 2)
    end
end
end