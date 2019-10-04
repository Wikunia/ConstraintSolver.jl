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
    CS.add_constraint!(com, com_grid[6]+2*com_grid[7] ==  7)
    
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
end