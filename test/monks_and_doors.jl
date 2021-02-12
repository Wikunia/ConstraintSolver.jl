# This test case is copied from http://hakank.org/julia/constraints/monks_and_doors.jl
# which is a website by Håkan Kjellerstrand
# please check it out :)

@testset "Monks & Doors" begin
    all_solutions = true
    model = Model(optimizer_with_attributes(CS.Optimizer,   
        "all_solutions"=> all_solutions,
        # "all_optimal_solutions"=>all_solutions, 
        "logging"=>[],

        "traverse_strategy"=>:BFS,
        "branch_split"=>:InHalf,

        "branch_strategy" => :IMPS, # default
    ))

    num_doors = 4
    num_monks = 8
    @variable(model, doors[1:num_doors], Bin)
    da,db,dc,dd = doors 
    door_names = ["A","B","C","D"]

    @variable(model, monks[1:num_monks], Bin)
    m1,m2,m3,m4,m5,m6,m7,m8 = monks

    # Monk 1: Door A is the exit.
    # M1 #= A (Picat constraint)
    @constraint(model, m1 == da)

    #  Monk 2: At least one of the doors B and C is the exit.
    # M2 #= 1 #<=> (B #\/ C)
    @constraint(model, m2 := { db == 1 || dc == 1})

    #  Monk 3: Monk 1 and Monk 2 are telling the truth.
    # M3 #= 1 #<=> (M1 #/\ M2)
    @constraint(model, m3 := { m1 == 1 && m2 == 1})

    #  Monk 4: Doors A and B are both exits.
    # M4 #= 1 #<=> (A #/\ B)
    @constraint(model, m4 := { da == 1 && db == 1})

    #  Monk 5: Doors A and C are both exits.
    # M5 #= 1 #<=> (A #/\ C)
    @constraint(model, m5 := { da == 1 && dc == 1})

    #  Monk 6: Either Monk 4 or Monk 5 is telling the truth.
    # M6 #= 1 #<=> (M4 #\/ M5)
    @constraint(model, m6 := { m4 == 1|| m5 == 1})

    #  Monk 7: If Monk 3 is telling the truth, so is Monk 6.
    # M7 #= 1 #<=> (M3 #=> M6)
    @constraint(model, m7 := { m3 => {m6 == 1}})

    #  Monk 8: If Monk 7 and Monk 8 are telling the truth, so is Monk 1.
    # M8 #= 1 #<=> ((M7 #/\ M8) #=> (M1))
    b1 = @variable(model, binary=true)
    @constraint(model, b1 := {m7 == 1 && m8 == 1})
    @constraint(model, m8 := {b1 => {m1 == 1}})

    # Exactly one door is an exit.
    # (A + B + C + D) #= 1
    @constraint(model, da + db + dc + dd == 1)

    # Solve the problem
    optimize!(model)

    status = JuMP.termination_status(model)
    # println("status:$status")
    num_sols = 0
    @test status == MOI.OPTIMAL
    num_sols = MOI.get(model, MOI.ResultCount())
    @test num_sols == 1
    doors_val = convert.(Integer,JuMP.value.(doors))
    monks_val = convert.(Integer,JuMP.value.(monks))
    # exit door is A
    @test doors_val[1] == 1
    @test sum(doors_val) == 1
    @test sum(monks_val) == 3
    # monks 1,7,8 are the only ones who tell the truth
    @test monks_val[1] == monks_val[7] == monks_val[8] == 1
end