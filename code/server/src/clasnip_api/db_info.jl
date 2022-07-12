const CLASNIP_DB_INFO = Dict{String,Any}()

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
    for (name, info) in db_info
        if is_valid_clasnip_db_info(info)
            if haskey(CLASNIP_DB_INFO, name)
                @warn "Clasnip database reload for same name: $name" info
            end
            CLASNIP_DB_INFO[name] = info
        else
            @warn "Fail to add a new clasnip database: database invalid: $name" info
        end
    end
    merge!(CLASNIP_DB_INFO, db_info)
end
function add_clasnip_db_info(json_path::String)
    @info "add_clasnip_db_info: $json_path"
    add_clasnip_db_info(JSON.parsefile(json_path))
end

function delete_clasnip_db_info(db_name::String)
    global CLASNIP_DB_INFO
    if haskey(CLASNIP_DB_INFO, db_name)
        delete!(CLASNIP_DB_INFO, db_name)
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
            rm_invalid && rm(p, force=true, recursive=true)
            continue
        end

        add_clasnip_db_info(db_info_file)
    end
end
