function Base.getindex(tr::TableResidues, com::ConstraintSolverModel, var_idx::Int, local_var_idx::Int,  val::Int)
    val_idx = com.search_space[var_idx].init_val_to_index[val+com.search_space[var_idx].offset] 
    index_shift = tr.var_start[local_var_idx]-1+val_idx
    return tr.values[index_shift]
end

function Base.setindex!(tr::TableResidues, residue::Int, com::ConstraintSolverModel, var_idx::Int, local_var_idx::Int, val::Int)
    val_idx = com.search_space[var_idx].init_val_to_index[val+com.search_space[var_idx].offset] 
    index_shift = tr.var_start[local_var_idx]-1+val_idx
    tr.values[index_shift] = residue
end
