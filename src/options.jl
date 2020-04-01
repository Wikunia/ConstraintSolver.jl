mutable struct SolverOptions
    logging::Vector{Symbol}
    table::TableSetup
    time_limit::Float64 # time limit in backtracking in seconds
    traverse_strategy::Symbol
    branch_split::Symbol # defines splitting in the middle, or takes smallest, biggest value
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

function get_traverse_strategy(;options=SolverOptions())
    strategy = options.traverse_strategy
    if strategy == :BFS
        return TraverseBFS()
    elseif strategy == :DFS
        return TraverseDFS()
    elseif strategy == :DBFS
        return TraverseDBFS()
    end
end

function get_branch_split(;options=SolverOptions())
    strategy = options.branch_split
    return Val(strategy)
end

const POSSIBLE_OPTIONS = Dict(
    :traverse_strategy => [:BFS, :DFS, :DBFS],
    :branch_split => [:Smallest, :Biggest, :InHalf]
)

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
    traverse_strategy = :BFS
    branch_split = :Smallest
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
        traverse_strategy,
        branch_split,
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
            @error "The option $(kv[1]) doesn't exist."
        else
            moi_key = MOI.RawParameter(string(kv[1]))
            if is_possible_option_value(moi_key, kv[2])
                options_dict[kv[1]] = kv[2]
            else
                @error "The option $(kv[1]) doesn't have $(kv[2]) as a possible value. Possible values are: $(POSSIBLE_OPTIONS[moi_key])"
            end
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

function is_possible_option_value(option_param::MOI.RawParameter, value)
    option = Symbol(option_param.name)
    if haskey(POSSIBLE_OPTIONS, option)
        return value in POSSIBLE_OPTIONS[option]
    end
    return true
end