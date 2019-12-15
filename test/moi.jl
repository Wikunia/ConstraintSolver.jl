using ConstraintSolver, JuMP
# using Plots

CS = ConstraintSolver
include("sudoku_fcts.jl")
include("../visualizations/plot_search_space.jl")

function moi_tests()
    com = CS.init();
 
    optimizer = CS.Optimizer()
    @assert MOI.supports_constraint(optimizer, MOI.VectorOfVariables, CS.AllDifferentSet)


    x1 = MOI.add_constrained_variable(optimizer, MOI.Interval(1.0, 9.0))
    x2 = MOI.add_constrained_variable(optimizer, MOI.Interval(1.0, 9.0))
    x3 = MOI.add_constrained_variable(optimizer, MOI.Interval(1.0, 9.0))

    # [1] to get the index
    MOI.add_constraint(optimizer, x1[1], MOI.Integer())
    MOI.add_constraint(optimizer, x2[1], MOI.Integer())
    MOI.add_constraint(optimizer, x3[1], MOI.Integer())

    affine_terms = Vector{MOI.ScalarAffineTerm{Float64}}()
    push!(affine_terms,  MOI.ScalarAffineTerm{Float64}(1,MOI.VariableIndex(1)))
    push!(affine_terms,  MOI.ScalarAffineTerm{Float64}(1,MOI.VariableIndex(2)))
    MOI.add_constraint(optimizer, MOI.ScalarAffineFunction(affine_terms,0.0), MOI.EqualTo(3.0))
    MOI.add_constraint(optimizer, MOI.VectorOfVariables([x1[1], x2[1], x3[1]]), CS.AllDifferentSet(3))

    MOI.optimize!(optimizer)
    # <- works

    m = Model()
    set_optimizer(m, ConstraintSolver.Optimizer)
    @variable(m, 1 <= x[1:3] <= 9, Int)
    @constraint(m, x[1]+x[2] == 3)
    @constraint(m, x in CS.AllDifferentSet(3))
    optimize!(m)
end

function main(;benchmark=false, backtrack=true, visualize=false)
    com = CS.init()

    grid = zeros(Int64,(9,9))
    grid[1,:] = [6,0,2,0,5,0,0,0,0]
    grid[2,:] = [0,0,0,0,0,3,0,4,0]
    grid[3,:] = [0,0,0,0,0,0,0,0,0]
    grid[4,:] = [4,3,0,0,0,8,0,0,0]
    grid[5,:] = [0,1,0,0,0,0,2,0,0]
    grid[6,:] = [0,0,0,0,0,0,7,0,0]
    grid[7,:] = [5,0,0,2,7,0,0,0,0]
    grid[8,:] = [0,0,0,0,0,0,0,8,1]
    grid[9,:] = [0,0,0,6,0,0,0,0,0]
  
    m = Model()
    set_optimizer(model, ConstraintSolver.Optimizer)
    @variable(m, 1 <= x[1:9] <= 9, Int)
    println("Added variables")

    #=
    for (ind,val) in enumerate(grid)
        if val != 0
            @constraint(m, x[ind] == val)
        end
    end
    =#
    @constraint(m, x[1]+x[2] == 1)
    
    @constraint(m, [x[1]] in CS.AllDifferentSet(1))

    # plot_search_space(grid, com_grid, "search_space_start")

    # add_sudoku_constr!(com, com_grid)

    optimize!(m)
    
    #=
    if !benchmark
        println("Status: ", status)
        print_search_space(com_grid)
        # plot_search_space(grid, com_grid, "search_space_without_bt")
        @show com.info
        
        println("visualize: ", visualize)
        #=if visualize
            anim = @animate for i=1:length(com.snapshots)
                plot_search_space(grid, reshape(com.snapshots[i].search_space, (9,9)), "")
            end
            gif(anim, "visualizations/images/gifs/current.gif", fps=2)
        end
        =#
        @assert fulfills_sudoku_constr(com_grid)
    end 
    =#
    # plot_search_space(com, grid, "final_search_space")
end

