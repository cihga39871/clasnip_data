__precompile__(false)

module ClasnipApi

using Reexport
using Dates, Random, UUIDs
using Mux, HttpCommon, JSON
using SQLite, Tables, DataFrames, CSV, SHA
using StringDistances
using JLD2

using ..ClasnipMux

include(joinpath("..", "clasnip_pipeline", "ClasnipPipeline.jl"))
@reexport using .ClasnipPipeline
@reexport using .ClasnipPipeline.JobSchedulers
@reexport using .ClasnipPipeline.Pipelines

using ..Config
using ..Utils
# using ..Init

include(joinpath("..", "auth", "Auth.jl"))
@reexport using .Auth

using ..DynamicKey

const UUID4 = uuid4(UUIDs.MersenneTwister(9871))

include("utils.jl")
export file_locate

include("db_info.jl")
export is_valid_clasnip_db_info,
add_clasnip_db_info, delete_clasnip_db_info,
init_clasnip_db_info

include("new_analysis_api.jl")
export api_get_database, api_new_analysis

include("report_api.jl")
export api_report_query

include("file_viewer_api.jl")
export api_file_viewer

include("database_api.jl")
export api_check_database_name, api_rm_draft_database, api_upload_database, api_create_database

include("user_api.jl")
export api_user_dir_list, api_rm_clasnip_database

include("server_control.jl")
export api_dynamic_key, api_update_database, api_revise_retry

function __init__()
    init_clasnip_db_info(rm_invalid=true)
    db_desensitization()
end

end
