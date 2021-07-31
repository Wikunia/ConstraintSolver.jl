@testset "reified fixed to 1 And constraint violated or solved?" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, x in CS.AllDifferent() && sum(x) <= 2 && sum(x) > 1)
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    @test CS.fix!(com, variables[constraint.indices[1]], 1; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[2]], 1; check_feasibility = false)
    @test CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)

    #################

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, x in CS.AllDifferent() && sum(x) <= 2 && sum(x) >= 2)
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    @test CS.fix!(com, variables[constraint.indices[1]], 1; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[2]], 2; check_feasibility = false)
    @test CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)

    #################

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b := {x in CS.AllDifferent() && sum(x) > 2})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    and_constraint = com.constraints[1].inner_constraint
    @test CS.fix!(com, variables[and_constraint.indices[1]], 0; check_feasibility = false)
    @test CS.fix!(com, variables[and_constraint.indices[2]], 2; check_feasibility = false)
    @test CS.is_constraint_violated(com, and_constraint, and_constraint.fct, and_constraint.set)

    ############################### 

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b := {sum(x) > 2 && x in CS.AllDifferent()})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    and_constraint = com.constraints[1].inner_constraint
    @test CS.fix!(com, variables[and_constraint.indices[1]], 0; check_feasibility = false)
    @test CS.fix!(com, variables[and_constraint.indices[2]], 2; check_feasibility = false)
    @test CS.is_constraint_violated(com, and_constraint, and_constraint.fct, and_constraint.set)

    ##################

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b := {x in CS.AllDifferent() && sum(x) <= 2})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    @test CS.fix!(com, variables[constraint.indices[2]], 0; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[3]], 1; check_feasibility = false)
    @test CS.is_constraint_solved(com, constraint, constraint.fct, constraint.set)
end

@testset "Indicator fixed to 1 And constraint violated or solved?" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b => {x in CS.AllDifferent() && sum(x) <= 2 && sum(x) > 0 })
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
    @constraint(m, b => {x in CS.AllDifferent() && sum(x) <= 2 && sum(x) >= 0})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    @test CS.fix!(com, variables[constraint.indices[2]], 1; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[3]], 2; check_feasibility = false)
    @test CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)

     #################

     m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
     @variable(m, b >= 1, Bin)
     @variable(m, 0 <= x[1:2] <= 5, Int)
     @constraint(m, b => {sum(x) > 2 && x in CS.AllDifferent()})
     optimize!(m)
     com = CS.get_inner_model(m)
 
     variables = com.search_space
     constraint = com.constraints[1]
     and_constraint = com.constraints[1].inner_constraint
     @test CS.fix!(com, variables[and_constraint.indices[1]], 0; check_feasibility = false)
     @test CS.fix!(com, variables[and_constraint.indices[2]], 2; check_feasibility = false)
     @test CS.is_constraint_violated(com, and_constraint, and_constraint.fct, and_constraint.set)

     m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
     @variable(m, b >= 1, Bin)
     @variable(m, 0 <= x[1:2] <= 5, Int)
     @constraint(m, b => {x in CS.AllDifferent() && sum(x) > 2})
     optimize!(m)
     com = CS.get_inner_model(m)
 
     variables = com.search_space
     constraint = com.constraints[1]
     and_constraint = com.constraints[1].inner_constraint
     @test CS.fix!(com, variables[and_constraint.indices[1]], 0; check_feasibility = false)
     @test CS.fix!(com, variables[and_constraint.indices[2]], 2; check_feasibility = false)
     @test CS.is_constraint_violated(com, and_constraint, and_constraint.fct, and_constraint.set)

    ##################

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b => {x in CS.AllDifferent() && sum(x) <= 2})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    @test CS.fix!(com, variables[constraint.indices[2]], 0; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[3]], 1; check_feasibility = false)
    @test CS.is_constraint_solved(com, constraint, constraint.fct, constraint.set)
end

@testset "reified And constraint prune_constraint!" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b := {2x[1]+x[2] >= 3 && x[1] <= 1}) 
    optimize!(m)

    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]

    constr_indices = constraint.indices
    @test CS.fix!(com, variables[constraint.indices[3]], 0; check_feasibility = false)
    CS.changed!(com, constraint, constraint.fct, constraint.set)
    @test !CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
end

@testset "reified And constraint still feasible" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b := {2x[1]+x[2] >= 3 && x[1] <= 1})
    optimize!(m)

    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    and_constraint = com.constraints[1].inner_constraint

    constr_indices = and_constraint.indices
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    # set x[2] to 0 => x[1] would need to be 2 which isn't possible
    @test !CS.still_feasible(com, and_constraint, and_constraint.fct, and_constraint.set, and_constraint.indices[2], 0)
end