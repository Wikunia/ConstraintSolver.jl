function Base.getindex(
    tr::TableResidues,
    com::ConstraintSolverModel,
    vidx::Int,
    local_vidx::Int,
    val::Int,
)
    val_idx = com.search_space[vidx].init_val_to_index[val + com.search_space[vidx].offset]
    index_shift = tr.var_start[local_vidx] - 1 + val_idx
    return tr.values[index_shift]
end

function Base.setindex!(
    tr::TableResidues,
    residue::Int,
    com::ConstraintSolverModel,
    vidx::Int,
    local_vidx::Int,
    val::Int,
)
    val_idx = com.search_space[vidx].init_val_to_index[val + com.search_space[vidx].offset]
    index_shift = tr.var_start[local_vidx] - 1 + val_idx
    tr.values[index_shift] = residue
end
