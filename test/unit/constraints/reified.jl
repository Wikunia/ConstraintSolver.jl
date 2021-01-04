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
