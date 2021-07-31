@testset "xor constraint violated or solved?" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, (sum(x) <= 2) ⊻ (sum(x) > 3))
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    @test CS.fix!(com, variables[constraint.indices[1]], 1; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[2]], 2; check_feasibility = false)
    @test CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)

    #################

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, (sum(x) < 2) ⊻ (sum(x) > 4))
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    @test CS.fix!(com, variables[constraint.indices[1]], 1; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[2]], 1; check_feasibility = false)
    @test CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)

    #################

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b := {(sum(x) > 3) ⊻ (sum(x) < 2)})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    xor_constraint = com.constraints[1].inner_constraint
    @test CS.fix!(com, variables[xor_constraint.indices[1]], 0; check_feasibility = false)
    @test CS.fix!(com, variables[xor_constraint.indices[2]], 2; check_feasibility = false)
    @test CS.is_constraint_violated(com, xor_constraint, xor_constraint.fct, xor_constraint.set)

    ############################### 

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b := {(sum(x) > 3) ⊻ (sum(x) < 2)})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    xor_constraint = com.constraints[1].inner_constraint
    @test CS.fix!(com, variables[xor_constraint.indices[1]], 0; check_feasibility = false)
    @test CS.fix!(com, variables[xor_constraint.indices[2]], 4; check_feasibility = false)
    @test !CS.is_constraint_violated(com, xor_constraint, xor_constraint.fct, xor_constraint.set)

    ##################

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b := {(sum(x) > 3) ⊻ (sum(x) < 2)})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    @test CS.fix!(com, variables[constraint.indices[2]], 0; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[3]], 1; check_feasibility = false)
    @test CS.is_constraint_solved(com, constraint, constraint.fct, constraint.set)


    ##################

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b := {(sum(x) > 3) ⊻ (x in CS.AllDifferent())})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    @test CS.fix!(com, variables[constraint.indices[2]], 0; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[3]], 1; check_feasibility = false)
    @test CS.is_constraint_solved(com, constraint, constraint.fct, constraint.set)

    ##################

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b := {(sum(x) > 3) ⊻ (x in CS.TableSet([0 1; 1 0]))})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    @test CS.fix!(com, variables[constraint.indices[2]], 0; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[3]], 1; check_feasibility = false)
    @test CS.is_constraint_solved(com, constraint, constraint.fct, constraint.set)
end

@testset "Indicator fixed to 1 xor constraint violated or solved?" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b => {(sum(x) > 3) ⊻ (sum(x) < 2)})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    @test CS.fix!(com, variables[constraint.indices[2]], 1; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[3]], 1; check_feasibility = false)
    @test CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)

    #################

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b => {(sum(x) < 3) ⊻ (sum(x) >= 2)})
    optimize!(m)
    com = CS.get_inner_model(m)


    variables = com.search_space
    constraint = com.constraints[1]
    @test CS.fix!(com, variables[constraint.indices[2]], 1; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[3]], 1; check_feasibility = false)
    @test CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)

    #################

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b => {(sum(x) < 3) ⊻ (sum(x) > 1)})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    xor_constraint = com.constraints[1].inner_constraint
    @test CS.fix!(com, variables[xor_constraint.indices[1]], 0; check_feasibility = false)
    @test CS.fix!(com, variables[xor_constraint.indices[2]], 2; check_feasibility = false)
    CS.changed!(com, xor_constraint, xor_constraint.fct, xor_constraint.set)
    @test CS.is_constraint_violated(com, xor_constraint, xor_constraint.fct, xor_constraint.set)

    ##################

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b => {(sum(x) < 3) ⊻ (sum(x) > 1)})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    @test CS.fix!(com, variables[constraint.indices[2]], 0; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[3]], 0; check_feasibility = false)
    @test CS.is_constraint_solved(com, constraint, constraint.fct, constraint.set)
end

@testset "reified xor constraint prune_constraint!" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b := {(x[1] <= 2) ⊻ (x[2] <= 2)}) 
    optimize!(m)

    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]

    constr_indices = constraint.indices
    @test CS.fix!(com, variables[constraint.indices[3]], 0; check_feasibility = false)
    CS.changed!(com, constraint, constraint.fct, constraint.set)
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    @test sort(CS.values(m, x[1])) == [3,4,5]
end

@testset "reified xor constraint still feasible" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b := {(x[1] <= 2) ⊻ (x[2] <= 2)}) 
    optimize!(m)

    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    xor_constraint = com.constraints[1].inner_constraint

    constr_indices = xor_constraint.indices
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    # set x[2] to 0 
    @test CS.still_feasible(com, xor_constraint, xor_constraint.fct, xor_constraint.set, xor_constraint.indices[2], 0)
    @test CS.still_feasible(com, xor_constraint, xor_constraint.fct, xor_constraint.set, xor_constraint.indices[2], 3)
end

@testset "reified xor constraint prune_constraint" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 2 <= x[1:2] <= 5, Int)
    @constraint(m, b := {(x[1] < 2) ⊻ (x[2] < 2)}) 
    optimize!(m)

    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    xor_constraint = com.constraints[1].inner_constraint

    constr_indices = xor_constraint.indices
    @test !CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)

    ##########################

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 2 <= x[1:2] <= 5, Int)
    @constraint(m, b := {(x[1] > 1) ⊻ (x[2] > 1)}) 
    optimize!(m)

    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    xor_constraint = com.constraints[1].inner_constraint

    constr_indices = xor_constraint.indices
    @test !CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)

    ##########################

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 2 <= x[1:2] <= 5, Int)
    @constraint(m, b := {(x[1] > 2) ⊻ (x[2] < 2)}) 
    optimize!(m)

    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    xor_constraint = com.constraints[1].inner_constraint

    constr_indices = xor_constraint.indices
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
end
