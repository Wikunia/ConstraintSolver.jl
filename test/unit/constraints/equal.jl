@testset "EqualSet" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= x[1:3] <= 5, Int)
    @constraint(m, x in CS.EqualSet())
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]

    # doesn't check the length
    @test !CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [1, 2, 3])
    @test CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [2, 2, 2])

    constr_indices = constraint.indices
    @test CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[2],
        5,
    )
    @test CS.fix!(com, com.search_space[constr_indices[2]], 5)
    @test !CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[3],
        4,
    )
    @test CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[3],
        5,
    )

    # need to create a backtrack_vec to reverse pruning
    dummy_backtrack_obj = CS.BacktrackObj(com)
    dummy_backtrack_obj.step_nr = 1
    push!(com.backtrack_vec, dummy_backtrack_obj)
    # reverse previous fix
    CS.reverse_pruning!(com, 1)
    com.c_backtrack_idx = 1

    # now setting it to 5 should be feasible
    @test CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[3],
        4,
    )

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= x[1:3] <= 5, Int)
    @constraint(m, x in CS.EqualSet())
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
    for ind in constr_indices
        @test CS.value(com.search_space[ind]) == 5
        @test CS.isfixed(com.search_space[ind])
    end

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= x[1:3] <= 5, Int)
    @constraint(m, x in CS.EqualSet())
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]
    constr_indices = constraint.indices

    # Should be synced to the other variables
    @test CS.remove_below!(com, com.search_space[constr_indices[3]], 3)
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    for ind in constr_indices
        @test sort(CS.values(com.search_space[ind])) == 3:5
    end

    @test CS.rm!(com, com.search_space[constr_indices[1]], 5)
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    for ind in constr_indices
        @test sort(CS.values(com.search_space[ind])) == 3:4
    end

    @test CS.rm!(com, com.search_space[constr_indices[2]], 3)
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    for ind in constr_indices
        @test CS.value(com.search_space[ind]) == 4
        @test CS.isfixed(com.search_space[ind])
    end
end

@testset "equalset is_constraint_violated test" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= x[1:5] <= 5, Int)
    @constraint(m, x in CS.EqualSet())
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]

    variables = com.search_space
    @test CS.fix!(com, variables[1], 3; check_feasibility = false)
    @test CS.fix!(com, variables[2], 5; check_feasibility = false)
    @test CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= x[1:5] <= 5, Int)
    @constraint(m, x in CS.EqualSet())
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]

    variables = com.search_space
    @test CS.fix!(com, variables[1], 5; check_feasibility = false)
    @test CS.fix!(com, variables[2], 5; check_feasibility = false)
    @test !CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)
end
