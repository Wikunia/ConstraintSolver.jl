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
    include("constraints/and.jl")
    include("constraints/or.jl")
    include("constraints/scc.jl")
    include("constraints/equal_to.jl")
    include("constraints/equal.jl")
    include("constraints/less_than.jl")
    include("constraints/strictly_less_than.jl")
    include("constraints/not_equal.jl")
    include("constraints/svc.jl")
    include("constraints/table.jl")
    include("constraints/indicator.jl")
    include("constraints/reified.jl")
    include("constraints/geqset.jl")
end
