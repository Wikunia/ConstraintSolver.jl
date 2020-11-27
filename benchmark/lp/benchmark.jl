function solve_lp()
    glpk_optimizer = optimizer_with_attributes(GLPK.Optimizer, "msg_lev" => GLPK.GLP_MSG_OFF)
    model = Model(optimizer_with_attributes(
        CS.Optimizer,
        "lp_optimizer" => glpk_optimizer,
        "logging" => [],
    ))

    # Variables
    @variable(model, inclusion[h = 1:3], Bin)
    @variable(model, 0 <= allocations[h = 1:3, a = 1:3] <= 1, Int)
    @variable(model, 0 <= days[h = 1:3, a = 1:3] <= 5, Int)

    # Constraints
    @constraint(
        model,
        must_include[h = 1:3],
        sum(allocations[h, a] for a = 1:3) <= inclusion[h]
    )
    # at least n
    @constraint(model, min_hospitals, sum(inclusion[h] for h = 1:3) >= 3)
    # every h must be allocated at most one a
    @constraint(model, must_visit[h = 1:3], sum(allocations[h, a] for a = 1:3) <= 1)
    # every allocated h must have fewer than 5 days of visits per week
    @constraint(
        model,
        max_visits[h = 1:3],
        sum(days[h, a] for a = 1:3) <= 5 * inclusion[h]
    )

    @objective(model, Max, sum(days[h, a] * 5 for h = 1:3, a = 1:3))
    optimize!(model)
end
