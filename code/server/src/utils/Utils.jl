module Utils

using ..Config

include("input_validate.jl")
export trim_blank

include("database_validate.jl")
export validate

end  # module Utils
