@testset "LessThan" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -1 <= x <= 5, Int)
    @variable(m, -1 <= y <= 5, Int)
    @variable(m, -5 <= z <= 5, Int)
    @constraint(m, 1.2x + π * y - 2z <= 4.71)
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]
    @test CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [1, 2, 3])
    @test !CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [3, 2, 1])

    constr_indices = constraint.indices
    @test !CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[3],
        -5,
    )
    @test CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[3],
        -4,
    )

    @test CS.fix!(com, com.search_space[constr_indices[2]], 0)
    @test !CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[3],
        -4,
    )

    # need to create a backtrack_vec to reverse pruning
    dummy_backtrack_obj = CS.BacktrackObj(com)
    dummy_backtrack_obj.step_nr = 1
    push!(com.backtrack_vec, dummy_backtrack_obj)
    # reverse previous fix
    CS.reverse_pruning!(com, 1)
    com.c_backtrack_idx = 1

    # now setting it to -4 should be feasible
    @test CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[3],
        -4,
    )

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -1 <= x <= 5, Int)
    @variable(m, -1 <= y <= 5, Int)
    @variable(m, -5 <= z <= 5, Int)
    @constraint(m, 1.2x + π * y - 2z <= 4.71)
    optimize!(m)
    com = CS.get_inner_model(m)
    constraint = com.constraints[1]
    constr_indices = constraint.indices

    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    @test sort(CS.values(com.search_space[1])) == -1:5
    @test sort(CS.values(com.search_space[2])) == -1:5
    @test sort(CS.values(com.search_space[3])) == -4:5

    @test CS.fix!(com, com.search_space[constr_indices[3]], -4)
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    @test CS.value(com.search_space[1]) == -1
    @test CS.value(com.search_space[2]) == -1
    @test CS.value(com.search_space[3]) == -4
    @test CS.isfixed(com.search_space[1])
    @test CS.isfixed(com.search_space[2])
    @test CS.isfixed(com.search_space[3])
end

@testset "less than is_constraint_violated test" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= x[1:2] <= 5, Int)
    @constraint(m, sum(x) <= 7)
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]

    variables = com.search_space
    @test CS.fix!(com, variables[constraint.indices[1]], 5; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[2]], 3; check_feasibility = false)
    @test CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= x[1:2] <= 5, Int)
    @constraint(m, sum(x) <= 7)
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]

    variables = com.search_space
    @test CS.fix!(com, variables[constraint.indices[1]], 5; check_feasibility = false)
    @test !CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)
end

@testset "constraint without variables" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "logging" => []))
    @variable(m, -5 <= x[1:2] <= 5, Int)
    @constraint(m, x[2] - x[1] >= x[2]-x[1] + 10)
    optimize!(m)
    @test JuMP.termination_status(m) == MOI.INFEASIBLE

    m = Model(optimizer_with_attributes(CS.Optimizer, "logging" => []))
    @variable(m, -5 <= x[1:2] <= 5, Int)
    @constraint(m, x[2] - x[1] + (-x[2]) + x[1] <= 0)
    optimize!(m)
    @test JuMP.termination_status(m) == MOI.OPTIMAL

    m = Model(optimizer_with_attributes(CS.Optimizer, "logging" => []))
    @variable(m, -5 <= x[1:2] <= 5, Int)
    @constraint(m, sum(0 .* x) <= 1)
    optimize!(m)
    @test JuMP.termination_status(m) == MOI.OPTIMAL
end
