function Base.show(io::IO, csinfo::CSInfo)
    println("Info: ")
    for name in fieldnames(CSInfo)
        println(io, "$name = $(getfield(csinfo, name))")
    end
end

function compress_var_string(variable::CS.Variable)
    if CS.isfixed(variable)
        return string(CS.value(variable))
    end

    sorted_vals = sort(CS.values(variable))
    if sorted_vals[1]+length(CS.values(variable))-1 == sorted_vals[end]
        return "$(sorted_vals[1]):$(sorted_vals[end])"
    end
    return string(sort(CS.values(variable))) 
end

function get_str_repr(variables::Array{CS.Variable})
    if length(size(variables)) == 1
        output = ""
        for i=1:length(variables)
            if !CS.isfixed(variables[i])
                output *= "$(compress_var_string(variables[i])), "
            else
                output *= "$(CS.value(variables[i])), "
            end
        end
        return [output[1:end-2]]
    elseif length(size(variables)) == 2
        max_length = 1
        for j=1:size(variables)[2]
            for i=1:size(variables)[1]
                if !CS.isfixed(variables[i,j])
                    len = length(compress_var_string(variables[i,j]))
                    if len > max_length
                        max_length = len
                    end
                else
                    len = length(string(CS.value(variables[i,j])))
                    if len > max_length
                        max_length = len
                    end
                end
            end
        end
        lines = String[]
        for j=1:size(variables)[2]
            line = ""
            for i=1:size(variables)[1]
                pstr = ""
                if !CS.isfixed(variables[i,j])
                    pstr = compress_var_string(variables[i,j])      
                else 
                    pstr = string(CS.value(variables[i,j]))     
                end
                space_left  = floor(Int, (max_length-length(pstr))/2)
                space_right = ceil(Int, (max_length-length(pstr))/2)
                line *= repeat(" ", space_left)*pstr*repeat(" ", space_right)*" "
            end
            push!(lines, line)
        end
        return lines
    else
        @warn "Currently not supported to print more than 2 dimensions. Maybe file an issue with your problem and desired output"
    end
end

function Base.show(io::IO, variables::Array{CS.Variable})
    lines = get_str_repr(variables)
    for line in lines
        println(line)
    end
end