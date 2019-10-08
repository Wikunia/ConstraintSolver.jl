@testset "Small special tests" begin
@testset "Sum" begin
    com = CS.init()

    com_grid = Array{CS.Variable, 1}(undef, 7)
    com_grid[1] = CS.addVar!(com, 1, 9)
    com_grid[2] = CS.addVar!(com, 1, 9; fix=5)
    com_grid[3] = CS.addVar!(com, 1, 9)
    com_grid[4] = CS.addVar!(com, 1, 9)
    com_grid[5] = CS.addVar!(com, 1, 9)

    com_grid[6] = CS.addVar!(com, 1, 2)
    com_grid[7] = CS.addVar!(com, 3, 5)
    

    CS.rm!(com, com_grid[4], 5)
    CS.remove_above!(com, com_grid[5], 2)

    CS.add_constraint!(com, sum([com_grid[CartesianIndex(ind)] for ind in [1,2]]) == 11)
    CS.add_constraint!(com, sum([com_grid[CartesianIndex(ind)] for ind in [3,4]]) == 11)
    CS.add_constraint!(com, sum([com_grid[CartesianIndex(ind)] for ind in [2,5]]) ==  6)
    # testing coefficients from left and right
    CS.add_constraint!(com, com_grid[6]*1+2*com_grid[7] ==  7)
    
    status = CS.solve!(com; backtrack=false)
    @test status != :Infeasible
    @test CS.isfixed(com_grid[1])
    @test CS.value(com_grid[1]) == 6
    @test CS.isfixed(com_grid[5])
    @test CS.value(com_grid[5]) == 1
    @test !CS.has(com_grid[3], 6)

    @test CS.isfixed(com_grid[6])
    @test CS.value(com_grid[6]) == 1

    @test CS.isfixed(com_grid[7])
    @test CS.value(com_grid[7]) == 3
end

@testset "Infeasible coeff sum" begin
    com = CS.init()

    com_grid = Array{CS.Variable, 1}(undef, 3)
    com_grid[1] = CS.addVar!(com, 1, 9)
    com_grid[2] = CS.addVar!(com, 1, 9)
    com_grid[3] = CS.addVar!(com, 1, 9)
    
    CS.rm!(com, com_grid[2], 2)
    CS.rm!(com, com_grid[2], 3)
    CS.rm!(com, com_grid[2], 4)
    CS.rm!(com, com_grid[2], 6)
    CS.rm!(com, com_grid[2], 8)
        
    CS.add_constraint!(com, com_grid[2]*2+5*com_grid[1]+0*com_grid[3] == 21)
    
    status = CS.solve!(com; backtrack=true)
    @test status == :Infeasible
end

@testset "Negative coeff sum" begin
    com = CS.init()

    com_grid = Array{CS.Variable, 1}(undef, 3)
    com_grid[1] = CS.addVar!(com, 1, 9)
    com_grid[2] = CS.addVar!(com, 1, 9)
    com_grid[3] = CS.addVar!(com, 1, 9)
    
    CS.remove_above!(com, com_grid[3], 3)

    CS.add_constraint!(com, sum([7,5,-10].*com_grid) == -13)
    
    status = CS.solve!(com; backtrack=true)
    @test status == :Solved
    @test CS.isfixed(com_grid[1]) && CS.value(com_grid[1]) == 1
    @test CS.isfixed(com_grid[2]) && CS.value(com_grid[2]) == 2
    @test CS.isfixed(com_grid[3]) && CS.value(com_grid[3]) == 3

    com = CS.init()

    com_grid = Array{CS.Variable, 1}(undef, 3)
    com_grid[1] = CS.addVar!(com, 1, 5)
    com_grid[2] = CS.addVar!(com, 1, 2)
    com_grid[3] = CS.addVar!(com, 1, 9)
    
    CS.add_constraint!(com, sum([7,5,-10].*com_grid) == -13)
    
    status = CS.solve!(com; backtrack=true)
    @test status == :Solved
    @test CS.isfixed(com_grid[1]) && CS.value(com_grid[1]) == 1
    @test CS.isfixed(com_grid[2]) && CS.value(com_grid[2]) == 2
    @test CS.isfixed(com_grid[3]) && CS.value(com_grid[3]) == 3

    com = CS.init()

    v1 = CS.addVar!(com, 1, 5)
    v2 = CS.addVar!(com, 5, 10)
    
    CS.add_constraint!(com, v1-v2 == 0)
    
    status = CS.solve!(com; backtrack=false)
    @test status == :Solved
    @test CS.isfixed(v1) && CS.value(v1) == 5
    @test CS.isfixed(v2) && CS.value(v2) == 5
end

@testset "Equal constraint" begin
    # nothing to do
    com = CS.init()

    v1 = CS.addVar!(com, 1, 2; fix=2)
    v2 = CS.addVar!(com, 1, 2; fix=2)

    CS.add_constraint!(com, v1 == v2)

    status = CS.solve!(com)
    @test status == :Solved
    @test !com.info.backtracked
    @test CS.isfixed(v1) && CS.value(v1) == 2
    @test CS.isfixed(v2) && CS.value(v2) == 2

    # normal
    com = CS.init()

    v1 = CS.addVar!(com, 1, 2)
    v2 = CS.addVar!(com, 1, 2; fix=2)

    CS.add_constraint!(com, v1 == v2)

    status = CS.solve!(com)
    @test status == :Solved
    @test !com.info.backtracked
    @test CS.isfixed(v1) && CS.value(v1) == 2
    @test CS.isfixed(v2) && CS.value(v2) == 2

    # set but infeasible
    com = CS.init()

    v1 = CS.addVar!(com, 1, 2)
    v2 = CS.addVar!(com, 1, 2; fix=2)

    CS.add_constraint!(com, v1 == v2)
    CS.add_constraint!(com, CS.all_different([v1, v2]))

    status = CS.solve!(com)
    @test status == :Infeasible
    @test !com.info.backtracked

    # set but infeasible reversed
    com = CS.init()

    v1 = CS.addVar!(com, 1, 2)
    v2 = CS.addVar!(com, 1, 2; fix=2)

    CS.add_constraint!(com, v2 == v1)
    CS.add_constraint!(com, CS.all_different([v1, v2]))

    status = CS.solve!(com)
    @test status == :Infeasible
    @test !com.info.backtracked

    # reversed
    com = CS.init()

    v1 = CS.addVar!(com, 1, 2)
    v2 = CS.addVar!(com, 1, 2; fix=2)

    CS.add_constraint!(com, v2 == v1)

    status = CS.solve!(com)
    @test status == :Solved
    @test !com.info.backtracked
    @test CS.isfixed(v1) && CS.value(v1) == 2
    @test CS.isfixed(v2) && CS.value(v2) == 2

    # test with more
    com = CS.init()

    v1 = CS.addVar!(com, 1, 2)
    v2 = CS.addVar!(com, 1, 2; fix=2)
    v3 = CS.addVar!(com, 1, 2)
    v4 = CS.addVar!(com, 1, 2)

    CS.add_constraint!(com, v1 == v2)
    CS.add_constraint!(com, v1 == v4)
    CS.add_constraint!(com, v1 == v3)

    status = CS.solve!(com)
    @test status == :Solved
    @test !com.info.backtracked
    @test CS.isfixed(v1) && CS.value(v1) == 2
    @test CS.isfixed(v2) && CS.value(v2) == 2
    @test CS.isfixed(v3) && CS.value(v3) == 2
    @test CS.isfixed(v4) && CS.value(v4) == 2
end

@testset "NotSolved or infeasible" begin
    # NotSolved without backtracking
    com = CS.init()

    v1 = CS.addVar!(com, 1, 2)
    v2 = CS.addVar!(com, 1, 2)

    CS.add_constraint!(com, v2 == v1)

    status = CS.solve!(com; backtrack=false)
    @test status == :NotSolved
    @test !com.info.backtracked

    # Infeasible without backtracking
    com = CS.init()

    v1 = CS.addVar!(com, 1, 2; fix=1)
    v2 = CS.addVar!(com, 1, 2; fix=2)

    CS.add_constraint!(com, v2 == v1)

    status = CS.solve!(com)
    @test status == :Infeasible
    @test !com.info.backtracked

    # Infeasible without backtracking reverse
    com = CS.init()

    v1 = CS.addVar!(com, 1, 2; fix=1)
    v2 = CS.addVar!(com, 1, 2; fix=2)

    CS.add_constraint!(com, v1 == v2)

    status = CS.solve!(com)
    @test status == :Infeasible
    @test !com.info.backtracked
end

@testset "Test Equals()" begin
    # test using equal
    com = CS.init()

    v1 = CS.addVar!(com, 1, 2)
    v2 = CS.addVar!(com, 1, 2; fix=2)
    v3 = CS.addVar!(com, 1, 2)
    v4 = CS.addVar!(com, 1, 2)

    CS.add_constraint!(com, CS.equal([v1,v2,v3,v4]))

    status = CS.solve!(com)
    @test status == :Solved
    @test !com.info.backtracked
    @test CS.isfixed(v1) && CS.value(v1) == 2
    @test CS.isfixed(v2) && CS.value(v2) == 2
    @test CS.isfixed(v3) && CS.value(v3) == 2
    @test CS.isfixed(v4) && CS.value(v4) == 2
end

@testset "Test Equals() NotSolved/Infeasible" begin
    # test using equal
    com = CS.init()

    v1 = CS.addVar!(com, 1, 2)
    v2 = CS.addVar!(com, 1, 2; fix=2)
    v3 = CS.addVar!(com, 1, 2)
    v4 = CS.addVar!(com, 1, 3; fix=3)

    CS.add_constraint!(com, CS.equal([v1,v2,v3,v4]))

    status = CS.solve!(com)
    @test status == :Infeasible
    @test !com.info.backtracked
    @test CS.isfixed(v2) && CS.value(v2) == 2
    @test CS.isfixed(v4) && CS.value(v4) == 3

    # test using equal
    com = CS.init()

    v1 = CS.addVar!(com, 1, 2)
    v2 = CS.addVar!(com, 1, 2)
    v3 = CS.addVar!(com, 1, 2)
    v4 = CS.addVar!(com, 1, 2)

    CS.add_constraint!(com, CS.equal([v1,v2,v3,v4]))

    status = CS.solve!(com; backtrack=false)
    @test status == :NotSolved
    @test !com.info.backtracked
    @test !CS.isfixed(v2)
    @test !CS.isfixed(v4)
end


end