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
    dummy_backtrack_obj.step_nr = 1
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
    @constraint(m, b := {x in CS.AllDifferent()})
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
    @constraint(m, b := {x in CS.AllDifferent()})
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
    @constraint(m, b := {x in CS.AllDifferent()})
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]

    variables = com.search_space
    @test CS.fix!(com, variables[constraint.indices[1]], 0; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[2]], 3; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[3]], 3; check_feasibility = false)
    @test !CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)
end

@testset "reified complement prune" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b, Bin)
    @variable(m, 0 <= x[1:3] <= 15, Int)
    @constraint(m, b := {sum(x) > 10})
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]
    complement_constraint = constraint.complement_constraint
    @test complement_constraint.set == MOI.LessThan(10.0)
    @test all(term.coefficient == 1 for term in complement_constraint.fct.terms)
    @test complement_constraint.fct.constant == 0

    variables = com.search_space
    constr_indices = constraint.indices
    # set inactive
    @test CS.fix!(com, variables[constr_indices[1]], 0; check_feasibility = false)
    # should prune complement
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)

    for ind in constr_indices[2:4]
        @test sort(CS.values(com.search_space[ind])) == collect(0:10)
    end

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b, Bin)
    @variable(m, 0 <= x[1:3] <= 5, Int)
    @constraint(m, b := {sum(x) <= 10})
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]
    complement_constraint = constraint.complement_constraint
    @test complement_constraint.set == CS.Strictly(MOI.LessThan(-10.0))
    @test all(term.coefficient == -1 for term in complement_constraint.fct.terms)
    @test complement_constraint.fct.constant == 0

    variables = com.search_space
    constr_indices = constraint.indices
    # set inactive
    @test CS.fix!(com, variables[constr_indices[1]], 0; check_feasibility = false)
    # should prune complement
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)

    for ind in constr_indices[2:4]
        @test sort(CS.values(com.search_space[ind])) == collect(1:5)
    end

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b, Bin)
    @variable(m, 0 <= x[1:3] <= 5, Int)
    @constraint(m, b := {sum(x) == 10})
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]
    complement_constraint = constraint.complement_constraint
    @test complement_constraint.set == CS.NotEqualTo(10.0)
    @test all(term.coefficient == 1 for term in complement_constraint.fct.terms)
    @test complement_constraint.fct.constant == 0

    variables = com.search_space
    constr_indices = constraint.indices
    # set inactive
    @test CS.fix!(com, variables[constr_indices[1]], 0; check_feasibility = false)
    @test CS.fix!(com, variables[constr_indices[2]], 0; check_feasibility = false)
    @test CS.fix!(com, variables[constr_indices[3]], 5; check_feasibility = false)
    # should prune complement
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)

    for ind in constr_indices[4]
        @test sort(CS.values(com.search_space[ind])) == collect(0:4)
    end

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b, Bin)
    @variable(m, 0 <= x[1:3] <= 5, Int)
    @constraint(m, b := {sum(x) != 10})
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = com.constraints[1]
    complement_constraint = constraint.complement_constraint
    @test complement_constraint.set == MOI.EqualTo(10.0)
    @test all(term.coefficient == 1 for term in complement_constraint.fct.terms)
    @test complement_constraint.fct.constant == 0

    variables = com.search_space
    constr_indices = constraint.indices
    # set inactive
    @test CS.fix!(com, variables[constr_indices[1]], 0; check_feasibility = false)
    @test CS.fix!(com, variables[constr_indices[2]], 0; check_feasibility = false)
    @test CS.fix!(com, variables[constr_indices[3]], 5; check_feasibility = false)
    CS.changed!(com, constraint, constraint.fct, constraint.set)
    # should prune complement
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)

    for ind in constr_indices[4]
        @test sort(CS.values(com.search_space[ind])) == [5]
    end
end

@testset "still_feasible reified active and inactive" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b := {sum(x) > 10})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    constr_indices = constraint.indices
    # set such that b must be 0
    @test CS.fix!(com, variables[constr_indices[2]], 0; check_feasibility = false)
    @test CS.fix!(com, variables[constr_indices[3]], 0; check_feasibility = false)
    
    @test !CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[1],
        1,
    )
    @test CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[1],
        0,
    )

    # same but b must be 1

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b := {sum(x) > 9})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    constr_indices = constraint.indices
    # set such that b must be 0
    @test CS.fix!(com, variables[constr_indices[2]], 5; check_feasibility = false)
    @test CS.fix!(com, variables[constr_indices[3]], 5; check_feasibility = false)
    
    @test !CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[1],
        0,
    )
    @test CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[1],
        1,
    )
end