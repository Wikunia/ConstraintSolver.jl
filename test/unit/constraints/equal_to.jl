@testset "equal_to_prune_two" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= x[1:4] <= 5, Int)
    @constraint(m, sum(x) == 10)
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = get_constraints_by_type(com, CS.LinearConstraint)[1]
    @test constraint.is_equal
    @test CS.count_unfixed(com, constraint) == 4
    x_var = com.search_space[constraint.indices]
    # fix two and test that it is still feasible
    @test CS.fix!(com, x_var[1], 3)
    @test CS.fix!(com, x_var[2], -3)

    # here 3 and 4 must be equal to 5 and we can prune with
    # prune_is_equal_two_var!
    @test CS.prune_is_equal_two_var!(com, constraint, constraint.fct)
    @test CS.values(x_var[3]) == [5]
    @test CS.values(x_var[4]) == [5]
end

@testset "equal_to_prune_two in all different" begin
    # test if 3 and 4 are also in all different constraint
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= x[1:4] <= 5, Int)
    @constraint(m, sum(x) == 10)
    @constraint(m, x[3:4] in CS.AllDifferent())
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = get_constraints_by_type(com, CS.LinearConstraint)[1]
    x_var = com.search_space[constraint.indices]
    # fix two and test that it is still feasible
    @test CS.fix!(com, x_var[1], 3)
    @test CS.fix!(com, x_var[2], -3)
    @test CS.count_unfixed(com, constraint) == 2
    # not feasible as 3 and 4 would need to be 5 but there is an all different constraint
    @test !CS.prune_is_equal_two_var!(com, constraint, constraint.fct)
end

@testset "equal_to_prune_two not in same all different" begin
    # test if 3 and 4 are also in all different constraint
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= x[1:4] <= 5, Int)
    @constraint(m, sum(x) == 10)
    @constraint(m, x[1:3] in CS.AllDifferent())
    @constraint(m, [x[2], x[4]] in CS.AllDifferent())
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = get_constraints_by_type(com, CS.LinearConstraint)[1]
    x_var = com.search_space[constraint.indices]
    # fix two and test that it is still feasible
    @test CS.fix!(com, x_var[1], 3)
    @test CS.fix!(com, x_var[2], -3)
    @test CS.count_unfixed(com, constraint) == 2
    # feasible as 3 and 4 can be 5
    @test CS.prune_is_equal_two_var!(com, constraint, constraint.fct)
    @test CS.values(x_var[3]) == [5]
    @test CS.values(x_var[4]) == [5]
end

@testset "equal_to" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, y[1:3], CS.Integers([-3, 1, 2, 3]))
    @constraint(m, sum(y) + 1 == 5)
    optimize!(m)
    com = CS.get_inner_model(m)
    constraint = get_constraints_by_type(com, CS.LinearConstraint)[1]

    # doesn't check the length
    # 1+2+1 + constant (1) == 5
    @test  CS.is_constraint_solved(com, constraint, [1, 2, 1])
    @test !CS.is_constraint_solved(com, constraint, [1, 2, 2])

    constr_indices = constraint.indices
    @test !CS.still_feasible(
        com,
        constraint,
        constr_indices[1],
        -3,
    )
    @test CS.still_feasible(
        com,
        constraint,
        constr_indices[1],
        1,
    )
    # not actually feasible but will not be tested fully here
    CS.fix!(com, com.search_space[constr_indices[1]], 3)
    # will be tested when setting the next
    @test !CS.still_feasible(
        com,
        constraint,
        constr_indices[3],
        1,
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
        constr_indices[3],
        1,
    )


    # feasible but remove -3 and 3
    CS.set_first_node_call!(constraint, true)
    @test CS.prune_constraint!(com, constraint)
    for ind in constr_indices
        @test sort(CS.values(com.search_space[ind])) == [1, 2]
    end
    @test CS.fix!(com, com.search_space[constr_indices[1]], 2)
    @test CS.prune_constraint!(com, constraint)
    for ind in constr_indices[2:3]
        @test CS.values(com.search_space[ind]) == [1]
    end
    CS.values(com.search_space[constr_indices[1]]) == [2]
end

@testset "eqsum is_constraint_violated test" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= x[1:2] <= 5, Int)
    @constraint(m, sum(x) == 10)
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = get_constraints_by_type(com, CS.LinearConstraint)[1]

    variables = com.search_space
    @test CS.fix!(com, variables[1], 1; check_feasibility = false)
    @test CS.fix!(com, variables[2], 1; check_feasibility = false)
    @test CS.is_constraint_violated(com, constraint)

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= x[1:2] <= 5, Int)
    @constraint(m, sum(x) == 10)
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = get_constraints_by_type(com, CS.LinearConstraint)[1]

    variables = com.search_space
    @test CS.fix!(com, variables[1], 5; check_feasibility = false)
    @test CS.fix!(com, variables[2], 5; check_feasibility = false)
    @test !CS.is_constraint_violated(com, constraint)
end

@testset "constraint without variables" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "logging" => []))
    @variable(m, -5 <= x[1:2] <= 5, Int)
    @constraint(m, x[2] - x[1] + (-x[2]) + x[1] == 10)
    optimize!(m)
    @test JuMP.termination_status(m) == MOI.INFEASIBLE

    m = Model(optimizer_with_attributes(CS.Optimizer, "logging" => []))
    @variable(m, -5 <= x[1:2] <= 5, Int)
    @constraint(m, x[2] - x[1] + (-x[2]) + x[1] == 0)
    optimize!(m)
    @test JuMP.termination_status(m) == MOI.OPTIMAL
end
