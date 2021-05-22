@testset "complement constraint violated or solved?" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, !((sum(x) <= 2)))
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    @test CS.fix!(com, variables[constraint.indices[1]], 1; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[2]], 2; check_feasibility = false)
    @test CS.is_constraint_solved(com, constraint, constraint.fct, constraint.set)

    #################

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, !(sum(x) > 4))
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    @test CS.fix!(com, variables[constraint.indices[1]], 1; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[2]], 1; check_feasibility = false)
    @test CS.is_constraint_solved(com, constraint, constraint.fct, constraint.set)

    #################

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b := {!(sum(x) > 3)})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    xor_constraint = com.constraints[1].inner_constraint
    @test CS.fix!(com, variables[xor_constraint.indices[1]], 0; check_feasibility = false)
    @test CS.fix!(com, variables[xor_constraint.indices[2]], 2; check_feasibility = false)
    @test CS.is_constraint_solved(com, xor_constraint, xor_constraint.fct, xor_constraint.set)

    ############################### 

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b := {!((sum(x) > 3))})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    xor_constraint = com.constraints[1].inner_constraint
    @test CS.fix!(com, variables[xor_constraint.indices[1]], 0; check_feasibility = false)
    @test CS.fix!(com, variables[xor_constraint.indices[2]], 4; check_feasibility = false)
    @test !CS.is_constraint_solved(com, xor_constraint, xor_constraint.fct, xor_constraint.set)

    ##################

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b := {!((sum(x) >= 3))})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    @test CS.fix!(com, variables[constraint.indices[2]], 3; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[3]], 1; check_feasibility = false)
    @test CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)


    ##################

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x[1:2] <= 5, Int)
    @constraint(m, b := {!(sum(x) >= 5)})
    optimize!(m)
    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    @test CS.fix!(com, variables[constraint.indices[2]], 3; check_feasibility = false)
    @test CS.fix!(com, variables[constraint.indices[3]], 2; check_feasibility = false)
    @test CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)
end

@testset "complement constraint still feasible" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, b >= 1, Bin)
    @variable(m, 0 <= x <= 5, Int)
    @constraint(m, b := {!(x >= 2)}) 
    optimize!(m)

    com = CS.get_inner_model(m)

    variables = com.search_space
    constraint = com.constraints[1]
    complement_constraint = com.constraints[1].inner_constraint

    constr_indices = complement_constraint.indices
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    @test CS.still_feasible(com, complement_constraint, complement_constraint.fct, complement_constraint.set, complement_constraint.indices[1], 1)
    @test !CS.still_feasible(com, complement_constraint, complement_constraint.fct, complement_constraint.set, complement_constraint.indices[1], 2)
end