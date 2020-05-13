function UnitTestModel(constraint_types=["all"])
    # build the model without optimizing
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= x[1:10] <= 5, Int)
    @variable(m, y[1:10], CS.Integers([-3,1,2,3]))
    # if a new constraint type exists it should be added here to be able to access it in the unit tests
    if "all" in constraint_types || "alldifferent" in constraint_types
        @constraint(m, x in CS.AllDifferentSet())
    end
    if "all" in constraint_types || "equalto" in constraint_types
        @constraint(m, sum(y)+1 == 5)
    end
    if "all" in constraint_types || "lessthan" in constraint_types
        @constraint(m, sum(x)+1 <= 5)
    end
    if "all" in constraint_types || "greaterthan" in constraint_types
        @constraint(m, sum(x)+1 >= 2)
    end
    if "all" in constraint_types || "table" in constraint_types
        table = [2 3 5; 1 2 4; 0 3 7];
        @constraint(m, x[1:3] in CS.TableSet(table))
    end
    if "all" in constraint_types || "equalset" in constraint_types
        @constraint(m, y[1:3] in CS.EqualSet())
        @constraint(m, x[1] == y[2])
    end
    if "all" in constraint_types || "svc" in constraint_types
        @constraint(m, x[1] >= y[2])
    end
    optimize!(m)
    return JuMP.backend(m).optimizer.model.inner
end

function get_constraint_by_type(com, t)
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
end