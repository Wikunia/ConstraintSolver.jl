@testset "indicator" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, x, CS.Integers([-3, 1, 2, 3]))
    @variable(m, y, CS.Integers([-3, 1, 2, 3]))
    @variable(m, b, Bin)
    @constraint(m, b => {x + y + 1 == 5})
    optimize!(m)
    com = CS.get_inner_model(m)
    constraint = get_constraints_by_type(com, CS.IndicatorConstraint)[1]

    @test CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [1, 2, 2])
    @test !CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [1, 2, 3])
    @test CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [0, 2, 3])

    constr_indices = constraint.indices
    @test CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[2],
        -3,
    )
    @test CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[3],
        1,
    )
    # not actually feasible but will not be tested fully here
    CS.fix!(com, com.search_space[constr_indices[1]], 1)
    # will be tested when setting the next
    @test !CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[3],
        -3,
    )

    # need to create a backtrack_vec to reverse pruning
    dummy_backtrack_obj = CS.BacktrackObj(com)
    dummy_backtrack_obj.step_nr = 1
    push!(com.backtrack_vec, dummy_backtrack_obj)
    # reverse previous fix
    CS.reverse_pruning!(com, 1)
    com.c_backtrack_idx = 1
    # now setting it to 1 should be feasible
    @test CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[3],
        -3,
    )

    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    for ind in constr_indices[2:3]
        @test sort(CS.values(com.search_space[ind])) == [-3, 1, 2, 3]
    end
    @test sort(CS.values(com.search_space[1])) == [0, 1]
    # feasible but remove -3
    @test CS.fix!(com, com.search_space[constr_indices[1]], 1)
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    for ind in constr_indices[2:3]
        @test sort(CS.values(com.search_space[ind])) == [1, 2, 3]
    end
    CS.values(com.search_space[constr_indices[1]]) == [1]
end

@testset "indicator is_constraint_violated test" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b, Bin)
    @variable(m, -5 <= x[1:5] <= 5, Int)
    @constraint(m, b => {x in CS.GeqSet()})
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]

    variables = com.search_space
    @test CS.fix!(com, variables[constraint.indices[1]], 1; check_feasibility = false)
    @test CS.remove_above!(
        com,
        variables[constraint.indices[2]],
        3;
        check_feasibility = false,
    )
    @test CS.remove_below!(
        com,
        variables[constraint.indices[3]],
        4;
        check_feasibility = false,
    )
    @test CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b, Bin)
    @variable(m, -5 <= x[1:5] <= 5, Int)
    @constraint(m, b => {x in CS.GeqSet()})
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]

    variables = com.search_space
    @test CS.fix!(com, variables[constraint.indices[1]], 1; check_feasibility = false)
    @test CS.remove_above!(
        com,
        variables[constraint.indices[2]],
        3;
        check_feasibility = false,
    )
    @test CS.remove_below!(
        com,
        variables[constraint.indices[3]],
        3;
        check_feasibility = false,
    )
    @test !CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b, Bin)
    @variable(m, -5 <= x[1:5] <= 5, Int)
    @constraint(m, b => {x in CS.GeqSet()})
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]

    variables = com.search_space
    @test CS.fix!(com, variables[constraint.indices[1]], 0; check_feasibility = false)
    @test CS.remove_above!(
        com,
        variables[constraint.indices[2]],
        3;
        check_feasibility = false,
    )
    @test CS.remove_below!(
        com,
        variables[constraint.indices[3]],
        4;
        check_feasibility = false,
    )
    @test !CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)
end

@testset "indicator is_constraint_violated test" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "backtrack" => false, "logging" => []))
    @variable(m, b, Bin)
    v = [1,2,3,4,5]
    @variable(m, -5 <= x <= 5, Int)
    @constraint(m, b => {v[x] == 2})
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]
    # b is not active so no pruning should happen
    @test sort(CS.values.(m, x)) == -5:5
end