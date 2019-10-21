@testset "Small special tests" begin
@testset "Sum" begin
    com = CS.init()

    com_grid = Array{CS.Variable, 1}(undef, 7)
    com_grid[1] = add_var!(com, 1, 9)
    com_grid[2] = add_var!(com, 1, 9; fix=5)
    com_grid[3] = add_var!(com, 1, 9)
    com_grid[4] = add_var!(com, 1, 9)
    com_grid[5] = add_var!(com, 1, 9)

    com_grid[6] = add_var!(com, 1, 2)
    com_grid[7] = add_var!(com, 3, 5)
    

    CS.rm!(com, com_grid[4], 5)
    CS.remove_above!(com, com_grid[5], 2)

    add_constraint!(com, sum([com_grid[CartesianIndex(ind)] for ind in [1,2]]) == 11)
    add_constraint!(com, sum([com_grid[CartesianIndex(ind)] for ind in [3,4]]) == 11)
    add_constraint!(com, sum([com_grid[CartesianIndex(ind)] for ind in [2,5]]) ==  6)
    # testing coefficients from left and right
    add_constraint!(com, com_grid[6]*1+2*com_grid[7] ==  7)
        
    status = solve!(com; backtrack=false, keep_logs=true)
    # remove without pruning
    CS.remove_above!(com, com_grid[3], 5)

    # should also work for a fixed variable
    @test CS.compress_var_string(com_grid[1]) == "6"

    str_output = CS.get_str_repr(com_grid)
    @test str_output[1] == "6, 5, 2:5, [2, 3, 4, 6, 7, 8, 9], 1, 1, 3"

    com_grid_2D = [com_grid[1] com_grid[2]; com_grid[3] com_grid[4]]
    str_output = CS.get_str_repr(com_grid_2D)
    @test str_output[1] == "          6                    2:5          "
    @test str_output[2] == "          5           [2, 3, 4, 6, 7, 8, 9] "

    println(com_grid)

    @test status != :Infeasible
    @test CS.isfixed(com_grid[1])
    @test value(com_grid[1]) == 6
    @test CS.isfixed(com_grid[5])
    @test value(com_grid[5]) == 1
    @test !CS.has(com_grid[3], 6)

    @test CS.isfixed(com_grid[6])
    @test value(com_grid[6]) == 1

    @test CS.isfixed(com_grid[7])
    @test value(com_grid[7]) == 3
end

@testset "Reordering sum constraint" begin
    com = CS.init()

    x = add_var!(com, 0, 9)
    y = add_var!(com, 0, 9)
    z = add_var!(com, 0, 9)

    c1 = 2x+3x == 5
    @test length(c1.indices) == 1
    @test c1.indices[1] == 1
    @test c1.coeffs[1] == 5
    @test c1.rhs == 5
    
    add_constraint!(com, 2x+3x == 5)
    add_constraint!(com, 2x-3y+6+x == z)
    add_constraint!(com, x+2 == z)
    add_constraint!(com, z-2 == x)
    add_constraint!(com, 2x+x == z+3y-6)

    status = solve!(com)
    @test status == :Solved 
    @test CS.isfixed(x) && value(x) == 1
    @test 2*value(x)-3*value(y)+6+value(x) == value(z)
    @test value(x)+2 == value(z)
end

@testset "Infeasible coeff sum" begin
    com = CS.init()

    com_grid = Array{CS.Variable, 1}(undef, 3)
    com_grid[1] = add_var!(com, 1, 9)
    com_grid[2] = add_var!(com, 1, 9)
    com_grid[3] = add_var!(com, 1, 9)
    
    CS.rm!(com, com_grid[2], 2)
    CS.rm!(com, com_grid[2], 3)
    CS.rm!(com, com_grid[2], 4)
    CS.rm!(com, com_grid[2], 6)
    CS.rm!(com, com_grid[2], 8)
        
    add_constraint!(com, com_grid[2]*2+5*com_grid[1]+0*com_grid[3] == 21)
    
    status = solve!(com; backtrack=true)
    @test status == :Infeasible
end

@testset "Negative coeff sum" begin
    com = CS.init()

    com_grid = Array{CS.Variable, 1}(undef, 3)
    com_grid[1] = add_var!(com, 1, 9)
    com_grid[2] = add_var!(com, 1, 9)
    com_grid[3] = add_var!(com, 1, 9)
    
    CS.remove_above!(com, com_grid[3], 3)

    add_constraint!(com, sum([7,5,-10].*com_grid) == -13)
    
    status = solve!(com; backtrack=true)
    @test status == :Solved
    @test CS.isfixed(com_grid[1]) && value(com_grid[1]) == 1
    @test CS.isfixed(com_grid[2]) && value(com_grid[2]) == 2
    @test CS.isfixed(com_grid[3]) && value(com_grid[3]) == 3

    com = CS.init()

    com_grid = Array{CS.Variable, 1}(undef, 3)
    com_grid[1] = add_var!(com, 1, 5)
    com_grid[2] = add_var!(com, 1, 2)
    com_grid[3] = add_var!(com, 1, 9)
    
    add_constraint!(com, sum([7,5,-10].*com_grid) == -13)
    
    status = solve!(com; backtrack=true)
    @test status == :Solved
    @test CS.isfixed(com_grid[1]) && value(com_grid[1]) == 1
    @test CS.isfixed(com_grid[2]) && value(com_grid[2]) == 2
    @test CS.isfixed(com_grid[3]) && value(com_grid[3]) == 3

    com = CS.init()

    v1 = add_var!(com, 1, 5)
    v2 = add_var!(com, 5, 10)
    
    add_constraint!(com, v1-v2 == 0)
    
    status = solve!(com; backtrack=false)
    @test status == :Solved
    @test CS.isfixed(v1) && value(v1) == 5
    @test CS.isfixed(v2) && value(v2) == 5
end

@testset "Equal constraint" begin
    # nothing to do
    com = CS.init()

    v1 = add_var!(com, 1, 2; fix=2)
    v2 = add_var!(com, 1, 2; fix=2)

    add_constraint!(com, v1 == v2)

    status = solve!(com)
    @test status == :Solved
    @test !com.info.backtracked
    @test CS.isfixed(v1) && value(v1) == 2
    @test CS.isfixed(v2) && value(v2) == 2

    # normal
    com = CS.init()

    v1 = add_var!(com, 1, 2)
    v2 = add_var!(com, 1, 2; fix=2)

    add_constraint!(com, v1 == v2)

    status = solve!(com)
    @test status == :Solved
    @test !com.info.backtracked
    @test CS.isfixed(v1) && value(v1) == 2
    @test CS.isfixed(v2) && value(v2) == 2

    # set but infeasible
    com = CS.init()

    v1 = add_var!(com, 1, 2)
    v2 = add_var!(com, 1, 2; fix=2)

    add_constraint!(com, v1 == v2)
    add_constraint!(com, CS.all_different([v1, v2]))

    status = solve!(com)
    @test status == :Infeasible
    @test !com.info.backtracked

    # set but infeasible reversed
    com = CS.init()

    v1 = add_var!(com, 1, 2)
    v2 = add_var!(com, 1, 2; fix=2)

    add_constraint!(com, v2 == v1)
    add_constraint!(com, CS.all_different([v1, v2]))

    status = solve!(com)
    @test status == :Infeasible
    @test !com.info.backtracked

    # reversed
    com = CS.init()

    v1 = add_var!(com, 1, 2)
    v2 = add_var!(com, 1, 2; fix=2)

    add_constraint!(com, v2 == v1)

    status = solve!(com)
    @test status == :Solved
    @test !com.info.backtracked
    @test CS.isfixed(v1) && value(v1) == 2
    @test CS.isfixed(v2) && value(v2) == 2

    # test with more
    com = CS.init()

    v1 = add_var!(com, 1, 2)
    v2 = add_var!(com, 1, 2; fix=2)
    v3 = add_var!(com, 1, 2)
    v4 = add_var!(com, 1, 2)

    add_constraint!(com, v1 == v2)
    add_constraint!(com, v1 == v4)
    add_constraint!(com, v1 == v3)

    status = solve!(com)
    @test status == :Solved
    @test !com.info.backtracked
    @test CS.isfixed(v1) && value(v1) == 2
    @test CS.isfixed(v2) && value(v2) == 2
    @test CS.isfixed(v3) && value(v3) == 2
    @test CS.isfixed(v4) && value(v4) == 2
end

@testset "NotSolved or infeasible" begin
    # NotSolved without backtracking
    com = CS.init()

    v1 = add_var!(com, 1, 2)
    v2 = add_var!(com, 1, 2)

    add_constraint!(com, v2 == v1)

    status = solve!(com; backtrack=false)
    @test status == :NotSolved
    @test !com.info.backtracked

    # Infeasible without backtracking
    com = CS.init()

    v1 = add_var!(com, 1, 2; fix=1)
    v2 = add_var!(com, 1, 2; fix=2)

    add_constraint!(com, v2 == v1)

    status = solve!(com)
    @test status == :Infeasible
    @test !com.info.backtracked

    # Infeasible without backtracking reverse
    com = CS.init()

    v1 = add_var!(com, 1, 2; fix=1)
    v2 = add_var!(com, 1, 2; fix=2)

    add_constraint!(com, v1 == v2)

    status = solve!(com)
    @test status == :Infeasible
    @test !com.info.backtracked
end

@testset "Test Equals()" begin
    # test using equal
    com = CS.init()

    v1 = add_var!(com, 1, 2)
    v2 = add_var!(com, 1, 2; fix=2)
    v3 = add_var!(com, 1, 2)
    v4 = add_var!(com, 1, 2)

    add_constraint!(com, CS.equal([v1,v2,v3,v4]))

    status = solve!(com)
    @test status == :Solved
    @test !com.info.backtracked
    @test CS.isfixed(v1) && value(v1) == 2
    @test CS.isfixed(v2) && value(v2) == 2
    @test CS.isfixed(v3) && value(v3) == 2
    @test CS.isfixed(v4) && value(v4) == 2
end

@testset "Test Equals() NotSolved/Infeasible" begin
    # test using equal
    com = CS.init()

    v1 = add_var!(com, 1, 2)
    v2 = add_var!(com, 1, 2; fix=2)
    v3 = add_var!(com, 1, 2)
    v4 = add_var!(com, 1, 3; fix=3)

    add_constraint!(com, CS.equal([v1,v2,v3,v4]))

    status = solve!(com)
    @test status == :Infeasible
    @test !com.info.backtracked
    @test CS.isfixed(v2) && value(v2) == 2
    @test CS.isfixed(v4) && value(v4) == 3

    # test using equal
    com = CS.init()

    v1 = add_var!(com, 1, 2)
    v2 = add_var!(com, 1, 2)
    v3 = add_var!(com, 1, 2)
    v4 = add_var!(com, 1, 2)

    add_constraint!(com, CS.equal([v1,v2,v3,v4]))

    status = solve!(com; backtrack=false)
    @test status == :NotSolved
    @test !com.info.backtracked
    @test !CS.isfixed(v2)
    @test !CS.isfixed(v4)
end

@testset "Graph coloring small" begin
    com = CS.init()

    # cover from numberphile video
    v1 = add_var!(com, 1, 4)
    v2 = add_var!(com, 1, 4)
    v3 = add_var!(com, 1, 4)
    v4 = add_var!(com, 1, 4)
    v5 = add_var!(com, 1, 4)
    v6 = add_var!(com, 1, 4)
    v7 = add_var!(com, 1, 4)
    v8 = add_var!(com, 1, 4)
    v9 = add_var!(com, 1, 4)

    add_constraint!(com, v1 != v2)
    add_constraint!(com, v1 != v3)
    add_constraint!(com, v1 != v4)
    add_constraint!(com, v1 != v5)
    add_constraint!(com, v2 != v3)
    add_constraint!(com, v2 != v5)
    add_constraint!(com, v4 != v3)
    add_constraint!(com, v4 != v5)
    add_constraint!(com, v2 != v6)
    add_constraint!(com, v2 != v7)
    add_constraint!(com, v3 != v7)
    add_constraint!(com, v3 != v8)
    add_constraint!(com, v4 != v8)
    add_constraint!(com, v4 != v9)
    add_constraint!(com, v5 != v9)
    add_constraint!(com, v5 != v6)
    add_constraint!(com, v5 != v6)
    add_constraint!(com, v6 != v9)
    add_constraint!(com, v6 != v9)
    add_constraint!(com, v6 != v7)
    add_constraint!(com, v8 != v9)
    add_constraint!(com, v8 != v7)

    status = solve!(com)
    @test status == :Solved
    @test com.info.backtracked

    # Infeasible with 3 colors
    com = CS.init()
    v1 = add_var!(com, 1, 3)
    v2 = add_var!(com, 1, 3)
    v3 = add_var!(com, 1, 3)
    v4 = add_var!(com, 1, 3)
    v5 = add_var!(com, 1, 3)
    v6 = add_var!(com, 1, 3)
    v7 = add_var!(com, 1, 3)
    v8 = add_var!(com, 1, 3)
    v9 = add_var!(com, 1, 3)

    add_constraint!(com, v1 != v2)
    add_constraint!(com, v1 != v3)
    add_constraint!(com, v1 != v4)
    add_constraint!(com, v1 != v5)
    add_constraint!(com, v2 != v3)
    add_constraint!(com, v2 != v5)
    add_constraint!(com, v4 != v3)
    add_constraint!(com, v4 != v5)
    add_constraint!(com, v2 != v6)
    add_constraint!(com, v2 != v7)
    add_constraint!(com, v3 != v7)
    add_constraint!(com, v3 != v8)
    add_constraint!(com, v4 != v8)
    add_constraint!(com, v4 != v9)
    add_constraint!(com, v5 != v9)
    add_constraint!(com, v5 != v6)
    add_constraint!(com, v5 != v6)
    add_constraint!(com, v6 != v9)
    add_constraint!(com, v6 != v9)
    add_constraint!(com, v6 != v7)
    add_constraint!(com, v8 != v9)
    add_constraint!(com, v8 != v7)

    status = solve!(com)
    @test status == :Infeasible
    @test com.info.backtracked


    # very simple
    com = CS.init()

    v1 = add_var!(com, 1, 2; fix=1)
    v2 = add_var!(com, 1, 2)

    add_constraint!(com, v1 != v2)

    status = solve!(com; backtrack=false)
    @test status == :Solved
    @test !com.info.backtracked
    @test CS.isfixed(v1) && value(v1) == 1
    @test CS.isfixed(v2) && value(v2) == 2

    # infeasible at beginning
    com = CS.init()

    v1 = add_var!(com, 1, 2; fix=1)
    v2 = add_var!(com, 1, 2; fix=1)

    add_constraint!(com, v1 != v2)

    status = solve!(com; backtrack=false)
    @test status == :Infeasible
    @test !com.info.backtracked

    # Error not implemented
    com = CS.init()

    v1 = add_var!(com, 1, 2; fix=1)
    v2 = add_var!(com, 1, 2)
    v3 = add_var!(com, 1, 2)

    @test_throws ErrorException add_constraint!(com, !CS.equal([v1,v2,v3]))
    @test_throws ErrorException add_constraint!(com, !CS.all_different([v1,v2,v3]))
end



end