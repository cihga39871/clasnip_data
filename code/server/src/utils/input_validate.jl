function trim_blank(s::AbstractString)
    s = replace(s, r"^ +| +$" => "")
end
trim_blank(s::Nothing) = nothing
