@testset "reified fixed to 1 or constraint violated or solved?" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, x in CS.AllDifferent() || sum(x) > 2 || x[1] > 1)
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
    @constraint(m, b := {x in CS.AllDifferent() || sum(x) <= 2 || 2x[1]+2x[2] > 8})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    @test CS.fix!(com, variables[constraint.indices[2]], 2; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[3]], 2; check_feasibility = false)
    @test CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)

    #################

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b := {x in CS.AllDifferent() || sum(x) > 2})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    or_constraint = com.constraints[1].inner_constraint
    @test CS.fix!(com, variables[or_constraint.indices[1]], 1; check_feasibility = false)
    @test CS.fix!(com, variables[or_constraint.indices[2]], 1; check_feasibility = false)
    @test CS.is_constraint_violated(com, or_constraint, or_constraint.fct, or_constraint.set)

    ############################### 

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b := {sum(x) > 2 || x in CS.AllDifferent()})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    or_constraint = com.constraints[1].inner_constraint
    @test CS.fix!(com, variables[or_constraint.indices[1]], 1; check_feasibility = false)
    @test CS.fix!(com, variables[or_constraint.indices[2]], 1; check_feasibility = false)
    @test CS.is_constraint_violated(com, or_constraint, or_constraint.fct, or_constraint.set)

    ##################

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b := {x in CS.AllDifferent() || sum(x) <= 2})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    @test CS.fix!(com, variables[constraint.indices[2]], 1; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[3]], 1; check_feasibility = false)
    @test CS.is_constraint_solved(com, constraint, constraint.fct, constraint.set)
end

@testset "Indicator fixed to 1 or constraint violated or solved?" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b => {x in CS.AllDifferent() || sum(x) > 2 || x[1] > 1 })
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
    @constraint(m, b => {x in CS.AllDifferent() || sum(x) <= 2 || 2x[1]+2x[2] > 8})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    @test CS.fix!(com, variables[constraint.indices[2]], 2; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[3]], 2; check_feasibility = false)
    @test CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)

    #################

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b => {x in CS.AllDifferent() || sum(x) > 2})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    or_constraint = com.constraints[1].inner_constraint
    @test CS.fix!(com, variables[or_constraint.indices[1]], 1; check_feasibility = false)
    @test CS.fix!(com, variables[or_constraint.indices[2]], 1; check_feasibility = false)
    @test CS.is_constraint_violated(com, or_constraint, or_constraint.fct, or_constraint.set)

    ############################### 

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b => {sum(x) > 2 || x in CS.AllDifferent()})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    or_constraint = com.constraints[1].inner_constraint
    @test CS.fix!(com, variables[or_constraint.indices[1]], 1; check_feasibility = false)
    @test CS.fix!(com, variables[or_constraint.indices[2]], 1; check_feasibility = false)
    @test CS.is_constraint_violated(com, or_constraint, or_constraint.fct, or_constraint.set)

    ##################

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b => {x in CS.AllDifferent() || sum(x) <= 2})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    @test CS.fix!(com, variables[constraint.indices[2]], 1; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[3]], 1; check_feasibility = false)
    @test CS.is_constraint_solved(com, constraint, constraint.fct, constraint.set)
end

@testset "reified or constraint prune_constraint!" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b := {2x[1]+x[2] >= 3 || x[1] > 1}) 
    optimize!(m)

    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]

    constr_indices = constraint.indices
    @test CS.fix!(com, variables[constraint.indices[2]], 0; check_feasibility = false)
    CS.changed!(com, constraint, constraint.fct, constraint.set)
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    for v in 0:2
        @test !CS.has(variables[constraint.indices[3]], v)
    end

    # prune rhs
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b := {x[1] > 1 || 2x[1]+x[2] >= 3}) 
    optimize!(m)

    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]

    constr_indices = constraint.indices
    @test CS.fix!(com, variables[constraint.indices[2]], 0; check_feasibility = false)
    CS.changed!(com, constraint, constraint.fct, constraint.set)
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    for v in 0:2
        @test !CS.has(variables[constraint.indices[4]], v)
    end
end

@testset "reified or constraint still_feasible" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @variable(m, 0 <= y <= 5, Int)
    @constraint(m, b := { x in CS.AllDifferent() || y < 1}) 
    optimize!(m)

    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]

    or_constraint =constraint.inner_constraint

    constr_indices = or_constraint.indices
    @test CS.fix!(com, variables[constraint.indices[2]], 0; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[3]], 0; check_feasibility = false)
    @test !CS.still_feasible(com, or_constraint, or_constraint.fct, or_constraint.set, constr_indices[3], 1)

    # swap lhs and rhs
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @variable(m, 0 <= y <= 5, Int)
    @constraint(m, b := { y < 1 || x in CS.AllDifferent()}) 
    optimize!(m)

    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]

    or_constraint =constraint.inner_constraint

    constr_indices = or_constraint.indices
    @test CS.fix!(com, variables[constr_indices[2]], 0; check_feasibility = false)
    @test CS.fix!(com, variables[constr_indices[3]], 0; check_feasibility = false)
    @test !CS.still_feasible(com, or_constraint, or_constraint.fct, or_constraint.set, constr_indices[1], 1)
end