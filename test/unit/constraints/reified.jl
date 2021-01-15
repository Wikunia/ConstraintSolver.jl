@testset "reified > bridge" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b, Bin)
    @variable(m, 0 <= x[1:3] <= 5, Int)
    @constraint(m, b := {sum(x) > 10})
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]

    variables = com.search_space
    @test CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [1, 3, 3, 5])
    @test !CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [1, 2, 3, 5])
    @test CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [0, 2, 3, 5])

    constr_indices = constraint.indices
    @test CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[2],
        1,
    )
    @test CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[2],
        0,
    )
    CS.fix!(com, com.search_space[constr_indices[1]], 1)
    @test !CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[3],
        0,
    )

    # need to create a backtrack_vec to reverse pruning
    dummy_backtrack_obj = CS.BacktrackObj(com)
    push!(com.backtrack_vec, dummy_backtrack_obj)
    # reverse previous fix
    CS.reverse_pruning!(com, 1)
    com.c_backtrack_idx = 1

    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    for ind in constr_indices[2:4]
        @test sort(CS.values(com.search_space[ind])) == [0,1,2,3,4,5]
    end
    @test sort(CS.values(com.search_space[constr_indices[1]])) == [0, 1]
    @test CS.fix!(com, com.search_space[constr_indices[1]], 1)
    # feasible but remove 0
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    for ind in constr_indices[2:4]
        @test sort(CS.values(com.search_space[ind])) == [1, 2, 3, 4, 5]
    end
    CS.values(com.search_space[constr_indices[1]]) == [1]
end

@testset "reified > bridge is_constraint_violated" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b, Bin)
    @variable(m, -5 <= x[1:3] <= 5, Int)
    @constraint(m, b := {sum(x) > 10})
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]

    variables = com.search_space
    @test CS.fix!(com, variables[constraint.indices[1]], 1; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[2]], 3; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[3]], 2; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[4]], 5; check_feasibility = false)
    @test CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b, Bin)
    @variable(m, -5 <= x[1:3] <= 5, Int)
    @constraint(m, b := {sum(x) > 10})
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]

    variables = com.search_space
    @test CS.fix!(com, variables[constraint.indices[1]], 1; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[2]], 3; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[3]], 3; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[4]], 5; check_feasibility = false)
    @test !CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b, Bin)
    @variable(m, -5 <= x[1:3] <= 5, Int)
    @constraint(m, b := {sum(x) > 10})
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]

    variables = com.search_space
    @test CS.fix!(com, variables[constraint.indices[1]], 0; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[2]], 3; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[3]], 3; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[4]], 5; check_feasibility = false)
    @test CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)
end


@testset "reified is_constraint_violated test" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b, Bin)
    @variable(m, -5 <= x[1:5] <= 5, Int)
    @constraint(m, b := {x in CS.AllDifferentSet()})
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]

    variables = com.search_space
    @test CS.fix!(com, variables[constraint.indices[1]], 1; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[2]], 3; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[3]], 3; check_feasibility = false)
    @test CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b, Bin)
    @variable(m, -5 <= x[1:5] <= 5, Int)
    @constraint(m, b := {x in CS.AllDifferentSet()})
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]

    variables = com.search_space
    @test CS.fix!(com, variables[constraint.indices[1]], 1; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[2]], 1; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[3]], 3; check_feasibility = false)
    @test !CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b, Bin)
    @variable(m, -5 <= x[1:5] <= 5, Int)
    @constraint(m, b := {x in CS.AllDifferentSet()})
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]

    variables = com.search_space
    @test CS.fix!(com, variables[constraint.indices[1]], 0; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[2]], 3; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[3]], 3; check_feasibility = false)
    @test !CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)
end
