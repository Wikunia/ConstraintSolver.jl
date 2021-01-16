#=
    The problems are taken from http://www.hakank.org/julia/constraints/

    Thanks a lot to Håkan Kjellerstrand
=#



#
# all_different_except_c
#
# Ensure that all values (except c) are distinct
# Thanks to Ole who fixed some initial problems I had.
# (See https://github.com/Wikunia/ConstraintSolver.jl/issues/202 for
# details.)
#
function all_different_except_c(model, x, c=0)
    n = length(x)

    # Define the variables we'll use
    b_len = length([1 for i in 2:n for j in 1:i-1 for k in 1:3])
    bs = @variable(model, [1:b_len], Bin) # "Anonymous" variables
    c = 1
    for i in 2:n, j in 1:i-1
        b1 = bs[c]
        b2 = bs[c+1]
        b3 = bs[c+2]
        @constraint(model, b1 := {x[i] != 0})
        @constraint(model, b2 := {x[j] != 0})
        @constraint(model, b3 := {b1 + b2 == 2})
        @constraint(model, b3 => {x[i] != x[j]})
        c += 3
    end
    # return bs so we can print it in the main function
    return bs
end

#
# increasing(model, x)
#
# Ensure that array x in increasing order
#
function increasing(model, x)
    len = length(x)
    for i in 2:len
        @constraint(model, x[i-1] <= x[i])
    end
end

#=
  Decomposition of global constraint alldifferent_except_0 in Julia + ConstraintSolver.
  From Global constraint catalogue:
  http://www.emn.fr/x-info/sdemasse/gccat/Calldifferent_except_0.html
  """
  Enforce all variables of the collection VARIABLES to take distinct
  values, except those variables that are assigned to 0.
  Example
     (<5, 0, 1, 9, 0, 3>)
  The alldifferent_except_0 constraint holds since all the values
  (that are different from 0) 5, 1, 9 and 3 are distinct.
  """
  Model created by Hakan Kjellerstrand, hakank@gmail.com
  See also my Julia page: http://www.hakank.org/julia/
=#

function all_different_except_0(n=10)
    model = Model(optimizer_with_attributes(CS.Optimizer,
                                            "all_solutions"=>true,
                                            # "all_solutions"=>false,
                                            "logging"=>[],
                                            )
                                            )
    @variable(model, 0 <= x[1:n] <= n, Int)

    bs = all_different_except_c(model,x,0)
    increasing(model, x)

    optimize!(model)

    status = JuMP.termination_status(model)
    @assert status == MOI.OPTIMAL
    num_sols = MOI.get(model, MOI.ResultCount())
    @assert num_sols == 2^n
end
