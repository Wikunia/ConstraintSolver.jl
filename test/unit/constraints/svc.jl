@testset "SVC" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= x <= 5, Int)
    @variable(m, -5 <= y <= 5, Int)
    @constraint(m, x <= y)
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]
    @test constraint isa CS.SingleVariableConstraint

    # doesn't check the length
    @test !CS.is_constraint_solved(com, constraint, [3, 2])
    @test  CS.is_constraint_solved(com, constraint, [2, 2])
    @test  CS.is_constraint_solved(com, constraint, [1, 2])

    constr_indices = constraint.indices
    @test CS.still_feasible(
        com,
        constraint,
        constr_indices[2],
        -5,
    )
    @test CS.fix!(com, com.search_space[constr_indices[2]], 3)
    @test !CS.still_feasible(
        com,
        constraint,
        constr_indices[1],
        4,
    )
    @test CS.still_feasible(
        com,
        constraint,
        constr_indices[1],
        3,
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
        constr_indices[1],
        4,
    )

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= x <= 5, Int)
    @variable(m, -5 <= y <= 5, Int)
    @constraint(m, x <= y)
    optimize!(m)
    com = CS.get_inner_model(m)
    constraint = com.constraints[1]

    # feasible and no changes
    @test CS.prune_constraint!(com, constraint)
    for ind in constr_indices
        @test sort(CS.values(com.search_space[ind])) == -5:5
    end
    @test CS.fix!(com, com.search_space[constr_indices[2]], 4)
    @test CS.prune_constraint!(com, constraint)
    @test sort(CS.values(com.search_space[1])) == -5:4


    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= x <= 5, Int)
    @variable(m, -5 <= y <= 5, Int)
    @constraint(m, x <= y)
    optimize!(m)
    com = CS.get_inner_model(m)
    constraint = com.constraints[1]

    # Should be synced to the other variables
    @test CS.remove_above!(com, com.search_space[constr_indices[2]], 1)
    @test CS.prune_constraint!(com, constraint)
    for ind in constr_indices
        @test sort(CS.values(com.search_space[ind])) == -5:1
    end
end

@testset "svc is_constraint_violated test" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, 0 <= x <= 5, Int)
    @variable(m, 0 <= y <= 3, Int)
    @constraint(m, x <= y)
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]

    variables = com.search_space
    @test CS.fix!(com, variables[constraint.indices[1]], 5; check_feasibility = false)
    @test CS.is_constraint_violated(com, constraint)

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, 0 <= x <= 5, Int)
    @variable(m, 0 <= y <= 3, Int)
    @constraint(m, x <= y)
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]

    variables = com.search_space
    @test CS.fix!(com, variables[constraint.indices[1]], 3; check_feasibility = false)
    @test !CS.is_constraint_violated(com, constraint)
end
