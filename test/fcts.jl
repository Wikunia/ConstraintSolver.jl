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

@testset "get_constrained_best_bound" begin 
    ##################################
    # negative values
    ##################################
    com = CS.ConstraintSolverModel()
    x = [CS.add_var!(com, -5, 5) for i=1:5]

    terms = MOI.ScalarAffineTerm{Float64}[]
    indices = Int[]
    for i=1:5
        push!(terms, MOI.ScalarAffineTerm(1.0,MOI.VariableIndex(i)))
        push!(indices, i)
    end
    fct = MOI.ScalarAffineFunction(terms, 2.0)
    set = MOI.LessThan(10.0)
    lc = CS.LinearConstraint(
        0, fct, set, indices, Int[], false, 
        Float64[], Float64[], Float64[], Float64[], true, zero(UInt64)
    )
    # constraint sum(x)+2.0 <= 10
    obj_fct = CS.LinearCombinationObjective(
        CS.LinearCombination([1,2,3,4,5], [1.0,2,3,4,5]),
        5.0,
        [1,2,3,4,5]
    )
    # objective x[1]+2x[2]+3x[3]+4x[4]+5x[5]+5
    com.sense = MOI.MAX_SENSE
    # optimal value is 51
    @test CS.get_constrained_best_bound(com, lc, fct, set, obj_fct, 0, 0) >= 51

    ##################################
    # positive values 
    ##################################
    com = CS.ConstraintSolverModel()
    x = [CS.add_var!(com, 0, 5) for i=1:5]

    terms = MOI.ScalarAffineTerm{Float64}[]
    indices = Int[]
    for i=1:5
        push!(terms, MOI.ScalarAffineTerm(-1.0,MOI.VariableIndex(i)))
        push!(indices, i)
    end
    fct = MOI.ScalarAffineFunction(terms, 2.0)
    set = MOI.LessThan(-6.0)
    lc = CS.LinearConstraint(
        0, fct, set, indices, Int[], false, 
        Float64[], Float64[], Float64[], Float64[], true, zero(UInt64)
    )
    # constraint sum(x)-2.0 >= 6
    obj_fct = CS.LinearCombinationObjective(
        CS.LinearCombination([1,2,3,4,5], [1.0,2,3,4,5]),
        5.0,
        [1,2,3,4,5]
    )
    # objective x[1]+2x[2]+3x[3]+4x[4]+5x[5]+5
    com.sense = MOI.MIN_SENSE
    # optimal value is 16
    computed_bound = CS.get_constrained_best_bound(com, lc, fct, set, obj_fct, 0, 0)
    @test computed_bound <= 16 && computed_bound > typemin(Float64)

    ##################################
    # positive relevant values 
    ##################################
    com = CS.ConstraintSolverModel()
    x = [CS.add_var!(com, 0, 5) for i=1:5]
    y = CS.add_var!(com, -5, 5)

    terms = MOI.ScalarAffineTerm{Float64}[]
    indices = Int[]
    for i=1:5
        push!(terms, MOI.ScalarAffineTerm(-1.0,MOI.VariableIndex(i)))
        push!(indices, i)
    end
    push!(terms, MOI.ScalarAffineTerm(-1.0,MOI.VariableIndex(6)))
    push!(indices, 6)
    fct = MOI.ScalarAffineFunction(terms, 0.0)
    set = MOI.LessThan(20.0)
    lc = CS.LinearConstraint(
        0, fct, set, indices, Int[], false, 
        Float64[], Float64[], Float64[], Float64[], true, zero(UInt64)
    )
    # y can be negative but it's not part of the objective anyway
    # constraint sum(x)+y >= 20
    obj_fct = CS.LinearCombinationObjective(
        CS.LinearCombination([1,2,3,4,5], [5.0,4,3,2,1]),
        5.0,
        [1,2,3,4,5]
    )
    # objective 5x[1]+4x[2]+3x[3]+2x[4]+1x[5]+5
    com.sense = MOI.MIN_SENSE
    # optimal value is 35
    computed_bound = CS.get_constrained_best_bound(com, lc, fct, set, obj_fct, 0, 0)
    @test computed_bound <= 35 && computed_bound > typemin(Float64)

    ##################################
    # positive relevant values  Max
    ##################################
    com = CS.ConstraintSolverModel()
    x = [CS.add_var!(com, 0, 5) for i=1:3]
    y = CS.add_var!(com, -5, 5)

    terms = MOI.ScalarAffineTerm{Float64}[]
    indices = Int[]
    for i=1:3
        push!(terms, MOI.ScalarAffineTerm(1.0,MOI.VariableIndex(i)))
        push!(indices, i)
    end
    push!(terms, MOI.ScalarAffineTerm(1.0,MOI.VariableIndex(4)))
    push!(indices, 4)
    fct = MOI.ScalarAffineFunction(terms, 0.0)
    set = MOI.LessThan(7.0)
    lc = CS.LinearConstraint(
        0, fct, set, indices, Int[], false, 
        Float64[], Float64[], Float64[], Float64[], true, zero(UInt64)
    )
    # y can be negative but it's not part of the objective anyway
    # constraint sum(x)+y <= 7
    obj_fct = CS.LinearCombinationObjective(
        CS.LinearCombination([1,2,3], [5.0,4.9,3.2]),
        -5.0,
        [1,2,3]
    )
    # objective 5x[1]+4.9x[2]+3.2x[3]
    com.sense = MOI.MAX_SENSE
    # optimal value is 50.9
    computed_bound = CS.get_constrained_best_bound(com, lc, fct, set, obj_fct, 0, 0)
    @test computed_bound >= 50.9-1e-6 && computed_bound < typemax(Float64)


    ##################################
    # negative values so bad bound
    ##################################
    com = CS.ConstraintSolverModel()
    x = [CS.add_var!(com, -1, 5) for i=1:3]
    y = CS.add_var!(com, -5, 5)

    terms = MOI.ScalarAffineTerm{Float64}[]
    indices = Int[]
    push!(terms, MOI.ScalarAffineTerm(-1.0,MOI.VariableIndex(1)))
    push!(indices, 1)
    push!(terms, MOI.ScalarAffineTerm(-1.0,MOI.VariableIndex(2)))
    push!(indices, 2)
    push!(terms, MOI.ScalarAffineTerm(1.0,MOI.VariableIndex(3)))
    push!(indices, 3)
    
    push!(terms, MOI.ScalarAffineTerm(-1.0,MOI.VariableIndex(4)))
    push!(indices, 4)
    fct = MOI.ScalarAffineFunction(terms, 0.0)
    set = MOI.LessThan(7.0)
    lc = CS.LinearConstraint(
        0, fct, set, indices, Int[], false, 
        Float64[], Float64[], Float64[], Float64[], true, zero(UInt64)
    )
    # y can be negative but it's not part of the objective anyway
    # constraint x[1]+x[2]-x[3] >= 7
    obj_fct = CS.LinearCombinationObjective(
        CS.LinearCombination([1,2,3], [5.0,4.9,3.2]),
        -5.0,
        [1,2,3]
    )
    # objective 5x[1]+4.9x[2]+3.2x[3]
    com.sense = MOI.MIN_SENSE
    # optimal value is 1.6
    computed_bound = CS.get_constrained_best_bound(com, lc, fct, set, obj_fct, 0, 0)
    @test computed_bound <= 1.6+1e-6
end

@testset "TableLogging" begin
    table = CS.TableSetup(
        [:open_nodes, :closed_nodes, :incumbent, :best_bound, :duration],
        ["#Open", "#Closed", "Incumbent", "Best Bound", "[s]"],
        [10,10,20,20,10]; 
        min_diff_duration=5.0)
    table_header = CS.get_header(table)
    lines = split(table_header, "\n")
    @test length(lines) == 2
    @test length(lines[2]) == sum(table.col_widths)
    @test occursin("#Open", lines[1])
    @test occursin("#Closed", lines[1])

    table_row = CS.TableRow(0,0,1.0,1.0,0.203)
    line = CS.get_row(table, table_row)
    @test length(line) == sum(table.col_widths)
    line_split = split(line, r"\s+")
    # +2 for first and last empty
    @test length(line_split) == length(table.col_widths)+2
    @test line_split[2] == "0"
    # only precision 2
    @test line_split[end-1] == "0.20"

    table_row = CS.TableRow(1000000000000,1000000000000,1.0,1.0,0.203)
    line = CS.get_row(table, table_row)
    @test length(line) == sum(table.col_widths)
    line_split = split(line, r"\s+")
    # +2 for first and last empty
    @test length(line_split) == length(table.col_widths)+2
    @test line_split[2] == ">>"
    @test line_split[3] == ">>"

    # duration too long
    table_row = CS.TableRow(1,2,1.0,1.0,10000000000.203)
    line = CS.get_row(table, table_row)
    @test length(line) == sum(table.col_widths)
    line_split = split(line, r"\s+")
    # +2 for first and last empty
    @test length(line_split) == length(table.col_widths)+2
    @test line_split[end-1] == ">>"

    # better precision for bound
    table_row = CS.TableRow(1,2,1.0,0.000004,0.203)
    line = CS.get_row(table, table_row)
    @test length(line) == sum(table.col_widths)
    line_split = split(line, r"\s+")
    # +2 for first and last empty
    @test length(line_split) == length(table.col_widths)+2
    @test line_split[end-2] == "0.000004"

    # Incumbent precision too high
    table = CS.TableSetup(
        [:open_nodes, :closed_nodes, :incumbent, :best_bound, :duration],
        ["#Open", "#Closed", "Incumbent", "Best Bound", "[s]"],
        [10,10,10,10,10]; 
        min_diff_duration=5.0)
    table_row = CS.TableRow(1,2,10000000.02,0.000004,0.203)
    line = CS.get_row(table, table_row)
    @test length(line) == sum(table.col_widths)
    line_split = split(line, r"\s+")
    # +2 for first and last empty
    @test length(line_split) == length(table.col_widths)+2
    @test line_split[4] == "10000000.0"

    # need to increase size for #Open
    table = CS.TableSetup(
        [:open_nodes, :closed_nodes, :incumbent, :best_bound, :duration],
        ["#Open", "#Closed", "Incumbent", "Best Bound", "[s]"],
        [1,10,20,20,10]; 
        min_diff_duration=5.0)
    table_header = CS.get_header(table)
    lines = split(table_header, "\n")
    @test length(lines) == 2
    @test length(lines[2]) == sum(table.col_widths)
    @test length(lines[2]) > sum([1,10,20,20,10])
    @test occursin("#Open", lines[1])
    @test occursin("#Closed", lines[1])
end
end
