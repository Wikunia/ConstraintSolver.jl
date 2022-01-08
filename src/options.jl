function get_auto_traverse_strategy(com::CS.CoM)
    return com.sense == MOI.FEASIBILITY_SENSE ? :DFS : :BFS
end

function get_traverse_strategy(com; options = SolverOptions())
    if options.traverse_strategy == :DBFS
        return isempty(com.solutions) ? Val(:DFS) : Val(:BFS)
    end
    return Val(options.traverse_strategy)
end

function get_auto_branch_strategy(com::CS.CoM)
    return :IMPS # Infeasible and Minimum Possiblity Search
end

function get_branch_strategy(; options = SolverOptions())
    strategy = options.branch_strategy
    return Val(strategy)
end

function get_branch_split(; options = SolverOptions())
    strategy = options.branch_split
    return Val(strategy)
end

const POSSIBLE_OPTIONS = Dict(
    :traverse_strategy => [:Auto, :BFS, :DFS, :DBFS],
    :branch_strategy => [:Auto, :ABS, :IMPS],
    :branch_split => [:Auto, :Smallest, :Biggest, :InHalf],
)

function SolverOptions()
    logging = [:Info, :Table]

    table = init_log_table(
            (id=:open_nodes, name="#Open", width=10),
            (id=:closed_nodes, name="#Closed", width=10),
            (id=:incumbent, name="Incumbent", width=20),
            (id=:best_bound, name="Best Bound", width=20),
            (id=:duration, name="Time [s]", width=10);
            alignment=:center
    )
    seed = 1
    traverse_strategy = :Auto
    branch_strategy = :Auto
    branch_split = :Auto
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
    no_prune = false
    decay = 0.999
    max_probes = 10
    max_confidence_deviation = 20
    simplify = true

    return SolverOptions(
        logging,
        table,
        time_limit,
        seed,
        traverse_strategy,
        branch_strategy,
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
        lp_optimizer,
        no_prune,
        ActivityOptions(decay, max_probes, max_confidence_deviation),
        simplify,
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
