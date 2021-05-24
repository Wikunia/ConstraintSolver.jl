##################################################
#### Check if all possible solutions are found  ##
##################################################


@testset "all solutions and set" begin
    lhs(x) = sum(x) >= 1
    rhs(x) = sum(x) <= 2

    m = Model(optimizer_with_attributes(CS.Optimizer, "logging" => [], "all_optimal_solutions"=>true))
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @variable(m, b, Bin)
    @constraint(m, b >= 1)
    @constraint(m, b := {sum(x) >= 1 && sum(x) <= 2})
    optimize!(m)
    
    com = CS.get_inner_model(m)
    nresults = JuMP.result_count(m)
    results = Set{Tuple{Int,Int}}()
    for i in 1:nresults
        xval = convert.(Int, round.(JuMP.value.(x; result=i)))
        @test (lhs(xval) && rhs(xval))
        push!(results, (xval[1], xval[2]))
    end
    for i in 0:5, j in 0:5
        if lhs([i,j]) && rhs([i,j])
            @test (i,j) in results
        end
    end
end

@testset "all solutions or set" begin
    lhs(x) = sum(x) >= 1
    rhs(x) = sum(x) <= 2

    m = Model(optimizer_with_attributes(CS.Optimizer, "logging" => [], "all_optimal_solutions"=>true))
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @variable(m, b, Bin)
    @constraint(m, b >= 1)
    @constraint(m, b := {sum(x) >= 1 || sum(x) <= 2})
    optimize!(m)
    
    com = CS.get_inner_model(m)
    nresults = JuMP.result_count(m)
    results = Set{Tuple{Int,Int}}()
    for i in 1:nresults
        xval = convert.(Int, round.(JuMP.value.(x; result=i)))
        @test (lhs(xval) || rhs(xval))
        push!(results, (xval[1], xval[2]))
    end
    for i in 0:5, j in 0:5
        if lhs([i,j]) || rhs([i,j])
            @test (i,j) in results
        end
    end
end

@testset "all solutions xor set" begin
    lhs(x) = sum(x) >= 1
    rhs(x) = sum(x) <= 2

    m = Model(optimizer_with_attributes(CS.Optimizer, "logging" => [], "all_optimal_solutions"=>true))
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @variable(m, b, Bin)
    @constraint(m, b >= 1)
    @constraint(m, b := {(sum(x) >= 1) ⊻ (sum(x) <= 2)})
    optimize!(m)
    
    com = CS.get_inner_model(m)
    nresults = JuMP.result_count(m)
    results = Set{Tuple{Int,Int}}()
    for i in 1:nresults
        xval = convert.(Int, round.(JuMP.value.(x; result=i)))
        @test (lhs(xval) ⊻ rhs(xval))
        push!(results, (xval[1], xval[2]))
    end
    for i in 0:5, j in 0:5
        if lhs([i,j]) ⊻ rhs([i,j])
            @test (i,j) in results
        end
    end
end

@testset "all solutions xnor set" begin
    lhs(x) = sum(x) >= 1
    rhs(x) = sum(x) <= 2

    m = Model(optimizer_with_attributes(CS.Optimizer, "logging" => [], "all_optimal_solutions"=>true))
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @variable(m, b, Bin)
    @constraint(m, b >= 1)
    @constraint(m, b := {!((sum(x) >= 1) ⊻ (sum(x) <= 2))})
    optimize!(m)
    
    com = CS.get_inner_model(m)
    nresults = JuMP.result_count(m)
    results = Set{Tuple{Int,Int}}()
    for i in 1:nresults
        xval = convert.(Int, round.(JuMP.value.(x; result=i)))
        @test !((lhs(xval) ⊻ rhs(xval)))
        push!(results, (xval[1], xval[2]))
    end
    for i in 0:5, j in 0:5
        if !(lhs([i,j]) ⊻ rhs([i,j]))
            @test (i,j) in results
        end
    end
end

@testset "all solutions xnor set 2" begin
    lhs(x) = !(sum(x) > 3)
    rhs(x) = sum(x) >= 2
    
    m = Model(optimizer_with_attributes(CS.Optimizer, "logging" => [], "all_optimal_solutions"=>true))
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @variable(m, b, Bin)
    @constraint(m, b >= 1)
    @constraint(m, b := {!((!(sum(x) > 3)) ⊻ (sum(x) >= 2))})
    optimize!(m)
    
    com = CS.get_inner_model(m)
    nresults = JuMP.result_count(m)
    results = Set{Tuple{Int,Int}}()
    for i in 1:nresults
        xval = convert.(Int, round.(JuMP.value.(x; result=i)))
        @test !(lhs(xval) ⊻ rhs(xval))
        push!(results, (xval[1], xval[2]))
    end
    for i in 0:5, j in 0:5
        if !(lhs([i,j]) ⊻ rhs([i,j]))
            @test (i,j) in results
        end
    end
end

#=
@testset "all solutions combined" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "logging" => [], "all_optimal_solutions"=>true))
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @variable(m, b, Bin)
    @constraint(m, b >= 1)
    @constraint(m, b := {(!((!(sum(x) > 3)) ⊻ (sum(x) >= 2))) && (x[1]+2x[2] <= 5)})
    optimize!(m)
    
    com = CS.get_inner_model(m)
    nresults = JuMP.result_count(m)
    results = Set{Tuple{Int,Int}}()
    for i in 1:nresults
        xval = convert.(Int, round.(JuMP.value.(x; result=i)))
        @test !((!(sum(xval) > 3)) ⊻ (sum(xval) >= 2)) && (xval[1]+2xval[2] <= 5)
        push!(results, (xval[1], xval[2]))
    end
    for i in 0:5, j in 0:5
        x = [i,j]
        if !((!(sum(x) > 3)) ⊻ (sum(x) >= 2)) && (x[1]+2x[2] <= 5)
            @test (i,j) in results
        end
    end
end
=#