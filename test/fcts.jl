@testset "Function tests" begin

@testset "Logs"  begin

    var_states = Dict{Int,Vector{Int}}()
    var_changes = Dict{Int,Vector{Tuple{Symbol, Int, Int, Int}}}()
    children = CS.TreeLogNode{Int}[]
    l1 = CS.TreeLogNode(0,:Open,0,0,0,0,var_states, var_changes, children) 
    l2 = CS.TreeLogNode(0,:Closed,0,0,0,0,var_states, var_changes, children) 
    @test !CS.same_logs(l1,l2) 

    # different children order
    children = CS.TreeLogNode{Int}[]
    tln1 = CS.TreeLogNode(0,:Open,0,1,0,0,var_states, var_changes, CS.TreeLogNode{Int}[]) 
    tln2 = CS.TreeLogNode(0,:Open,0,2,0,0,var_states, var_changes, CS.TreeLogNode{Int}[]) 
    push!(children, tln1)
    push!(children, tln2)
    l1 = CS.TreeLogNode(0,:Closed,0,0,0,0,var_states, var_changes, children[[1,2]]) 
    l2 = CS.TreeLogNode(0,:Closed,0,0,0,0,var_states, var_changes, children[[2,1]])
    @test !CS.same_logs(l1,l2) 

    # missing one child
    children = CS.TreeLogNode{Float64}[]
    tln1 = CS.TreeLogNode(0,:Open,0.0,1,0,0,var_states, var_changes, CS.TreeLogNode{Float64}[]) 
    tln2 = CS.TreeLogNode(0,:Open,0.0,2,0,0,var_states, var_changes, CS.TreeLogNode{Float64}[]) 
    push!(children, tln1)
    push!(children, tln2)
    l1 = CS.TreeLogNode(0,:Closed,0.0,0,0,0,var_states, var_changes, children[[1,2]]) 
    l2 = CS.TreeLogNode(0,:Closed,0.0,0,0,0,var_states, var_changes, children[[1]])
    @test !CS.same_logs(l1,l2) 

    # 2 layer children different struture
    children1 = CS.TreeLogNode{Int}[]
    tln13 = CS.TreeLogNode(0,:Open,0,3,0,0,var_states, var_changes, CS.TreeLogNode{Int}[]) 
    tln11 = CS.TreeLogNode(0,:Open,0,1,0,0,var_states, var_changes, [tln13]) 
    tln12 = CS.TreeLogNode(0,:Open,0,2,0,0,var_states, var_changes, CS.TreeLogNode{Int}[]) 
    push!(children1, tln11)
    push!(children1, tln12)
    children2 = CS.TreeLogNode{Int}[]
    tln23 = CS.TreeLogNode(0,:Open,0,3,0,0,var_states, var_changes, CS.TreeLogNode{Int}[]) 
    tln21 = CS.TreeLogNode(0,:Open,0,1,0,0,var_states, var_changes, CS.TreeLogNode{Int}[]) 
    tln22 = CS.TreeLogNode(0,:Open,0,2,0,0,var_states, var_changes, [tln23]) 
    push!(children2, tln21)
    push!(children2, tln22)
    l1 = CS.TreeLogNode(0,:Closed,0,0,0,0,var_states, var_changes, children1) 
    l2 = CS.TreeLogNode(0,:Closed,0,0,0,0,var_states, var_changes, children2)
    @test !CS.same_logs(l1,l2)

    # 2 layer children different position
    children1 = CS.TreeLogNode{Int}[]
    tln13 = CS.TreeLogNode(0,:Open,0,3,0,0,var_states, var_changes, CS.TreeLogNode{Int}[]) 
    tln14 = CS.TreeLogNode(0,:Open,0,4,0,0,var_states, var_changes, CS.TreeLogNode{Int}[]) 
    tln11 = CS.TreeLogNode(0,:Open,0,1,0,0,var_states, var_changes, [tln13,tln14]) 
    tln12 = CS.TreeLogNode(0,:Open,0,2,0,0,var_states, var_changes, CS.TreeLogNode{Int}[]) 
    push!(children1, tln11)
    push!(children1, tln12)
    children2 = CS.TreeLogNode{Int}[]
    tln23 = CS.TreeLogNode(0,:Open,0,3,0,0,var_states, var_changes, CS.TreeLogNode{Int}[]) 
    tln24 = CS.TreeLogNode(0,:Open,0,4,0,0,var_states, var_changes, CS.TreeLogNode{Int}[]) 
    tln21 = CS.TreeLogNode(0,:Open,0,1,0,0,var_states, var_changes, [tln24, tln23]) 
    tln22 = CS.TreeLogNode(0,:Open,0,2,0,0,var_states, var_changes, CS.TreeLogNode{Int}[]) 
    push!(children2, tln21)
    push!(children2, tln22)
    l1 = CS.TreeLogNode(0,:Closed,0,0,0,0,var_states, var_changes, children1) 
    l2 = CS.TreeLogNode(0,:Closed,0,0,0,0,var_states, var_changes, children2)
    @test !CS.same_logs(l1,l2) 
end

@testset "get_idx_array_diff" begin
    ad = CS.get_idx_array_diff([3,5,7], [7,5,2,9])
    @test ad.only_left_idx == [1]
    @test ad.same_left_idx == [2,3]
    @test ad.same_right_idx == [2,1]
    @test ad.only_right_idx == [3,4]

    ad = CS.get_idx_array_diff([1,2,3,4], [5,4,6])
    @test ad.only_left_idx == [1,2,3]
    @test ad.same_left_idx == [4]
    @test ad.same_right_idx == [2]
    @test ad.only_right_idx == [1,3]

    ad = CS.get_idx_array_diff([5,10,6], [17,20,13,10])
    @test ad.only_left_idx == [1,3]
    @test ad.same_left_idx == [2]
    @test ad.same_right_idx == [4]
    @test ad.only_right_idx == [3,1,2]
end
end