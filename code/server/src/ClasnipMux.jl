__precompile__(false)

module ClasnipMux

using Reexport
@reexport using Base.Threads
@reexport using Revise
@reexport using Dates, Random, Logging
@reexport using Mux, HttpCommon, JSON, HTTP, MbedTLS, YAML, HTTP.URIs
@reexport using SQLite, Tables, DataFrames, SHA, CSV, DataFramesMeta, StatsBase
@reexport using StringDistances
@reexport using Dates

include("compress.jl")
export decompress

include(joinpath(@__DIR__, "..", "config", "Config.jl"))
@reexport using .Config

include(joinpath(@__DIR__, "dynamic_key", "DynamicKey.jl"))
@reexport using .DynamicKey

include(joinpath("utils", "Utils.jl"))
@reexport using .Utils

# include(joinpath("init", "Init.jl"))
# @reexport using .Init

include("status_messages.jl")
include("communication_standard.jl")
export json_response, response_with_header, get_request_data!, @show_repl

# include(joinpath(ENV["CJCBioTools"], "api", "julia", "clasnip_pipeline", "ClasnipPipeline.jl"))
# @reexport using .ClasnipPipeline
# @reexport using .ClasnipPipeline.JobSchedulers
# @reexport using .ClasnipPipeline.Pipelines



include(joinpath("clasnip_api", "ClasnipApi.jl"))
@reexport using .ClasnipApi
@reexport using .ClasnipApi.ClasnipPipeline.JobSchedulers
@reexport using .ClasnipApi.ClasnipPipeline.Pipelines
@reexport using .ClasnipApi.Auth

# include(joinpath("auth", "Auth.jl"))
# @reexport using .Auth

set_scheduler_update_second(Config.SCHEDULER_UPDATE_SECOND)
set_scheduler_max_cpu(round(Int, Config.SCHEDULER_MAX_CPU - 1))

include("router.jl")
export run_server, stop_server, restart_server

end
