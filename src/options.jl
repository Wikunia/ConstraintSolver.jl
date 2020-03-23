mutable struct SolverOptions
    logging::Vector{Symbol}
    table::TableSetup
    time_limit::Float64 # time limit in backtracking in seconds
    backtrack::Bool
    max_bt_steps::Int
    backtrack_sorting::Bool
    keep_logs::Bool
    rtol::Float64
    atol::Float64
    solution_type::Type
    all_solutions::Bool
    all_optimal_solutions::Bool
    lp_optimizer::Any
end

function SolverOptions()
    logging = [:Info, :Table]
    table = TableSetup(
        [
            CS.TableCol(:open_nodes, "#Open", Int, 10, :center),
            CS.TableCol(:closed_nodes, "#Closed", Int, 10, :center),
            CS.TableCol(:incumbent, "Incumbent", Float64, 20, :center),
            CS.TableCol(:best_bound, "Best Bound", Float64, 20, :center),
            CS.TableCol(:duration, "Time [s]", Float64, 10, :center),
        ],
        Dict(:min_diff_duration => 5.0),
    )
    backtrack = true
    max_bt_steps = typemax(Int)
    backtrack_sorting = true
    keep_logs = false
    rtol = 1e-6
    atol = 1e-6
    solution_type = Float64
    all_solutions = false
    all_optimal_solutions = false
    lp_optimizer = nothing
    time_limit = Inf

    return SolverOptions(
        logging,
        table,
        time_limit,
        backtrack,
        max_bt_steps,
        backtrack_sorting,
        keep_logs,
        rtol,
        atol,
        solution_type,
        all_solutions,
        all_optimal_solutions,
        lp_optimizer
    )
end

function combine_options(options)
    defaults = SolverOptions()
    options_dict = Dict{Symbol,Any}()
    for kv in options
        if !in(kv[1], fieldnames(SolverOptions))
            @error "The option " * string(kv[1]) * " doesn't exist."
        else
            options_dict[kv[1]] = kv[2]
        end
    end

    for fname in fieldnames(SolverOptions)
        if haskey(options_dict, fname)
            setfield!(
                defaults,
                fname,
                convert(fieldtype(SolverOptions, fname), options_dict[fname]),
            )
        end
    end
    return defaults
end
