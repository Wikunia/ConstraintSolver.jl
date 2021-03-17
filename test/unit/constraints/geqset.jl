@testset "EqualSet" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= y <= 5, Int)
    @variable(m, -5 <= x[1:2] <= 5, Int)
    @constraint(m, [y, x...] in CS.GeqSet())
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]

    # doesn't check the length
    @test !CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [1, 2, 3])
    @test CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [3, 2, 1])

    constr_indices = constraint.indices
    @test CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[1],
        3,
    )
    @test CS.fix!(com, com.search_space[constr_indices[1]], 3)
    @test !CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[2],
        4,
    )
    @test CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[3],
        2,
    )

    # need to create a backtrack_vec to reverse pruning
    dummy_backtrack_obj = CS.BacktrackObj(com)
    dummy_backtrack_obj.step_nr = 1
    push!(com.backtrack_vec, dummy_backtrack_obj)
    # reverse previous fix
    CS.reverse_pruning!(com, 1)
    com.c_backtrack_idx = 1

    # now setting it to 4 should be feasible
    @test CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[2],
        4,
    )

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= y <= 5, Int)
    @variable(m, -5 <= x[1:2] <= 5, Int)
    @constraint(m, [y, x...] in CS.GeqSet())
    optimize!(m)
    com = CS.get_inner_model(m)
    constraint = com.constraints[1]
    constr_indices = constraint.indices

    # feasible and no changes
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    for ind in constr_indices
        @test sort(CS.values(com.search_space[ind])) == -5:5
    end
    @test CS.fix!(com, com.search_space[constr_indices[2]], 5)
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    @test CS.value(com.search_space[constr_indices[1]]) == 5
    @test CS.isfixed(com.search_space[constr_indices[1]])

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= y <= 5, Int)
    @variable(m, -5 <= x[1:2] <= 5, Int)
    @constraint(m, [y, x...] in CS.GeqSet())
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]
    constr_indices = constraint.indices

    # Should be synced to the first variable
    @test CS.remove_below!(com, com.search_space[constr_indices[3]], 4)
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    @test sort(CS.values(com.search_space[constr_indices[1]])) == 4:5

    @test CS.rm!(com, com.search_space[constr_indices[1]], 5)
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    @test sort(CS.values(com.search_space[constr_indices[2]])) == -5:4
    @test sort(CS.values(com.search_space[constr_indices[3]])) == 4:4
end

@testset "geqset is_constraint_violated test" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= x[1:5] <= 5, Int)
    @constraint(m, x in CS.GeqSet())
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]

    variables = com.search_space
    @test CS.fix!(com, variables[1], 3; check_feasibility = false)
    @test CS.remove_below!(com, variables[2], 4; check_feasibility = false)
    @test CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= x[1:5] <= 5, Int)
    @constraint(m, x in CS.GeqSet())
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]

    variables = com.search_space
    @test CS.fix!(com, variables[1], -5; check_feasibility = false)
    @test CS.fix!(com, variables[2], -5; check_feasibility = false)
    @test !CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)
end
