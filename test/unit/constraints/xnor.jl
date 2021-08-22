@testset "xnor constraint violated or solved?" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, !((sum(x) <= 2) ⊻ (sum(x) > 3)))
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    @test CS.fix!(com, variables[constraint.indices[1]], 1; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[2]], 2; check_feasibility = false)
    @test CS.is_constraint_solved(com, constraint)

    #################

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, !((sum(x) < 2) ⊻ (sum(x) > 4)))
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    @test CS.fix!(com, variables[constraint.indices[1]], 1; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[2]], 1; check_feasibility = false)
    @test CS.is_constraint_solved(com, constraint)

    #################

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b := {!((sum(x) > 3) ⊻ (sum(x) < 2))})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    xor_constraint = com.constraints[1].inner_constraint
    @test CS.fix!(com, variables[xor_constraint.indices[1]], 0; check_feasibility = false)
    @test CS.fix!(com, variables[xor_constraint.indices[2]], 2; check_feasibility = false)
    @test CS.is_constraint_solved(com, xor_constraint)

    ############################### 

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b := {!((sum(x) > 3) ⊻ (sum(x) < 2))})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    xor_constraint = com.constraints[1].inner_constraint
    @test CS.fix!(com, variables[xor_constraint.indices[1]], 0; check_feasibility = false)
    @test CS.fix!(com, variables[xor_constraint.indices[2]], 4; check_feasibility = false)
    @test !CS.is_constraint_solved(com, xor_constraint)

    ##################

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b := {!((sum(x) > 3) ⊻ (sum(x) < 2))})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    @test CS.fix!(com, variables[constraint.indices[2]], 0; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[3]], 1; check_feasibility = false)
    @test CS.is_constraint_violated(com, constraint)


    ##################

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b := {!((sum(x) > 3) ⊻ (x in CS.AllDifferent()))})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    @test CS.fix!(com, variables[constraint.indices[2]], 0; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[3]], 1; check_feasibility = false)
    @test CS.is_constraint_violated(com, constraint)

    ##################

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b := {!((sum(x) > 3) ⊻ (x in CS.TableSet([0 1; 1 0])))})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    @test CS.fix!(com, variables[constraint.indices[2]], 0; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[3]], 1; check_feasibility = false)
    @test CS.is_constraint_violated(com, constraint)
end

@testset "Indicator fixed to 1 xnor constraint violated or solved?" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b => {!((sum(x) > 3) ⊻ (sum(x) < 2))})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    @test CS.fix!(com, variables[constraint.indices[2]], 1; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[3]], 1; check_feasibility = false)
    @test CS.is_constraint_solved(com, constraint)

    #################

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b => {!((sum(x) < 3) ⊻ (sum(x) >= 2))})
    optimize!(m)
    com = CS.get_inner_model(m)


    variables = com.search_space
    constraint = com.constraints[1]
    @test CS.fix!(com, variables[constraint.indices[2]], 1; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[3]], 1; check_feasibility = false)
    @test CS.is_constraint_solved(com, constraint)

    #################

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b => {!((sum(x) < 3) ⊻ (sum(x) > 1))})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    xor_constraint = com.constraints[1].inner_constraint
    @test CS.fix!(com, variables[xor_constraint.indices[1]], 0; check_feasibility = false)
    @test CS.fix!(com, variables[xor_constraint.indices[2]], 2; check_feasibility = false)
    @test CS.is_constraint_solved(com, xor_constraint)

    ##################

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b => {!((sum(x) < 3) ⊻ (sum(x) > 1))})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    @test CS.fix!(com, variables[constraint.indices[2]], 0; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[3]], 0; check_feasibility = false)
    @test CS.is_constraint_violated(com, constraint)
end

@testset "reified xnor constraint prune_constraint!" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b := {!((x[1] <= 2) ⊻ (x[2] <= 2))}) 
    optimize!(m)

    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]

    constr_indices = constraint.indices
    @test CS.fix!(com, variables[constraint.indices[3]], 0; check_feasibility = false)
    @test CS.prune_constraint!(com, constraint)
    @test sort(CS.values(m, x[1])) == [0,1,2]
end

@testset "reified xnor constraint still feasible" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b := {!((x[1] <= 2) ⊻ (x[2] <= 2))}) 
    optimize!(m)

    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    xor_constraint = com.constraints[1].inner_constraint

    constr_indices = xor_constraint.indices
    @test CS.prune_constraint!(com, constraint)
    @test CS.still_feasible(com, xor_constraint, xor_constraint.indices[2], 0)
    @test CS.still_feasible(com, xor_constraint, xor_constraint.indices[2], 3)
end

@testset "xnor constraint still feasible" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, !((x[1]+x[2] <= 2) ⊻ (x[2] <= 2)))
    optimize!(m)

    com = CS.get_inner_model(m)

    variables = com.search_space
    xnor_constraint = com.constraints[1]

    constr_indices = xnor_constraint.indices
    @test CS.still_feasible(com, xnor_constraint, 1, 0)
    @test CS.fix!(com, variables[2], 1; check_feasibility = false)
    @test !CS.still_feasible(com, xnor_constraint, 1, 3)

    ###

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, !((x[1] <= 2) ⊻ (x[2]+x[1] <= 2)))
    optimize!(m)

    com = CS.get_inner_model(m)

    variables = com.search_space
    xnor_constraint = com.constraints[1]

    constr_indices = xnor_constraint.indices
    @test CS.still_feasible(com, xnor_constraint, 2, 0)
    @test CS.fix!(com, variables[1], 1; check_feasibility = false)
    @test !CS.still_feasible(com, xnor_constraint, 2, 3)
end


@testset "xnor constraint prune_constraint" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, 2 <= x[1:2] <= 5, Int)
    @constraint(m, !((x[1]+x[2] < 2) ⊻ (x[2] < 2)))
    optimize!(m)

    com = CS.get_inner_model(m)

    variables = com.search_space
    xnor_constraint = com.constraints[1]

    constr_indices = xnor_constraint.indices
    # is already solved as both are violated no pruning possible
    @test CS.prune_constraint!(com, xnor_constraint)

    ###

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, 2 <= x[1:2] <= 5, Int)
    @constraint(m, !((x[1]+x[2] >= 2) ⊻ (x[2] >= 2)))
    optimize!(m)

    com = CS.get_inner_model(m)

    variables = com.search_space
    xnor_constraint = com.constraints[1]

    constr_indices = xnor_constraint.indices
    # is already solved as both are subconstraints are solved => no pruning possible
    @test CS.prune_constraint!(com, xnor_constraint)

    ###

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, 2 <= x[1:2] <= 5, Int)
    @constraint(m, !((x[1]+x[2] >= 2) ⊻ (x[2] > 4)))
    optimize!(m)

    com = CS.get_inner_model(m)

    variables = com.search_space
    xnor_constraint = com.constraints[1]

    constr_indices = xnor_constraint.indices
    # lhs solved => rhs must be solved
    @test CS.prune_constraint!(com, xnor_constraint)
    @test CS.values(variables[2]) == [5]

    ###

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, 2 <= x[1:2] <= 5, Int)
    @constraint(m, !((x[1]+x[2] <= 2) ⊻ (x[2] > 4)))
    optimize!(m)

    com = CS.get_inner_model(m)

    variables = com.search_space
    xnor_constraint = com.constraints[1]

    constr_indices = xnor_constraint.indices
    # lhs violated => rhs must be complement solved
    @test CS.prune_constraint!(com, xnor_constraint)
    @test sort!(CS.values(variables[2])) == [2,3,4]

    ###

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, !((x[1]+x[2] <= 5) ⊻ (x[2] > 5)))
    optimize!(m)

    com = CS.get_inner_model(m)

    variables = com.search_space
    xnor_constraint = com.constraints[1]

    constr_indices = xnor_constraint.indices
    # rhs violated => lhs must be complement solved
    @test CS.prune_constraint!(com, xnor_constraint)
    # the variables can't be 0 as otherwise we can't fullfil the complement x[1]+x[2] > 5
    @test !CS.has(variables[1], 0)
    @test !CS.has(variables[2], 0)
end