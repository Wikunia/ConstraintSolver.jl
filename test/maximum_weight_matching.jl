@testset "Maximum weighted matching" begin
function neighbors(sym_matrix, i)
    return findall(v -> v != 0, sym_matrix[:, i])
end

@testset "Bipartite example" begin

    # from slide 65 of https://www.slideshare.net/KuoE0/acmicpc-bipartite-matching
    # but set 1 <-> 4 to 4.9 to avoid matching 1 <-> 4 and 3 <-> 5 which also sums to 10
    weight_matrix = [
        0   0 0 4.9 0  2
        0   0 0 3   1 -2
        0   0 0 0   5  0
        4.9 3 5 0   0  0
        0   1 0 0   0  0
        2  -2 0 0   0  0
    ]
    n = 6

    m = Model(CSJuMPTestSolver())
    @variable(m, x[1:n, 1:n], Bin)
    for i=1:n, j=1:n
        if weight_matrix[i,j] == 0 || i > j
            @constraint(m, x[i,j] == 0)
        end
    end
    for i=1:n
        @constraint(m, sum(x[min(i,j), max(i,j)] for j in neighbors(weight_matrix, i)) <= 1)
    end

    @objective(m, Max, sum(weight_matrix .* x))
    optimize!(m)
    @test JuMP.objective_value(m) ≈ 10
    @test JuMP.value(x[1,6]) == 1
    @test JuMP.value(x[2,4]) == 1
    @test JuMP.value(x[3,5]) == 1
    @test sum(JuMP.value.(x[1,1:6])) == 1
    @test sum(JuMP.value.(x[2,1:6])) == 1
    @test sum(JuMP.value.(x[3,1:6])) == 1
    @test sum(JuMP.value.(x[4,1:6])) == 0
    @test sum(JuMP.value.(x[5,1:6])) == 0
    @test sum(JuMP.value.(x[6,1:6])) == 0
end
end
