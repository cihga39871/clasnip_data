

function api_check_database_name(request)
    data = try
        get_request_data!(request) |> JSON.parse
    catch
        return json_response(request, 400)
    end

    db_name = trim_blank(get(data, "dbName", nothing))

    # create database folder
    db_name_format = format_database_name(db_name)

    # check whether name is valid
    code = check_database_name(db_name_format)
    code != 200 && (return json_response(request, code))

    db_server_path = no_repeat_path(joinpath(Config.DB_DIR, db_name_format))

    mkpath(db_server_path, mode=0o750)
    json_response(request, code, data = Dict("dbServerPath" => basename(db_server_path)))
end

function format_database_name(db_name::AbstractString)
    replace(db_name, r"[^A-Za-z0-9]+" => "_")
end

function check_database_name(db_name_format::AbstractString)
    length(db_name_format) > 100 && (return 471) # value too long
    occursin(Config.VALIDATION_RULE_GENERAL, db_name_format) || (return 456) # invalid input
    # NOTE: replace special chars are important to avoid directory conflict in new analysis
    db_name_format = lowercase(db_name_format)
    existing_db_names = keys(CLASNIP_DB_INFO)
    for i in existing_db_names
        i_format = lowercase(replace(i, r"[^A-Za-z0-9]+" => "_"))
        if db_name_format == i_format
            return 467
        elseif StringDistances.Levenshtein()(db_name_format, i_format) < Config.DATABASE_NAME_DISTANCE
            return 475 # Name Similar to Existing Ones
        end
    end
    return 200
end
check_database_name(db_name::Nothing) = 400

"""
    api_upload_database(request)

# Headers

- `token` and `username`: for authentication. Auth fail: 440.
- `refGenome`: file name of reference genome. Missing: 400.

# Data

- multiparts

# Return data

- json of Vector[DbFasta].

    struct of DbFasta
        valid::Bool
        filepath::String
        group::String
        basename::String
    end
"""
function api_upload_database(request)
    # owner check
    owner = "<public>"
    token_str = get(request[:headers], "token", "null")
    username = get(request[:headers], "username", "null")
    if token_str != "null" && username != "null"
        owner = username
        # if is_token_valid(token_str, username)
        #     owner = username
        # else
        #     return json_response(request, 440, logging_body=false)
        # end
    end
    # change to an existing directory. It is necessary because sometimes pwd() throw an error when current directory is not exist when deleted a failed database dir, but still in this directory.
    cd(Config.PROJECT_ROOT_FOLDER)

    # check db name on server
    db_name = trim_blank(get(request[:headers], "dbName", nothing))
    db_name_format = format_database_name(db_name)
    db_name_code = check_database_name(db_name_format)

    if db_name_code != 200
        return json_response(request, db_name_code, logging_body=false)
    end

    db_server_path = get(request[:headers], "dbServerPath", "") # basename
    if db_server_path == "" || occursin(r"[^A-Za-z0-9\-\_]", db_server_path)
        return json_response(request, 400, logging_body=false)
    end
    db_path = joinpath(Config.DB_DIR, db_server_path) # full path
    if !isdir(db_path)
        return json_response(request, 400, logging_body=false)
    elseif is_valid_clasnip_database(db_path)  # database occupired
        return json_response(request, 467, logging_body=false)
    end

    # parse boundary from Content-Type
    content_type = get(request[:headers], "Content-Type", "null")
    m = match(r"multipart/form-data; boundary=(.*)$", content_type)
    m === nothing && (return json_response(request, 400, logging_body=false))

    boundary_delimiter = m[1]
    # [RFC2046 5.1.1](https://tools.ietf.org/html/rfc2046#section-5.1.1)
    # length(boundary_delimiter) > 70 && error("boundary delimiter must not be greater than 70 characters")
    parts = HTTP.MultiPartParsing.parse_multipart_body(request[:data], boundary_delimiter)
    length(parts) != 1 && (return json_response(request, 400, logging_body=false))

    ## prepare download

    prefix, ext = splitext(parts[1].filename)
    if occursin(r".tar$"i, prefix)
        ext = ".tar" * ext
    end
    if !is_acceptable_compression_ext(ext)
        return json_response(request, 469, logging_body=false)
    end
    downloaded_file = joinpath(db_path, "download$ext")
    save_successful = multipart_save(downloaded_file, parts)

    if !save_successful
        return json_response(request, 468, logging_body=false)  # Upload Failed
    end

    # decompress
    decompress_to = joinpath(db_path, "extracted")
    rm(decompress_to, force=true, recursive=true)
    mkpath(decompress_to, mode=0o750)
    decompress(downloaded_file, outdir=decompress_to, force=true, as_file=false)

    # check fasta
    fas = scan_database_fasta(decompress_to)
    code_fas = code_database_fasta(fas)
    if code_fas != 200
        # remove files under db_path, not the folder itself
        rm.(readdir(db_path, join=true), force=true, recursive=true)
        return json_response(request, code_fas, logging_body=false)
    end

    # owner file in dir
    owner_file = joinpath(db_path, "owner.$owner")
    touch(owner_file)

    return json_response(request, 200, logging_body=false, data=fas)

end

function multipart_save(dest::String, parts::Vector{HTTP.Multipart})
    # Save the file in the temp directory
    length(parts) != 1 && (return false)
    try
        @info "Saving $(parts[1].filename) to $dest"
        write(dest, take!(parts[1].data))
        return true
    catch e
        rethrow(e)
        return false
    end
end

function no_repeat_path(path::AbstractString)
    if ispath(path)
        n = 0
        while ispath("$(path)_$n")
            n += 1
        end
        return "$(path)_$n"
    else
        return path
    end
end

function api_rm_draft_database(request)
    data = try
        get_request_data!(request) |> JSON.parse
    catch
        return json_response(request, 400)
    end

    db_server_path = get(data, "dbServerPath", "") # basename
    if db_server_path == "" || occursin(r"[^A-Za-z0-9\-\_]", db_server_path)
        return json_response(request, 400)
    end
    db_path = joinpath(Config.DB_DIR, db_server_path) # full path
    if !isdir(db_path)
        return json_response(request, 400)
    end

    # check whether the database is complete
    if is_valid_clasnip_database(db_path)
        return json_response(request, 406)
    else
        # change to an existing directory. It is necessary because sometimes pwd() throw an error when current directory is not exist when deleted a failed database dir, but still in this directory.
        cd(Config.PROJECT_ROOT_FOLDER)

        rm(db_path, force=true,  recursive=true)
        return json_response(request, 200)
    end
end

function is_valid_clasnip_database(database_dir)
    fs = readdir(database_dir)
    has_database_vcf = false
    for f in fs
        if occursin(r"\.db-vcf\.reduced\.jld2$", f)
            has_database_vcf = true
            break
        end
    end
    has_database_vcf
end

function is_acceptable_compression_ext(filepath::AbstractString)
    occursin(r"\.(gz|zip|xz|z|bz2|tar)$"i, filepath)
end

struct DbFasta
    valid::Bool
    filepath::String
    group::String
    basename::String
end
function DbFasta(filepath; hided_dirpath::String="")
    fp = length(hided_dirpath) == 0 ? filepath :
        replace(filepath, hided_dirpath => "")
    group = basename(dirname(fp))
    valid = group == "" ? false : is_valid_fasta(filepath)
    DbFasta(
        valid,
        fp,
        group,
        basename(fp)
    )
end

function scan_database_fasta(dirpath; hide_prefix::Bool=true)
    fs = Vector{DbFasta}()
    hide_arg = hide_prefix ? dirpath : ""
    for (root, dirs, files) in walkdir(dirpath)
        for file in files
            filepath = joinpath(root, file)
            push!(fs, DbFasta(filepath; hided_dirpath=hide_arg))
        end
    end
    fs
end

function is_valid_fasta(filepath)
    base, ext = splitext(filepath)
    occursin(r"fa|fasta|fs"i, ext) || (return false)
    isfile(filepath) || (return false)
    io = open(filepath, "r")
    valid = true
    while !eof(io)
        line = readline(io)
        length(line) == 0 && continue
        if line[1] == '>'
            continue
        else
            if occursin(r"^[ACGTUWSMKRYBDHVNZ acgtuwsmkrybdhvnz]+$", line)
                continue
            else
                valid = false
                break
            end
        end
    end
    close(io)
    return valid
end


function code_database_fasta(fas::Vector{DbFasta})
    valid_fas = filter(x -> x.valid, fas)
    groups = Set{String}()
    for x in valid_fas
        union!(groups, (x.group,))
    end
    length(groups) >= 2 ? 200 : 470  # Only One Group in Database
end

### create db
"""
    api_create_database(request)

# Data in json format

- `token`: localStorage.getItem('token'),
- `username`: localStorage.getItem('username'),
- `dbName`: database name. Error code see `?check_database_name`.
- `dbServerPath`: database path on server. Has clasinp database 467. Not created 400. Missing 400.
- `dbType`: one of genomic, multiple genes, single gene. Invalid and missing 400.
- `refGenome`: reference genome for the database. Invalid or missing 400.
- `region`: database region. eg: "genomic", "16s RNA", "multiple genes". Missing: 400. Invalid: 456.
- `taxonomyRank`: one of "strain", "species", "genus". Invalid and missing 400.
- `taxonomyName`: Missing: 400. Invalid: 456.

"""
function api_create_database(request)
    data = try
        get_request_data!(request) |> JSON.parse
    catch
        return json_response(request, 400)
    end

    # change to an existing directory. It is necessary because sometimes pwd() throw an error when current directory is not exist when deleted a failed database dir, but still in this directory.
    cd(Config.PROJECT_ROOT_FOLDER)

    # owner check
    owner = "<public>"
    token_str = get(data, "token", nothing)
    username = get(data, "username", nothing)
    # if !isnothing(token_str) && !isnothing(username)
    if !isnothing(token_str) && !isnothing(username)
        owner = username
        # if is_token_valid(token_str, username)
        #     owner = username
        # else
        #     return json_response(request, 440)
        # end
    end

    # variables
    db_name = trim_blank(get(data, "dbName", nothing))
    db_server_path = get(data, "dbServerPath", "")
    db_path = joinpath(Config.DB_DIR, db_server_path)
    ref_genome_dict = get(data, "refGenome", Dict())
    ref_genome = get(ref_genome_dict, "filepath", "")
    db_type = get(data, "dbType", "")
    region = get(data, "region", "")
    taxonomy_rank = get(data, "taxonomyRank", "")
    taxonomy_name = get(data, "taxonomyName", "")
    date = replace(string(now()), r"T.*" => "") # 2022-03-28


    # variable validation
    db_name_format = format_database_name(db_name)
    db_name_code = check_database_name(db_name_format)
    if db_name_code != 200
        return json_response(request, db_name_code)
    end

    if db_server_path == "" || occursin(r"[^A-Za-z0-9\-\_]", db_server_path)
        return json_response(request, 400)
    end

    if !isdir(db_path)
        return json_response(request, 400)
    elseif is_valid_clasnip_database(db_path)  # database occupired
        return json_response(request, 467)
    end

    decompress_to = joinpath(db_path, "extracted")
    ref_origin = decompress_to * ref_genome
    if !isfile(ref_origin)
        return json_response(request, 400)
    end

    if !(db_type in ["genomic", "multiple genes", "single gene"])
        return json_response(request, 400)
    end
    do_cross_validation = db_type == "single gene"

    if region == "" || occursin(r"[^A-Za-z0-9\-\_ \(\)]", region)
        return json_response(request, 400)
    end

    if !(taxonomy_rank in ["strain", "species", "genus"])
        return json_response(request, 400)
    end

    if taxonomy_name == "" || occursin(r"[^A-Za-z0-9\-\_ \(\)]", taxonomy_name)
        return json_response(request, 400)
    end

    # check fasta
    fas = ClasnipApi.scan_database_fasta(decompress_to; hide_prefix=false)
    filter!(x -> x.valid, fas)
    code_fas = ClasnipApi.code_database_fasta(fas)
    if code_fas != 200
        # change to an existing directory. It is necessary because sometimes pwd() throw an error when current directory is not exist when deleted a failed database dir, but still in this directory.
        cd(Config.PROJECT_ROOT_FOLDER)

        # remove files under db_path, not the folder itself
        rm.(readdir(db_path, join=true), force=true, recursive=true)
        return json_response(request, code_fas)
    end

    # finish checking

    # prepare arguments
    fastas = [f.filepath for f in fas]
    labels = [f.group * "/" * f.basename for f in fas]
    db_prefix = joinpath(db_path, "database.jl-v$VERSION.db-vcf")

    # build bowtie2 ref
    ref = joinpath(db_path, basename(ref_origin))
    cp(ref_origin, ref, force=true, follow_symlinks=true)
    run(`samtools faidx $ref`) # cannot use gzip/bgzip, freebayes not compatible
    build_bowtie2_index(ref)

    # submit job

    db_build_job = Job(; name = "Main DB Build: $db_name", user = owner) do
        db_wrapper_job = clasnip_db_build(fastas, labels, ref, db_prefix, working_dir = db_path, user = owner, do_cross_validation = do_cross_validation)

        while db_wrapper_job.state in (QUEUING, RUNNING)
            sleep(2)
        end

        if db_wrapper_job.state == DONE
            last_job = try
                result(db_wrapper_job)[2]["CV_SUMMARY_JOB"]
            catch
                db_wrapper_job
            end
            register_job = Job(
                @task(register_database(db_name, db_path, db_prefix, ref, fas, owner, db_type, region, taxonomy_rank, taxonomy_name, date)),
                name = "Register Database: $db_name",
                user = owner,
                dependency = [DONE => last_job.id]
            )
            submit!(register_job)
            return register_job
        else
            @error "Main DB Build Failed: $db_name"
            return db_wrapper_job
        end
    end
    submit!(db_build_job)



    # if create failed, clean by using update_database()
    # job_clean_failed = Job(
    #     @task(rm(db_path, force=true,  recursive=true)),
    #     name = "Clean Failed Database: $db_path",
    #     user = owner,
    #     dependency = [CANCELLED => job.id]
    # )
    # submit!(job_clean_failed)

    return json_response(request, 200, data = Dict(
        "jobID" => db_build_job.id
    ))
end

function register_database(db_name, db_path, db_prefix, ref, fas, owner, db_type, region, taxonomy_rank, taxonomy_name, date)

    # get db accuracy
    @load joinpath(db_path, "stat.identity_distributions.jld2") db_accuracy

    # db json file
    db_info = Dict{String,Dict{String,Any}}(
        db_name => Dict{String,Any}(
            "refGenome" => ref,
            "dbAccuracy" => db_accuracy,
            "dbVcfReduced" => db_prefix * ".reduced.jld2",
            "groups" => count_groups(fas),
            "owner" => owner,
            "dbType" => db_type,
            "region" => region,
            "taxonomyRank" => taxonomy_rank,
            "taxonomyName" => taxonomy_name,
            "date" => date
        )
    )
    db_info_file = joinpath(db_path, "db_info.json")
    open(db_info_file, "w+") do io
        JSON.print(io, db_info, 4)
    end

    # link to owner
    user_db_dir = joinpath(Config.USER_DIR, owner, "database")
    mkpath(user_db_dir, mode=0o750)
    link_to = joinpath(user_db_dir, basename(db_path) * ".json")
    rm(link_to, force=true)
    symlink(db_info_file, link_to)

    # add to config db
    add_clasnip_db_info(db_info)

    # sensitive data clean for new_analysis_api
    db_desensitization()

    # remove tmp
    if Config.CLEAN_TMP_FILES
        ClasnipApi.remove_database_tmpfiles(db_path)
    end
end

function count_groups(fas::Vector{ClasnipApi.DbFasta})
    groups = Dict{String, Int}()
    for f in fas
        f.valid || continue
        if haskey(groups, f.group)
            groups[f.group] += 1
        else
            groups[f.group] = 1
        end
    end
    groups
end

function remove_database_tmpfiles(db_path)
    to_rm = [
        "database.jl-v$VERSION.db-vcf",
        "database.jl-v$VERSION.db-vcf.jld2",
        "extracted",
        "database.jl-v$VERSION.db-vcf.cross-validation.1.analysis-AB",
        "database.jl-v$VERSION.db-vcf.cross-validation.1.analysis-BA",
        "database.jl-v$VERSION.db-vcf.cross-validation.2.analysis-AB",
        "database.jl-v$VERSION.db-vcf.cross-validation.2.analysis-BA",
        "database.jl-v$VERSION.db-vcf.cross-validation.3.analysis-AB",
        "database.jl-v$VERSION.db-vcf.cross-validation.3.analysis-BA"
    ]
    # change to an existing directory. It is necessary because sometimes pwd() throw an error when current directory is not exist when deleted a failed database dir, but still in this directory.
    cd(Config.PROJECT_ROOT_FOLDER)

    for i in to_rm
        rm(joinpath(db_path, i), force=true, recursive=true)
    end

    # delete id files starts with .
    fs = readdir(db_path)
    for i in fs
        if i[1] == '.'
            rm(joinpath(db_path, i), force=true, recursive=true)
        end
    end
end
