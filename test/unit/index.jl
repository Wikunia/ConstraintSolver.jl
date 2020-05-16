function get_constraints_by_type(com, t)
    constraints = CS.Constraint[]
    for constraint in com.constraints
        if constraint isa t
            push!(constraints, constraint)
        end
    end
    return constraints
end

@testset "Unit Tests" begin
    include("constraints/alldifferent.jl")
    include("constraints/eq_sum.jl")
    include("constraints/equal.jl")
end