@testset "StrictlyLessThan" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -1 <= x <= 5, Int)
    @variable(m, -1 <= y <= 5, Int)
    @variable(m, -5 <= z <= 6, Int)
    @constraint(m, x + y + z < 4)
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]
    @test CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [1, 1, 1])
    @test !CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [1, 1, 2])

    constr_indices = constraint.indices
    @test !CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[3],
        6,
    )
    @test CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[3],
        5,
    )

    @test CS.fix!(com, com.search_space[constr_indices[2]], 0)
    @test !CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[3],
        5,
    )

    # need to create a backtrack_vec to reverse pruning
    dummy_backtrack_obj = CS.BacktrackObj(com)
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
        5,
    )

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -1 <= x <= 5, Int)
    @variable(m, -1 <= y <= 5, Int)
    @variable(m, -5 <= z <= 6, Int)
    @constraint(m, x + y + z < 4)
    optimize!(m)
    com = CS.get_inner_model(m)
    constraint = com.constraints[1]
    constr_indices = constraint.indices

    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    @test sort(CS.values(com.search_space[1])) == -1:5
    @test sort(CS.values(com.search_space[2])) == -1:5
    @test sort(CS.values(com.search_space[3])) == -5:5 # 6 not possible

    @test CS.fix!(com, com.search_space[constr_indices[3]], 5)
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    @test CS.value(com.search_space[1]) == -1
    @test CS.value(com.search_space[2]) == -1
    @test CS.value(com.search_space[3]) == 5
    @test CS.isfixed(com.search_space[1])
    @test CS.isfixed(com.search_space[2])
    @test CS.isfixed(com.search_space[3])

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -1 <= x <= 5, Int)
    @variable(m, -1 <= y <= 5, Int)
    @variable(m, -5 <= z <= 6, Int)
    @constraint(m, x + y + z < 3.999)
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]
    @test constraint.rhs ≈ 3
    @test constraint.strict_rhs ≈ 3.999
    @test CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [1, 1, 1])
    @test !CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [1, 1, 2])

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -1 <= x <= 5, Int)
    @variable(m, -1 <= y <= 5, Int)
    @variable(m, -5 <= z <= 6, Int)
    @constraint(m, x + y + z < 4.1)
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]
    @test constraint.rhs ≈ 4
    @test constraint.strict_rhs ≈ 4.1
    @test CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [1, 1, 1])
    @test CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [1, 1, 2])

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -1 <= x <= 5, Int)
    @variable(m, -1 <= y <= 5, Int)
    @variable(m, -5 <= z <= 6, Int)
    @constraint(m, x + 0.9y + 1.1z < 4.1)
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]
    @test constraint.strict_rhs ≈ 4.1
    @test CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [1, 1, 1])
    @test !CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [1, 1, 2])
end

@testset "StrictlyGreaterThan (bridged)" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= x <= 1, Int)
    @variable(m, -1 <= y <= 5, Int)
    @variable(m, -6 <= z <= 6, Int)
    @constraint(m, -x + y + z > 4)
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]
    @test !CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [-1, 1, 1])
    @test !CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [-1, 1, 2])
    @test CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [-1, 2, 2])

    constr_indices = constraint.indices
    @test !CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[3],
        -6,
    )
    @test CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[3],
        -5,
    )

    @test CS.fix!(com, com.search_space[constr_indices[2]], 0)
    @test !CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[3],
        -5,
    )

    # need to create a backtrack_vec to reverse pruning
    dummy_backtrack_obj = CS.BacktrackObj(com)
    push!(com.backtrack_vec, dummy_backtrack_obj)
    # reverse previous fix
    CS.reverse_pruning!(com, 1)
    com.c_backtrack_idx = 1

    # now setting it to -5 should be feasible
    @test CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[3],
        -5,
    )

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= x <= 1, Int)
    @variable(m, -1 <= y <= 5, Int)
    @variable(m, -6 <= z <= 6, Int)
    @constraint(m, -x + y + z > 4)
    optimize!(m)
    com = CS.get_inner_model(m)
    constraint = com.constraints[1]
    constr_indices = constraint.indices

    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    @test sort(CS.values(com.search_space[1])) == -5:1
    @test sort(CS.values(com.search_space[2])) == -1:5
    @test sort(CS.values(com.search_space[3])) == -5:6 # -6 not possible

    @test CS.fix!(com, com.search_space[constr_indices[3]], -5)
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    @test CS.value(com.search_space[1]) == -5
    @test CS.value(com.search_space[2]) == 5
    @test CS.value(com.search_space[3]) == -5
    @test CS.isfixed(com.search_space[1])
    @test CS.isfixed(com.search_space[2])
    @test CS.isfixed(com.search_space[3])

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -1 <= x <= 5, Int)
    @variable(m, -1 <= y <= 5, Int)
    @variable(m, -5 <= z <= 6, Int)
    @constraint(m, x + y + z > 3.999)
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]
    @test constraint.rhs ≈ -4
    @test constraint.strict_rhs ≈ -3.999
    @test !CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [1, 1, 1])
    @test CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [1, 1, 2])
    @test CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [1, 1, 3])

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -1 <= x <= 5, Int)
    @variable(m, -1 <= y <= 5, Int)
    @variable(m, -5 <= z <= 6, Int)
    @constraint(m, x + y + z > 4.1)
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]
    @test constraint.rhs ≈ -5
    @test constraint.strict_rhs ≈ -4.1
    @test !CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [1, 1, 1])
    @test !CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [1, 1, 2])

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -1 <= x <= 5, Int)
    @variable(m, -1 <= y <= 5, Int)
    @variable(m, -5 <= z <= 6, Int)
    @constraint(m, x + 0.9y + 1.1z > 4.1)
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]
    @test constraint.strict_rhs ≈ -4.1
    @test !CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [1, 1, 1])
    @test CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [1, 1, 3])
end

@testset "strictly less than is_constraint_violated test" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= x[1:2] <= 5, Int)
    @constraint(m, sum(x) < 7)
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]

    variables = com.search_space
    @test CS.fix!(com, variables[constraint.indices[1]], 5; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[2]], 2; check_feasibility = false)
    @test CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= x[1:2] <= 5, Int)
    @constraint(m, sum(x) < 4)
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]

    variables = com.search_space
    @test CS.fix!(com, variables[constraint.indices[1]], 5; check_feasibility = false)
    @test !CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)
end
