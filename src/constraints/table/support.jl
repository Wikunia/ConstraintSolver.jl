function get_view(ts::TableSupport, com::ConstraintSolverModel, vidx::Int, local_vidx::Int, val::Int)
    val_idx = com.search_space[vidx].init_val_to_index[val+com.search_space[vidx].offset] 
    index_shift = ts.var_start[local_vidx]-1+val_idx
    return @view ts.values[:,index_shift]
end

function Base.getindex(ts::TableSupport, com::ConstraintSolverModel, vidx::Int, local_vidx::Int, val::Int, row_idx::Int)
    val_idx = com.search_space[vidx].init_val_to_index[val+com.search_space[vidx].offset] 
    index_shift = ts.var_start[local_vidx]-1+val_idx
    return ts.values[row_idx,index_shift]
end