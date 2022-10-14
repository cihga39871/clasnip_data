const CLASNIP_DB_INFO = Dict{String,Any}()
const CLASNIP_FORMATED_DB_NAME = Dict{String,String}()

function is_valid_clasnip_db_info(db_info::Dict)
    db_vcf_file = get(db_info, "dbVcfReduced", "")
    db_vcf_file == "" && (return false)

    db_path = dirname(db_vcf_file)

    filesize(db_vcf_file) > 0 &&
    filesize(get(db_info, "refGenome", "")) > 0 &&
    filesize(get(db_info, "refGenome", "") * ".1.bt2") > 0 &&
    filesize(get(db_info, "refGenome", "") * ".2.bt2") > 0 &&
    filesize(get(db_info, "refGenome", "") * ".3.bt2") > 0 &&
    filesize(get(db_info, "refGenome", "") * ".4.bt2") > 0 &&
    filesize(get(db_info, "refGenome", "") * ".fai") > 0 &&
    filesize(get(db_info, "refGenome", "") * ".rev.1.bt2") > 0 &&
    filesize(get(db_info, "refGenome", "") * ".rev.2.bt2") > 0 &&
    filesize(joinpath(db_path, "plot.heatmap_identity.svg")) > 0 &&
    filesize(joinpath(db_path, "stat.accuracy_and_identity.txt")) > 0 &&
    filesize(joinpath(db_path, "stat.heatmap_identity.txt")) > 0 &&
    filesize(joinpath(db_path, "stat.identity_distributions.jld2")) > 0 &&
    isfile(joinpath(db_path, "stat.low_coverages.txt")) &&
    isfile(joinpath(db_path, "stat.wrongly_classified.txt"))
end

function add_clasnip_db_info(db_info::Dict)
    global CLASNIP_DB_INFO
    global CLASNIP_FORMATED_DB_NAME
    for (name, info) in db_info
        if is_valid_clasnip_db_info(info)
            if haskey(CLASNIP_DB_INFO, name)
                @warn "Clasnip database reload for same name: $name"
            end
            CLASNIP_DB_INFO[name] = info
            CLASNIP_FORMATED_DB_NAME[format_database_name(name)] = name
        else
            @warn "Fail to add a new clasnip database: database invalid: $name" info
        end
    end
    db_desensitization()
    # merge!(CLASNIP_DB_INFO, db_info)
end
function add_clasnip_db_info(json_path::String)
    @info "add_clasnip_db_info: $json_path"
    add_clasnip_db_info(JSON.parsefile(json_path))
end

function delete_clasnip_db_info(db_name::String)
    global CLASNIP_DB_INFO
    global CLASNIP_FORMATED_DB_NAME
    db_name_format = format_database_name(db_name)
    if haskey(CLASNIP_FORMATED_DB_NAME, db_name_format)
        delete!(CLASNIP_FORMATED_DB_NAME, db_name_format)
    end
    if haskey(CLASNIP_DB_INFO, db_name)
        delete!(CLASNIP_DB_INFO, db_name)
        db_desensitization()
        return true
    else
        return false
    end
end

function init_clasnip_db_info(; rm_invalid::Bool=false)
    # add clasnip db info in config.
    clasnip_database_json = abspath(@__DIR__, "..", "..", "config", "clasnip_database.json")
    isfile(clasnip_database_json) && add_clasnip_db_info(clasnip_database_json)

    # add other db
    db_paths = readdir(Config.DB_DIR, join=true)

    # change to an existing directory. It is necessary because sometimes pwd() throw an error when current directory is not exist when deleted a failed database dir, but still in this directory.
    cd(Config.PROJECT_ROOT_FOLDER)

    for p in db_paths
        db_info_file = joinpath(p, "db_info.json")

        if !isfile(db_info_file) || filesize(db_info_file) == 0
            # do it only when init!
            if rm_invalid && Config.CLEAN_TMP_FILES
                @info "removing unfinished database: $p"
                rm(p, force=true, recursive=true)
            else
                @warn "unfinished database detected but not removed: $p"
            end
            continue
        end

        add_clasnip_db_info(db_info_file)
    end
end

function clasnip_db_sort(db)
    db = sort(db)
    sort!(db, by = name -> replace(get(db[name], "region", ""), r"^$" => "~")) # ~ is more than z in ASCII
    sort!(db, by = name -> replace(get(db[name], "dbType", ""), r"^$" => "~")) # ~ is more than z in ASCII
    sort!(db, by = name -> replace(get(db[name], "taxonomyName", ""), r"^$" => "~")) # ~ is more than z in ASCII
end

function db_desensitization()
    db = Dict{String,Any}()
    for p in CLASNIP_DB_INFO
        name = p.first
        dict = p.second
        new_dict = Dict{String,Any}()
        new_dict["groups"] = get(dict, "groups", Dict())
        new_dict["refGenome"] = basename(get(dict, "refGenome", "<Not Found>"))
        new_dict["owner"] = get(dict, "owner", "<Unknown>")
        new_dict["dbPath"] = dirname(get(dict, "refGenome", "<Not Found>"))
        new_dict["dbAccuracy"] = get(dict, "dbAccuracy", NaN)
        new_dict["dbType"] = get(dict, "dbType", "")
        new_dict["region"] = get(dict, "region", "")
        new_dict["taxonomyRank"] = get(dict, "taxonomyRank", "")
        new_dict["taxonomyName"] = get(dict, "taxonomyName", "")
        new_dict["groupBy"] = get(dict, "groupBy", "groups")
        new_dict["date"] = get(dict, "date", "0000-00-00")

        db[name] = new_dict
    end
    db_sorted = clasnip_db_sort(db)
    global desensitized_db_info = json(db_sorted)
end

"""
    get_db_info(db_name; formatted::Bool = false)

- `formatted::Bool`: whether `db_name` is formatted using `format_database_name(db_name)`

Return `db_info::Dict` or `nothing`
"""
function get_db_info(db_name; formatted::Bool = false)
    if formatted
        db_name = get(CLASNIP_FORMATED_DB_NAME, db_name, nothing)
        if isnothing(db_name)
            return nothing
        end
    end
    get(CLASNIP_DB_INFO, db_name, nothing)
end

"""
get_user_friendly_db_name(db_name; formatted::Bool = false)

- `formatted::Bool`: whether `db_name` is formatted using `format_database_name(db_name)`

Return `user_friendly_db_name` or `db_name`.
"""
function get_user_friendly_db_name(db_name::AbstractString; formatted::Bool = false)
    db_info = get_db_info(db_name; formatted = formatted)
    isnothing(db_info) && (return db_name)

    tax = get(db_info, "taxonomyName", nothing)
    isnothing(tax) && (return db_name)

    region = get(db_info, "region", nothing)
    isnothing(region) && (return db_name)

    if formatted
        db_name = get(CLASNIP_FORMATED_DB_NAME, db_name, db_name)
    end

    return "$tax ($region)"
end

function api_get_database(request)
    json_response(request, 200, data = desensitized_db_info)
end