#=
    Support for >= and >
=#
const UnionGT{T} = Union{Strictly{T, MOI.GreaterThan{T}}, MOI.GreaterThan{T}}
