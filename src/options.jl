mutable struct SolverOptions
    backtrack           :: Bool
    max_bt_steps        :: Int
    backtrack_sorting   :: Bool
    keep_logs           :: Bool
    rtol                :: Float64
    atol                :: Float64
    solution_type       :: DataType
end

function SolverOptions()
    backtrack           = true
    max_bt_steps        = typemax(Int)
    backtrack_sorting   = true
    keep_logs           = false
    rtol                = 1e-6
    atol                = 1e-6
    solution_type       = Float64

    return SolverOptions(backtrack, max_bt_steps, backtrack_sorting, keep_logs, rtol, atol, solution_type)
end

function combine_options(options)
    defaults = SolverOptions()
    options_dict = Dict{Symbol,Any}()
    for kv in options
        if !in(kv[1], fieldnames(SolverOptions))
            @warn "Option "*string(kv[1])*" is not available"
        else
            options_dict[kv[1]] = kv[2]
        end
    end

    for fname in fieldnames(SolverOptions)
        if haskey(options_dict, fname)
            setfield!(defaults, fname, options_dict[fname])
        end
    end
    return defaults
end
