mutable struct SolverOptions
    backtrack           :: Bool
    max_bt_steps        :: Int64
    backtrack_sorting   :: Bool
    keep_logs           :: Bool
end

function get_default_options()
    backtrack           = true
    max_bt_steps        = typemax(Int64)
    backtrack_sorting   = true
    keep_logs           = false

    return SolverOptions(backtrack, max_bt_steps, backtrack_sorting, keep_logs)
end

function combine_options(options)
    defaults = get_default_options()
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