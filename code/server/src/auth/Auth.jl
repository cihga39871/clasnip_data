module Auth

using Dates, Random
using Mux, HttpCommon, JSON
using SQLite, Tables, DataFrames, SHA

using ..ClasnipMux
using ..ClasnipPipeline
using ..JobSchedulers
using ..Pipelines
using ..Config
# using ..Init
using ..Utils

include("init_database.jl")

include("tokens.jl")
export Token, update_time_last_token_clear,
generate_token, authorize_token, has_token, is_token_valid, destory_token, clean_old_tokens, validate_null

include("auth_api.jl")
export api_get_token, api_login, api_register, api_logout, api_validate_token, api_validate_token_header

end
