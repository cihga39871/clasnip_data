

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
        new_dict["date"] = get(dict, "date", "0000-00-00")

        db[name] = new_dict
    end
    db_sorted = clasnip_db_sort(db)
    global desensitized_db_info = json(db_sorted)
end

function api_get_database(request)
    json_response(request, 200, data = desensitized_db_info)
end

"""
## Keys of request[:data] (If authed)

    database: "Candidatus Liberibacter solanacearum"
    email: "jiacheng_chuan@outlook.com"
    sequences: "ACACTGACTGTCGATGACAC"
    token: "QpjWHvAG8E1hcHcfJEC4CmMgoTOD7kKP4cYdOccIC1xBkzwxoAQV1YTj1wh"
    username: "root"

## Keys of request[:data] (If not authed)

    database: "Candidatus Liberibacter solanacearum"
    email: nothing
    sequences: ">abc\nACATGCAGTGCTAGTCA"
    token: nothing
    username: nothing
"""
function api_new_analysis(request)
    data = try
        get_request_data!(request) |> JSON.parse
    catch
        return json_response(request, 400)
    end

    database = get(data, "database", "")
    haskey(CLASNIP_DB_INFO, database) || (return json_response(request, 440))

    # if token not valid, return 440
    owner = "<public>"
    token_str = get(data, "token", nothing)
    username = get(data, "username", nothing)
    if !isnothing(token_str) && !isnothing(username)
        if is_token_valid(token_str, username)
            owner = username
        else
            return json_response(request, 440)
        end
    end

    # sequences check and save
    raw_sequences = get(data, "sequences", nothing)
    length(raw_sequences) > Config.FASTQ_MAX_SIZE && (return json_response(request, 476))
    isnothing(raw_sequences) && (return json_response(request, 400))

    seq_paths = save_sequence(raw_sequences)
    isnothing(seq_paths) && (return json_response(request, 465))

    # analysis dir
    seq_uuid5, seq_dir, seq_file = seq_paths
    db_name_format = replace(database, r"[^A-Za-z0-9\-\_]" => "_")
    analysis_dir = joinpath(seq_dir, "analysis", db_name_format)
    mkpath(analysis_dir, mode=0o750)

    # link seq to analysis dir
    link_seq_file = joinpath(analysis_dir, "seq.fasta")
    if !isfile(link_seq_file)
        symlink(joinpath("..", "..", basename(seq_file)), link_seq_file)
    end


    # owner file in analysis dir
    owner_file = joinpath(analysis_dir, "owner.$owner")
    touch(owner_file)

    # owner analyses
    job_name = "$seq_uuid5.$db_name_format"
    owner_folder = joinpath(Config.USER_DIR, owner, "analysis")
    mkpath(owner_folder; mode=0o750)
    link_analysis_dir = joinpath(owner_folder, job_name)
    if !islink(link_analysis_dir)
        # change to an existing directory. It is necessary because sometimes pwd() throw an error when current directory is not exist when deleted a failed database dir, but still in this directory.
        cd(Config.PROJECT_ROOT_FOLDER)
        rm(link_analysis_dir, force=true)
        symlink(relpath(analysis_dir, owner_folder), link_analysis_dir)
    end

    task = @task begin
        # cd(analysis_dir)
        #TODO: multiple people do the same job?

        done_marker_path = joinpath(analysis_dir, ".clasnip")
        mlst_path = joinpath(analysis_dir, "seq.fasta.fq.bam.all.vcf.mlst.partial.txt")
        classification_res_path = joinpath(analysis_dir, "seq.fasta.fq.bam.all.vcf.mlst.classification_result.txt")

        # check done before
        isfile(done_marker_path) && isfile(mlst_path) && isfile(classification_res_path) && return

        # do classify
        reference_genome = CLASNIP_DB_INFO[database]["refGenome"]
        db_vcf = CLASNIP_DB_INFO[database]["dbVcfReduced"]
        res = ClasnipPipeline.clasnip_classify(
            joinpath(analysis_dir, "seq.fasta"), reference_genome, db_vcf,
            clean = Config.CLEAN_TMP_FILES, log_file = joinpath(analysis_dir, "log.txt")
        )

        if isfile(mlst_path) && isfile(classification_res_path)
            touch(done_marker_path)
            return nothing
        else
            # job failed
            error("Clasnip Classification Failed: No Outputs.")
        end
    end
    job = Job(task,
        name = job_name,
        user = owner,
        priority = owner == "<public>" ? 50 : 19,
        ncpu = 1,
        wall_time = Hour(1)
    )
    submit!(job)

    return json_response(request, 200, data = Dict(
        "jobID" => job.id,
        "jobName" => job.name
    ))
end

function save_sequence(seq::AbstractString)
    global UUID4
    raw_bases = String[]
    headers = String[]
    is_header = false
    for line in split(seq, r"\r|\n")
        length(line) == 0 && continue
        if line[1] == '>'
            is_header && (return nothing)
            is_header = true
            length(raw_bases) == length(headers) || (return nothing)
            push!(headers, line)
            push!(raw_bases, "")
            continue
        else
            is_header = false
            occursin(r"^[ACTGNWSMKRYBDHV]+ *$"i, line) || (return nothing)
            if length(raw_bases) == 0
                push!(raw_bases, line)
            else
                raw_bases[end] *= line
            end
        end
    end
    perm = sortperm(raw_bases)
    raw_bases = raw_bases[perm]
    cat_bases = join(raw_bases, ",")
    length(cat_bases) == 0 && (return nothing)

    seq_uuid5 = string(UUIDs.uuid5(UUID4, cat_bases))

    if isempty(headers)  # seq is raw seq, not fasta
        push!(headers, ">$seq_uuid5")
    end
    headers = headers[perm]

    seq_dir = joinpath(Config.ANALYSIS_DIR, seq_uuid5)
    seq_file = joinpath(seq_dir, "seq.$seq_uuid5.fasta")
    if isdir(seq_dir) && isfile(seq_file)
        return seq_uuid5, seq_dir, seq_file
    end

    mkpath(seq_dir, mode=0o750)

    seq_io = open(seq_file, "w+")
    nseq = length(raw_bases)
    for i = 1:nseq
        println(seq_io, headers[i])
        println(seq_io, raw_bases[i])
    end
    close(seq_io)

    return seq_uuid5, seq_dir, seq_file
end
