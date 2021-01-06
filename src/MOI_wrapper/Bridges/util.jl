function operate_vector_affine_function_part(operator, T, func::MOI.VectorAffineFunction, part::Int)
    unchanged_terms = [term for term in func.terms if term.output_index != part]
    unchanged_constants_before = [func.constants[i] for i in 1:part-1]
    unchanged_constants_after = [func.constants[i] for i in part+1:length(func.constants)]

    change_terms = [term for term in func.terms if term.output_index == part]
    change_constnat = func.constants[part]
    change_saf = MOI.ScalarAffineFunction([term.scalar_term for term in change_terms], change_constnat)
    mapped_inner = MOIU.operate(operator, T, change_saf)
    mapped_vaf = MOI.VectorAffineFunction(
        [
            unchanged_terms...,
            [MOI.VectorAffineTerm(part, term) for term in mapped_inner.terms]...
        ],
        [unchanged_constants_before..., mapped_inner.constant, unchanged_constants_after...]
    )
    return mapped_vaf
end
