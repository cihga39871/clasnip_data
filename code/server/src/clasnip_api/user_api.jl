struct FileStat
    name::String
    time::DateTime
end
FileStat(f::AbstractString) = FileStat(f, Dates.unix2datetime(mtime(f)))
FileStat(f::AbstractString, t::Float64) = FileStat(f, Dates.unix2datetime(t))

function api_user_dir_list(request; list_dir="analysis")
    data = try
        get_request_data!(request) |> JSON.parse
    catch
        return json_response(request, 400)
    end

    username = get(data, "username", nothing)
    # isnothing(username) && (return json_response(request, 459))

    user_dir = joinpath(Config.USER_DIR, username, list_dir)
    isdir(user_dir) || (return json_response(request, data=[]))

    dir_contents = readdir(user_dir, join=true)
    file_stats = [FileStat(basename(f), mtime(f)) for f in dir_contents]
    sort!(file_stats, rev = true, by = f -> f.time)

    return json_response(request, data=file_stats)
end

"""
# Request data in json format
 - `dbName`
"""
function api_rm_clasnip_database(request)
    data = try
        get_request_data!(request) |> JSON.parse
    catch
        return json_response(request, 400)
    end

    username = get(data, "username", nothing)
    db_name = get(data, "dbName", nothing)
    isnothing(db_name) && (return json_response(request, 400))

    db_info = get(CLASNIP_DB_INFO, db_name, nothing)
    isnothing(db_info) && (return json_response(request, 400))

    db_owner = get(db_info, "owner", "")
    db_owner == username || (return json_response(request, 401))

    # genome dir has to be in Config.DB_DIR
    db_vcf = get(db_info, "dbVcfReduced", nothing)
    isnothing(db_vcf) && (return json_response(request, 400))
    occursin(Regex("^" * Config.DB_DIR), db_vcf) || (return json_response(request, 403))

    db_path = dirname(db_vcf)

    # check user database dir
    db_link = joinpath(Config.USER_DIR, username, "database", basename(db_path) * ".json")
    # islink(db_link) || (return json_response(request, 401))

    ### cleaning
    delete_clasnip_db_info(db_name)

    # clean sensitive data for new_analysis_api
    db_desensitization()

    # free memory if the database vcf is loaded
    ClasnipPipeline.clasnip_unload_database(db_vcf)

    # change to an existing directory. It is necessary because sometimes pwd() throw an error when current directory is not exist when deleted a failed database dir, but still in this directory.
    cd(Config.PROJECT_ROOT_FOLDER)

    rm(db_link, force=true)
    rm(db_path, force=true, recursive=true)

    return json_response(request)
end
