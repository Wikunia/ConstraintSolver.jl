function check_steiner(n::Integer, nb::Integer, x; result=1)
    x_val = convert.(Integer,JuMP.value.(x; result=result))
    # Convert to ints
    solution = [ [j for j in 1:n if x_val[i,j] == 1] for i in 1:nb   ]

    for i = 1:length(solution)
        for j = i+1:length(solution)
            if length(intersect(solution[i], solution[j])) > 1
                @show solution
                @show solution[i]
                @show solution[j]
                return false
            end
        end
    end
    return true
end

# taken from http://hakank.org/julia/constraints/steiner_and.jl
@testset "Steiner tests" begin
@testset "Steiner test for && and || anti constraints with !b" begin
    model = Model(CSJuMPTestOptimizer())

    n = 7

    nb = round(Int,(n * (n-1)) / 6) # number of sets

    @variable(model, x[1:nb,1:n], Bin)
    @constraint(model, x[1,1] == 1) # symmetry breaking

    # atmost 1 element in common
    for i in 1:nb
        @constraint(model,sum(x[i,:]) == 3)
        for j in i+1:nb
            b = @variable(model, [1:n], Bin)
            for k in 1:n 
                @constraint(model, !b[k] := { x[i,k] != 1 || x[j,k] != 1 })
            end
            @constraint(model, sum(b) <= 1)
        end
    end


    # Solve the problem
    optimize!(model)

    status = JuMP.termination_status(model)     
    @test status == MOI.OPTIMAL  
    @test check_steiner(n, nb, x) 
end

@testset "Steiner test for && and || anti constraints with b" begin
    model = Model(CSJuMPTestOptimizer())

    n = 7

    nb = round(Int,(n * (n-1)) / 6) # number of sets

    @variable(model, x[1:nb,1:n], Bin)
    @constraint(model, x[1,1] == 1) # symmetry breaking

    # atmost 1 element in common
    for i in 1:nb
        @constraint(model,sum(x[i,:]) == 3)
        for j in i+1:nb
            b = @variable(model, [1:n], Bin)
            for k in 1:n 
                @constraint(model, b[k] := { x[i,k] == 1 && x[j,k] == 1 })
            end
            @constraint(model, sum(b) <= 1)
        end
    end


    # Solve the problem
    optimize!(model)

    status = JuMP.termination_status(model)     
    @test status == MOI.OPTIMAL   
    @test check_steiner(n, nb, x)
end
end