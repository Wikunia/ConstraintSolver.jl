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
    com = JuMP.backend(m).optimizer.model.inner

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
    com = JuMP.backend(m).optimizer.model.inner

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
    com = JuMP.backend(m).optimizer.model.inner

    constraint = com.constraints[1]
    constr_indices = constraint.indices

    @test CS.fix!(com, com.search_space[constr_indices[2]], 4)
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    for ind in constr_indices
        @test CS.isfixed(com.search_space[ind])
        @test CS.value(com.search_space[ind]) == 4
    end
end
