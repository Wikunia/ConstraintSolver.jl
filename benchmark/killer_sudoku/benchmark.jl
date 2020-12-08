function parseKillerJSON(json_sums)
    sums = []
    for s in json_sums
        indices = Tuple[]
        for ind in s["indices"]
            push!(indices, tuple(ind...))
        end

        push!(sums, (result = s["result"], indices = indices, color = s["color"]))
    end
    return sums
end

function solve_killer_sudoku(filename; special = false)
    json_file = joinpath(dir, "benchmark/killer_sudoku/data/$filename")
    sums = parseKillerJSON(JSON.parsefile(json_file))

    m = CS.Optimizer(logging = [], keep_logs = true, time_limit = 20)

    x = [[MOI.add_constrained_variable(m, MOI.Integer()) for i in 1:9] for j in 1:9]
    for r in 1:9, c in 1:9
        MOI.add_constraint(m, x[r][c][1], MOI.GreaterThan(1.0))
        MOI.add_constraint(m, x[r][c][1], MOI.LessThan(9.0))
    end

    for s in sums
        saf = MOI.ScalarAffineFunction{Float64}(
            [MOI.ScalarAffineTerm(1.0, x[ind[1]][ind[2]][1]) for ind in s.indices],
            0.0,
        )
        MOI.add_constraint(m, saf, MOI.EqualTo(convert(Float64, s.result)))
        if !special
            MOI.add_constraint(
                m,
                [x[ind[1]][ind[2]][1] for ind in s.indices],
                CS.AllDifferentSetInternal(length(s.indices)),
            )
        end
    end

    # sudoku constraints
    for r in 1:9
        MOI.add_constraint(
            m,
            MOI.VectorOfVariables([x[r][c][1] for c in 1:9]),
            CS.AllDifferentSetInternal(9),
        )
    end
    for c in 1:9
        MOI.add_constraint(
            m,
            MOI.VectorOfVariables([x[r][c][1] for r in 1:9]),
            CS.AllDifferentSetInternal(9),
        )
    end
    variables = [MOI.VariableIndex(0) for _ in 1:9]
    for br in 0:2
        for bc in 0:2
            variables_i = 1
            for i in (br * 3 + 1):((br + 1) * 3), j in (bc * 3 + 1):((bc + 1) * 3)
                variables[variables_i] = x[i][j][1]
                variables_i += 1
            end
            MOI.add_constraint(m, variables, CS.AllDifferentSetInternal(9))
        end
    end

    MOI.optimize!(m)
end
