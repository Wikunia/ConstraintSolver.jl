@testset "Table" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= x <= 5, Int)
    @variable(m, -5 <= y <= 5, Int)
    @variable(m, -5 <= z <= 5, Int)

    tab = [
        1 2 3
        1 3 2
        2 1 3
        2 3 1
        3 1 2
        3 2 1
        4 4 4
    ]

    @constraint(m, [x, y, z] in CS.TableSet(tab))
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]

    # check if impossible values got removed
    constr_indices = constraint.indices
    for ind in constr_indices
        @test sort(CS.values(com.search_space[ind])) == 1:4
    end

    @test !CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [1, 2, 4])
    @test CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [1, 2, 3])

    @test CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[1],
        4,
    )
    @test CS.fix!(com, com.search_space[constr_indices[2]], 2)
    @test !CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[1],
        4,
    )

    # need to create a backtrack_vec to reverse pruning
    dummy_backtrack_obj = CS.BacktrackObj(com)
    dummy_backtrack_obj.step_nr = 1
    push!(com.backtrack_vec, dummy_backtrack_obj)
    # reverse previous fix
    CS.reverse_pruning!(com, 1)
    com.c_backtrack_idx = 1

    @test CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[1],
        4,
    )


    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= x <= 5, Int)
    @variable(m, -5 <= y <= 5, Int)
    @variable(m, -5 <= z <= 5, Int)

    tab = [
        1 2 3
        1 3 2
        2 1 3
        2 3 1
        3 1 2
        3 2 1
        4 4 4
    ]

    @constraint(m, [x, y, z] in CS.TableSet(tab))
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]
    constr_indices = constraint.indices

    @test CS.fix!(com, com.search_space[constr_indices[2]], 2)
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    for ind in constr_indices[[1, 3]]
        @test sort(CS.values(com.search_space[ind])) == [1, 3]
    end

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= x <= 5, Int)
    @variable(m, -5 <= y <= 5, Int)
    @variable(m, -5 <= z <= 5, Int)

    tab = [
        1 2 3
        1 3 2
        2 1 3
        2 3 1
        3 1 2
        3 2 1
        4 4 4
    ]

    @constraint(m, [x, y, z] in CS.TableSet(tab))
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]
    constr_indices = constraint.indices

    @test CS.fix!(com, com.search_space[constr_indices[2]], 4)
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    for ind in constr_indices
        @test CS.isfixed(com.search_space[ind])
        @test CS.value(com.search_space[ind]) == 4
    end
end

@testset "table is_constraint_violated test" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, 0 <= x <= 5, Int)
    @variable(m, 0 <= y <= 3, Int)
    @constraint(m, [x, y] in CS.TableSet([
        1 2
        3 4
        2 1
        2 3
    ]))
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]

    variables = com.search_space
    @test CS.fix!(com, variables[constraint.indices[1]], 1; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[2]], 3; check_feasibility = false)
    @test CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, 0 <= x <= 5, Int)
    @variable(m, 0 <= y <= 3, Int)
    @constraint(m, [x, y] in CS.TableSet([
        1 2
        3 4
        2 1
        2 3
    ]))
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]

    variables = com.search_space
    @test CS.fix!(com, variables[constraint.indices[1]], 1; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[2]], 2; check_feasibility = false)
    @test !CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)
end


@testset "all modulo" begin 
    function modulo(m, x, y, z)
        lbx = !(x isa Integer)  ? round(Int, JuMP.lower_bound(x)) : x
        ubx = !(x isa Integer) ? round(Int, JuMP.upper_bound(x)) : x
        lby = !(y isa Integer) ? round(Int, JuMP.lower_bound(y)) : y
        uby = !(y isa Integer) ? round(Int, JuMP.upper_bound(y)) : y
    
        table =  transpose(reduce(hcat,[ [i,j,i % j] for i in lbx:ubx, j in lby:uby if j != 0]))
        @constraint(m, [x, y, z] in CS.TableSet(table))
    end   

    m = Model(optimizer_with_attributes(CS.Optimizer, "logging" => [], "all_solutions" => true))
    @variable(m, 1 <= x[1:2] <= 10, Int)
    modulo(m,x[1],2,x[2])
    optimize!(m)

    @show JuMP.termination_status(m) == MOI.OPTIMAL
    nresults = JuMP.result_count(m)
    results = Set{Tuple{Int,Int}}()
    for i in 1:nresults
        xv = convert.(Int, round.(JuMP.value.(x; result=i)))
        @test xv[1] % 2 == xv[2] 
        push!(results, (xv[1], xv[2]))
    end

    found_nr = 0
    for i in 1:10, j in 1:10
        if i % 2 == j 
            @test (i,j) in results
            found_nr += 1
        end
    end
    @test found_nr == nresults
end