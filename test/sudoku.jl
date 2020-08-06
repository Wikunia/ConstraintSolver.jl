@testset "Sudoku" begin

    @testset "Sudoku MOI/Integers/Int8" begin
        grid = Int8[
            0 2 1 0 7 9 0 8 5
            0 4 5 3 1 0 0 0 9
            0 7 0 0 4 0 0 1 0
            0 0 0 1 0 8 0 3 6
            0 6 0 0 0 0 2 0 8
            0 0 0 0 0 3 0 0 4
            6 0 8 0 0 0 0 0 0
            0 9 4 0 0 7 8 0 0
            2 0 0 5 0 0 0 4 0
        ]
        grid .-= 6
        grid[grid .== 3] .= 10
        grid[grid .== -2] .= 7

        m = CS.Optimizer()
        # don't use 1-9 here but some other integers to test offset and alldifferent without all numbers
        x = [[MOI.add_constrained_variable(m, CS.Integers([-5,-4,-3,7,-1,0,1,2,10])) for i = 1:9] for j = 1:9]

        # set variables
        for r = 1:9, c = 1:9
            if grid[r, c] != -6
                sat = [MOI.ScalarAffineTerm(Int8(1), x[r][c][1])]
                MOI.add_constraint(
                    m,
                    MOI.ScalarAffineFunction{Int8}(sat, 0),
                    MOI.EqualTo(grid[r, c]),
                )
            end
        end

        # sudoku constraints
        moi_add_sudoku_constr!(m, x)
        MOI.set(m, MOI.TimeLimitSec(), 10.0)

        MOI.optimize!(m)
        @test MOI.get(m, MOI.TerminationStatus()) == MOI.OPTIMAL
        solution = zeros(Int, 9, 9)
        for r = 1:9
            solution[r, :] = [MOI.get(m, MOI.VariablePrimal(), x[r][c][1]) for c = 1:9]
        end
        @test jump_fulfills_sudoku_constr(solution)
        @test m.options.time_limit == 10.0
    end

    @testset "Hard sudoku with table constraint" begin
        grid = zeros(Int, (9, 9))
        
        grid[1, :] = [3 8 0 6 0 0 0 0 0]
        grid[2, :] = [0 0 9 0 0 0 0 0 0]
        grid[3, :] = [0 2 0 0 3 0 5 1 0]
        grid[4, :] = [0 0 0 0 0 5 0 0 0]
        grid[5, :] = [0 3 0 0 1 0 0 6 0]
        grid[6, :] = [0 0 0 4 0 0 0 0 0]
        grid[7, :] = [0 1 7 0 5 0 0 8 0]
        grid[8, :] = [0 0 0 0 0 0 9 0 0]
        grid[9, :] = [0 0 0 0 0 7 0 3 2]

        offset = -2
        grid .+= offset

        m = Model(optimizer_with_attributes(CS.Optimizer))
        @variable(m, 1+offset <= x[1:9, 1:9] <= 9+offset, Int)
        # set variables
        nvars_set = 0
        for r = 1:9, c = 1:9
            if grid[r, c] != offset
                @constraint(m, x[r, c] == grid[r, c])
                nvars_set += 1
            end
        end

        table = Array{Int64}(undef,(factorial(9),9))
        i = 1
        for row in permutations(1:9)
            table[i,:] = row .+ offset      
            i += 1    
        end
        
        # sudoku constraints
        for rc = 1:9
            @constraint(m, x[rc, :] in CS.TableSet(table))
            @constraint(m, x[:, rc] in CS.TableSet(table))
        end
        
        for br = 0:2
            for bc = 0:2
                @constraint(
                    m,
                    vec(x[br*3+1:(br+1)*3, bc*3+1:(bc+1)*3]) in CS.TableSet(table)
                )
            end
        end

        optimize!(m)
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test jump_fulfills_sudoku_constr(JuMP.value.(x))
    end

    #=
    @testset "Hard sudoku" begin
        com = CS.ConstraintSolverModel()
        com.options.logging = Symbol[]
        com.options.branch_split = :Biggest

        grid = zeros(Int, (9, 9))
        grid[1, :] = [0 0 0 5 4 6 0 0 9]
        grid[2, :] = [0 2 0 0 0 0 0 0 7]
        grid[3, :] = [0 0 3 9 0 0 0 0 4]
        grid[4, :] = [9 0 5 0 0 0 0 7 0]
        grid[5, :] = [7 0 0 0 0 0 0 2 0]
        grid[6, :] = [0 0 0 0 9 3 0 0 0]
        grid[7, :] = [0 5 6 0 0 8 0 0 0]
        grid[8, :] = [0 1 0 0 3 9 0 0 0]
        grid[9, :] = [0 0 0 0 0 0 8 0 6]

        com_grid = create_sudoku_grid!(com, grid)
        add_sudoku_constr!(com, com_grid)

        @test CS.solve!(com, CS.SolverOptions()) == :Solved
        @test fulfills_sudoku_constr(com_grid)
    end
    =#

    @testset "Hard sudoku infeasible" begin
        grid = [
            0 0 0 5 4 6 0 0 9
            0 2 0 0 0 0 0 0 7
            0 0 3 9 0 0 0 0 4
            9 0 5 0 0 0 0 7 3
            7 0 0 0 0 0 0 2 0
            0 0 0 0 9 3 0 0 0
            0 5 6 0 0 8 0 0 0
            0 1 0 0 3 9 0 0 0
            0 0 0 0 0 0 8 0 6
        ]

        m = Model(CSJuMPTestOptimizer())
        @variable(m, 1 <= x[1:9, 1:9] <= 9, Int)
        # set variables
        for r = 1:9, c = 1:9
            if grid[r, c] != 0
                @constraint(m, x[r, c] == grid[r, c])
            end
        end
        # sudoku constraints
        jump_add_sudoku_constr!(m, x)

        optimize!(m)
        @test JuMP.termination_status(m) == MOI.INFEASIBLE
    end


    @testset "Hard fsudoku repo" begin
        grid = zeros(Int, (9, 9))
        grid[1, :] = [0 0 0 0 0 0 0 0 0]
        grid[2, :] = [0 1 0 6 2 0 0 9 0]
        grid[3, :] = [0 0 2 0 0 9 3 1 0]
        grid[4, :] = [0 0 4 0 0 6 0 8 0]
        grid[5, :] = [0 0 8 7 0 2 1 0 0]
        grid[6, :] = [0 3 0 8 0 0 5 0 0]
        grid[7, :] = [0 6 9 1 0 0 4 0 0]
        grid[8, :] = [0 8 0 0 7 3 0 5 0]
        grid[9, :] = [0 0 0 0 0 0 0 0 0]

        m = Model(CSJuMPTestOptimizer())
        @variable(m, 1 <= x[1:9, 1:9] <= 9, Int)
        # set variables
        nvars_set = 0
        for r = 1:9, c = 1:9
            if grid[r, c] != 0
                @constraint(m, x[r, c] == grid[r, c])
                nvars_set += 1
            end
        end

        @test nvars_set == length(filter(n -> n != 0, grid))

        # sudoku constraints
        jump_add_sudoku_constr!(m, x)

        optimize!(m)

        @test JuMP.termination_status(m) == MOI.OPTIMAL
        com = JuMP.backend(m).optimizer.model.inner
        @test_reference "refs/hard_fsudoku" com.constraints

        # check that it actually solves the given sudoku
        for r = 1:9, c = 1:9
            if grid[r, c] != 0
                @test JuMP.value(x[r, c]) == grid[r, c]
            end
        end

        @test jump_fulfills_sudoku_constr(JuMP.value.(x))
    end

    @testset "Infeasible sudoku at start" begin
        grid = zeros(Int, (9, 9))
        grid[1, :] = [0 0 0 0 0 0 0 0 0]
        grid[2, :] = [0 1 0 6 2 0 0 9 0]
        grid[3, :] = [0 0 2 0 0 9 3 1 0]
        grid[4, :] = [0 0 4 0 0 6 0 8 0]
        grid[5, :] = [0 0 8 7 0 2 1 0 0]
        grid[6, :] = [0 0 0 0 0 0 5 0 0]
        grid[7, :] = [0 6 9 1 0 0 2 1 0]
        grid[8, :] = [0 0 0 0 7 0 0 5 0]
        grid[9, :] = [0 0 1 0 0 0 0 0 0]

        m = Model(CSJuMPTestOptimizer())
        @variable(m, 1 <= x[1:9, 1:9] <= 9, Int)
        # set variables
        nvars_set = 0
        for r = 1:9, c = 1:9
            if grid[r, c] != 0
                @constraint(m, x[r, c] == grid[r, c])
                nvars_set += 1
            end
        end

        # sudoku constraints
        jump_add_sudoku_constr!(m, x)

        optimize!(m)

        @test JuMP.termination_status(m) == MOI.INFEASIBLE
    end

    #=
    @testset "Hard fsudoku repo 0-8 Int8" begin
        com = CS.ConstraintSolverModel(Int8)

        grid = zeros(Int, (9, 9))
        grid[1, :] = [0 0 0 0 0 0 0 0 0]
        grid[2, :] = [0 1 0 6 2 0 0 9 0]
        grid[3, :] = [0 0 2 0 0 9 3 1 0]
        grid[4, :] = [0 0 4 0 0 6 0 8 0]
        grid[5, :] = [0 0 8 7 0 2 1 0 0]
        grid[6, :] = [0 3 0 8 0 0 5 0 0]
        grid[7, :] = [0 6 9 1 0 0 4 0 0]
        grid[8, :] = [0 8 0 0 7 3 0 5 0]
        grid[9, :] = [0 0 0 0 0 0 0 0 0]
        grid .-= 1

        com_grid = Array{CS.Variable,2}(undef, 9, 9)
        for (ind, val) in enumerate(grid)
            if val == -1
                if ind == 81 # bottom right
                    # some other values are possible there
                    com_grid[ind] = CS.add_var!(com, 9, 11)
                elseif ind == 80 # one above (will be 9 in the end)
                    com_grid[ind] = CS.add_var!(com, 7, 11)
                else
                    com_grid[ind] = CS.add_var!(com, 0, 8)
                end
            else
                com_grid[ind] = CS.add_var!(com, 0, 8; fix = val)
            end
        end
        CS.add_constraint!(com, com_grid[1,1]+com_grid[2,2] != com_grid[4,4])

        add_sudoku_constr!(com, com_grid)
        options = Dict{Symbol,Any}()
        options[:keep_logs] = true
        options[:logging] = []

        options = CS.combine_options(options)

        @test CS.solve!(com, options) == :Solved
        @test is_solved(com)
    end
    =#

    #=
    @testset "Hard fsudoku repo 0-8 Int8 Objective" begin
        com = CS.ConstraintSolverModel(Int8)

        grid = zeros(Int, (9, 9))
        grid[1, :] = [0 0 0 0 0 0 0 0 0]
        grid[2, :] = [0 1 0 6 2 0 0 9 0]
        grid[3, :] = [0 0 2 0 0 9 3 1 0]
        grid[4, :] = [0 0 4 0 0 6 0 8 0]
        grid[5, :] = [0 0 8 7 0 2 1 0 0]
        grid[6, :] = [0 3 0 8 0 0 5 0 0]
        grid[7, :] = [0 6 9 1 0 0 4 0 0]
        grid[8, :] = [0 8 0 0 7 3 0 5 0]
        grid[9, :] = [0 0 0 0 0 0 0 0 0]
        grid .-= 1

        com_grid = Array{CS.Variable,2}(undef, 9, 9)
        for (ind, val) in enumerate(grid)
            if val == -1
                if ind == 81 # bottom right
                    # some other values are possible there
                    com_grid[ind] = CS.add_var!(com, 9, 11)
                elseif ind == 80 # one above (will be 9 in the end)
                    com_grid[ind] = CS.add_var!(com, 7, 11)
                else
                    com_grid[ind] = CS.add_var!(com, 0, 8)
                end
            else
                com_grid[ind] = CS.add_var!(com, 0, 8; fix = val)
            end
        end

        add_sudoku_constr!(com, com_grid)

        com.objective = CS.SingleVariableObjective(MOI.SingleVariable(MOI.VariableIndex(1)), 1, [1])
        com.sense = MOI.MIN_SENSE

        options = Dict{Symbol,Any}()
        options[:keep_logs] = true
        options[:logging] = []

        options = CS.combine_options(options)

        @test CS.solve!(com, options) == :Solved
        @test is_solved(com)
        @test typeof(com.best_bound) == Int8
        @test typeof(com.best_sol) == Int8
    end
    =#

    @testset "top95 some use backtracking" begin
        grids = sudokus_from_file("data/top95")
        c = 0
        for grid in grids
            m = Model(optimizer_with_attributes(
                CS.Optimizer,
                "solution_type" => Int8,
                "logging" => []
            ))

            @variable(m, 1 <= x[1:9, 1:9] <= 9, Int)
            # set variables
            for r = 1:9, c = 1:9
                if grid[r, c] != 0
                    @constraint(m, x[r, c] == grid[r, c])
                end
            end

            # sudoku constraints
            jump_add_sudoku_constr!(m, x)
            @objective(m, Min, x[1, 1])

            optimize!(m)
            com = JuMP.backend(m).optimizer.model.inner

            @test typeof(com.best_sol) == Int8
            @test JuMP.objective_value(m) == JuMP.value(x[1, 1]) == com.best_sol
            @test JuMP.termination_status(m) == MOI.OPTIMAL
            @test is_solved(com)
            c += 1
        end
        # check that actually all 95 problems were tested
        @test c == 95
    end


    @testset "Number 7 in top95.txt w/o backtracking" begin
        m = Model(optimizer_with_attributes(
            CS.Optimizer,
            "backtrack" => false,
            "logging" => []
        ))

        grid = Int[
            6 0 2 0 5 0 0 0 0
            0 0 0 0 0 3 0 4 0
            0 0 0 0 0 0 0 0 0
            4 3 0 0 0 8 0 0 0
            0 1 0 0 0 0 2 0 0
            0 0 0 0 0 0 7 0 0
            5 0 0 2 7 0 0 0 0
            0 0 0 0 0 0 0 8 1
            0 0 0 6 0 0 0 0 0
        ]
        grid = transpose(reshape(grid, (9, 9)))

        @variable(m, 1 <= x[1:9, 1:9] <= 9, Int)
        # set variables
        for r = 1:9, c = 1:9
            if grid[r, c] != 0
                @constraint(m, x[r, c] == grid[r, c])
            end
        end

        # sudoku constraints
        jump_add_sudoku_constr!(m, x)

        optimize!(m)

        com = JuMP.backend(m).optimizer.model.inner
        @test JuMP.termination_status(m) == MOI.OTHER_LIMIT

        @test !com.info.backtracked
        @test com.info.backtrack_fixes == 0
        @test com.info.in_backtrack_calls == 0
        @show com.info
    end

    @testset "Two solutions" begin
        m = Model(optimizer_with_attributes(
            CS.Optimizer,
            "all_solutions" => true,
            "logging" => [],
        ))

        grid = Int[
            9 0 6 0 7 0 4 0 3
            0 0 0 4 0 0 2 0 0
            0 7 0 0 2 3 0 1 0
            5 0 0 0 0 0 1 0 0
            0 4 0 2 0 8 0 6 0
            0 0 3 0 0 0 0 0 5
            0 3 0 7 0 0 0 5 0
            0 0 7 0 0 5 0 0 0
            4 0 5 0 1 0 7 0 8
        ]

        @variable(m, 1 <= x[1:9, 1:9] <= 9, Int)
        # set variables
        for r = 1:9, c = 1:9
            if grid[r, c] != 0
                @constraint(m, x[r, c] == grid[r, c])
            end
        end

        # sudoku constraints
        jump_add_sudoku_constr!(m, x)

        optimize!(m)

        com = JuMP.backend(m).optimizer.model.inner

        @test JuMP.result_count(m) == 2
        @test JuMP.value.(x) != JuMP.value.(x, result = 2)
        if JuMP.value.(x[6, 5:6]) == [9, 4]
            @test JuMP.value.(x[7, 5:6]) == [4, 9]
        else
            @test JuMP.value.(x[6, 5:6]) == [4, 9]
            @test JuMP.value.(x[7, 5:6]) == [9, 4]
        end
    end

    @testset "Two solutions but optimize on one value" begin
        # all solutions should give all solutions even if they are not optimal
        m = Model(optimizer_with_attributes(
            CS.Optimizer,
            "all_solutions" => true,
            "logging" => [],
        ))

        grid = Int[
            9 0 6 0 7 0 4 0 3
            0 0 0 4 0 0 2 0 0
            0 7 0 0 2 3 0 1 0
            5 0 0 0 0 0 1 0 0
            0 4 0 2 0 8 0 6 0
            0 0 3 0 0 0 0 0 5
            0 3 0 7 0 0 0 5 0
            0 0 7 0 0 5 0 0 0
            4 0 5 0 1 0 7 0 8
        ]

        @variable(m, 1 <= x[1:9, 1:9] <= 9, Int)
        # set variables
        for r = 1:9, c = 1:9
            if grid[r, c] != 0
                @constraint(m, x[r, c] == grid[r, c])
            end
        end

        # sudoku constraints
        jump_add_sudoku_constr!(m, x)
        @objective(m, Max, x[6, 5])

        optimize!(m)

        com = JuMP.backend(m).optimizer.model.inner

        @test JuMP.result_count(m) == 2
        @test JuMP.value.(x) != JuMP.value.(x, result = 2)
        # the better one should be solution 1 of course
        @test JuMP.objective_value(m) == 9
        @test JuMP.value.(x[6, 5:6]) == [9, 4]
        @test JuMP.value.(x[7, 5:6]) == [4, 9]
        # second worse solution
        @test JuMP.objective_value(m, result = 2) == 4
        @test JuMP.value.(x[6, 5:6], result = 2) == [4, 9]
        @test JuMP.value.(x[7, 5:6], result = 2) == [9, 4]
    end

    @testset "Two solutions but only one optimal" begin
        # all solutions should give all solutions even if they are not optimal
        m = Model(optimizer_with_attributes(
            CS.Optimizer,
            "all_optimal_solutions" => true,
            "logging" => [],
        ))

        grid = Int[
            9 0 6 0 7 0 4 0 3
            0 0 0 4 0 0 2 0 0
            0 7 0 0 2 3 0 1 0
            5 0 0 0 0 0 1 0 0
            0 4 0 2 0 8 0 6 0
            0 0 3 0 0 0 0 0 5
            0 3 0 7 0 0 0 5 0
            0 0 7 0 0 5 0 0 0
            4 0 5 0 1 0 7 0 8
        ]

        @variable(m, 1 <= x[1:9, 1:9] <= 9, Int)
        # set variables
        for r = 1:9, c = 1:9
            if grid[r, c] != 0
                @constraint(m, x[r, c] == grid[r, c])
            end
        end

        # sudoku constraints
        jump_add_sudoku_constr!(m, x)
        @objective(m, Max, x[6, 5])

        optimize!(m)

        com = JuMP.backend(m).optimizer.model.inner

        @test JuMP.result_count(m) == 1
        # the better one should be solution 1 of course
        @test JuMP.objective_value(m) == 9
        @test JuMP.value.(x[6, 5:6]) == [9, 4]
        @test JuMP.value.(x[7, 5:6]) == [4, 9]
    end

    @testset "Two solutions but both optimal" begin
        # all solutions should give all solutions even if they are not optimal
        m = Model(optimizer_with_attributes(
            CS.Optimizer,
            "all_optimal_solutions" => true,
            "logging" => [],
        ))

        grid = Int[
            9 0 6 0 7 0 4 0 3
            0 0 0 4 0 0 2 0 0
            0 7 0 0 2 3 0 1 0
            5 0 0 0 0 0 1 0 0
            0 4 0 2 0 8 0 6 0
            0 0 3 0 0 0 0 0 5
            0 3 0 7 0 0 0 5 0
            0 0 7 0 0 5 0 0 0
            4 0 5 0 1 0 7 0 8
        ]

        @variable(m, x[1:9, 1:9], CS.Integers(1:9))
        # set variables
        for r = 1:9, c = 1:9
            if grid[r, c] != 0
                @constraint(m, x[r, c] == grid[r, c])
            end
        end

        # sudoku constraints
        jump_add_sudoku_constr!(m, x)
        @objective(m, Max, x[1, 1])

        optimize!(m)

        com = JuMP.backend(m).optimizer.model.inner
        @test com.info.n_constraint_types.alldifferent == 27
        @test length(com.constraints) == 27
        @test length(com.search_space) == 81

        # the better one should be solution 1 of course
        @test JuMP.objective_value(m) == 9
        @test JuMP.result_count(m) == 2
        @test JuMP.value.(x) != JuMP.value.(x, result = 2)
        if JuMP.value.(x[6, 5:6]) == [9, 4]
            @test JuMP.value.(x[7, 5:6]) == [4, 9]
        else
            @test JuMP.value.(x[6, 5:6]) == [4, 9]
            @test JuMP.value.(x[7, 5:6]) == [9, 4]
        end
    end

    @testset "All optimal solutions" begin
        n = 9
        g = 3

        grid = zeros(Int, (n, n))

        m = Model(optimizer_with_attributes(
            CS.Optimizer,
            "all_optimal_solutions" => true,
            "time_limit" => 1.0,
            "keep_logs" => true,
            "logging" => []
        ))

        @variable(m, 1 <= x[1:n, 1:n] <= n, Int)
        # set variables
        for r = 1:n, c = 1:n
            if grid[r, c] != 0
                @constraint(m, x[r, c] == grid[r, c])
            end
        end
        for rc = 1:n
            @constraint(m, x[rc, :] in CS.AllDifferentSet())
            @constraint(m, x[:, rc] in CS.AllDifferentSet())
        end
        for br = 0:g-1
            for bc = 0:g-1
                @constraint(
                    m,
                    vec(x[br*g+1:(br+1)*g, bc*g+1:(bc+1)*g]) in CS.AllDifferentSet()
                )
            end
        end

        optimize!(m)
        @test MOI.get(m, MOI.SolveTime()) >= 1.0
        # at least more than 1 but in that time frame it should find a lot ;)
        @test MOI.get(m, MOI.ResultCount()) >= 10 
        @test JuMP.termination_status(m) == MOI.TIME_LIMIT
        com = JuMP.backend(m).optimizer.model.inner
        general_tree_test(com)
    end

    @testset "All solutions" begin
        n = 9
        g = 3

        grid = zeros(Int, (n, n))

        m = Model(optimizer_with_attributes(
            CS.Optimizer,
            "all_solutions" => true,
            "time_limit" => 1.0,
            "logging" => []
        ))

        @variable(m, 1 <= x[1:n, 1:n] <= n, Int)
        # set variables
        for r = 1:n, c = 1:n
            if grid[r, c] != 0
                @constraint(m, x[r, c] == grid[r, c])
            end
        end
        for rc = 1:n
            @constraint(m, x[rc, :] in CS.AllDifferentSet())
            @constraint(m, x[:, rc] in CS.AllDifferentSet())
        end
        for br = 0:g-1
            for bc = 0:g-1
                @constraint(
                    m,
                    vec(x[br*g+1:(br+1)*g, bc*g+1:(bc+1)*g]) in CS.AllDifferentSet()
                )
            end
        end

        optimize!(m)
        @test MOI.get(m, MOI.SolveTime()) >= 1.0
        # at least more than 1 but in that time frame it should find a lot ;)
        @test MOI.get(m, MOI.ResultCount()) >= 10 
        @test JuMP.termination_status(m) == MOI.TIME_LIMIT
    end
end
