using Test
using ConstraintSolver
const CS = ConstraintSolver

import MathOptInterface
const MOI = MathOptInterface

import ForwardDiff
using JuMP
using LinearAlgebra: dot

@testset "StableSet" begin
    @testset "Weighted stable set" begin
        matrix = [
            0 1 1 0
            1 0 1 0
            1 1 0 1
            0 0 1 0
        ]
        model = CSTestSolver()
        x = [MOI.add_constrained_variable(model, MOI.ZeroOne()) for _ = 1:4]
        for i = 1:4, j = 1:4
            if matrix[i, j] == 1 && i < j
                (z, _) = MOI.add_constrained_variable(model, MOI.GreaterThan(0.0))
                MOI.add_constraint(model, z, MOI.Integer())
                MOI.add_constraint(model, z, MOI.LessThan(1.0))
                f = MOI.ScalarAffineFunction(
                    [
                        MOI.ScalarAffineTerm(1.0, x[i][1]),
                        MOI.ScalarAffineTerm(1.0, x[j][1]),
                        MOI.ScalarAffineTerm(1.0, z),
                    ],
                    0.0,
                )
                MOI.add_constraint(model, f, MOI.EqualTo(1.0))
            end
        end
        weights = [0.2, 0.1, 0.2, 0.1]
        terms = [MOI.ScalarAffineTerm(weights[i], x[i][1]) for i in eachindex(x)]
        objective = MOI.ScalarAffineFunction(terms, 0.0)
        MOI.set(model, MOI.ObjectiveFunction{typeof(objective)}(), objective)
        MOI.set(model, MOI.ObjectiveSense(), MOI.MAX_SENSE)
        MOI.optimize!(model)
        @test MOI.get(model, MOI.VariablePrimal(), x[4][1]) == 1
        @test MOI.get(model, MOI.VariablePrimal(), x[1][1]) == 1
        @test MOI.get(model, MOI.ObjectiveValue()) ≈ 0.3
    end

    @testset "Weighted stable set JuMP" begin
        matrix = [
            0 1 1 0
            1 0 1 0
            1 1 0 1
            0 0 1 0
        ]
        m = Model(CSJuMPTestSolver())
        x = @variable(m, x[1:4], Bin)
        for i = 1:4, j = i+1:4
            if matrix[i, j] == 1
                @constraint(m, x[i] + x[j] <= 1)
            end
        end
        w = [0.2, 0.1, 0.2, 0.1]
        @objective(m, Max, dot(w, x))
        optimize!(m)
        @test JuMP.value(x[4]) ≈ 1
        @test JuMP.value(x[1]) ≈ 1
        @test JuMP.value(x[2]) ≈ 0
        @test JuMP.value(x[3]) ≈ 0
        @test JuMP.objective_value(m) ≈ 0.3
    end

    @testset "Bigger stable set using <= " begin
        matrix = [
            0 1 0 1 0 0 1 0 0 1
            1 0 1 0 1 0 0 0 0 0
            0 1 0 1 0 0 0 0 1 0
            1 0 1 0 1 1 0 0 0 0
            0 1 0 1 0 1 1 1 0 0
            0 0 0 1 1 0 1 0 0 0
            1 0 0 0 1 1 0 1 0 0
            0 0 0 0 1 0 1 0 1 0
            0 0 1 0 0 0 0 1 0 1
            1 0 0 0 0 0 0 0 1 0
        ]
        n = 10
        m = Model(CSJuMPTestSolver())
        @variable(m, x[1:n], Bin)
        for i = 1:n, j = i+1:n
            if matrix[i, j] == 1
                @constraint(m, x[i] + x[j] <= 1)
            end
        end
        w = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
        @objective(m, Max, dot(w, x))
        optimize!(m)
        @test MOI.get(m, MOI.ObjectiveValue()) ≈ 2.7
    end

    function weighted_stable_set(w)
        matrix = [
            0 1 1 0
            1 0 1 0
            1 1 0 1
            0 0 1 0
        ]
        model = CS.Optimizer(solution_type = Real, logging = [])
        x = [MOI.add_constrained_variable(model, MOI.ZeroOne()) for _ = 1:4]
        for i = 1:4, j = 1:4
            if matrix[i, j] == 1 && i < j
                (z, _) = MOI.add_constrained_variable(model, MOI.GreaterThan(0.0))
                MOI.add_constraint(model, z, MOI.Integer())
                MOI.add_constraint(model, z, MOI.LessThan(1.0))
                f = MOI.ScalarAffineFunction(
                    [
                        MOI.ScalarAffineTerm(1.0, x[i][1]),
                        MOI.ScalarAffineTerm(1.0, x[j][1]),
                        MOI.ScalarAffineTerm(1.0, z),
                    ],
                    0.0,
                )
                MOI.add_constraint(model, f, MOI.EqualTo(1.0))
                # ConstraintSolver.add_constraint!(model, x[i] + x[j] <= 1)
            end
        end
        # sum(w[i] * x[i] for i in V) - stable_set == 0
        terms = [MOI.ScalarAffineTerm(w[i], x[i][1]) for i in eachindex(x)]
        objective = MOI.ScalarAffineFunction(terms, zero(eltype(w)))
        MOI.set(model, MOI.ObjectiveFunction{typeof(objective)}(), objective)
        MOI.set(model, MOI.ObjectiveSense(), MOI.MAX_SENSE)
        MOI.optimize!(model)
        return MOI.get(model, MOI.ObjectiveValue())
    end

    # type piracy for the greater good
    # see https://github.com/JuliaDiff/ForwardDiff.jl/issues/318
    function Base.typemin(::Type{ForwardDiff.Dual{T,V,N}}) where {T,V,N}
        ForwardDiff.Dual{T,V,N}(typemin(V))
    end

    @testset "Differentiating stable set" begin
        weights = [0.2, 0.1, 0.2, 0.1]
        # ∇w = Zygote.gradient(weighted_stable_set, weights)
        ∇w = ForwardDiff.gradient(weighted_stable_set, weights)
        @test ∇w[1] ≈ 1
        @test ∇w[4] ≈ 1
        @test ∇w[2] ≈ ∇w[3] ≈ 0
    end
end
