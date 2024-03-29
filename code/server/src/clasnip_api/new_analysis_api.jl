
"""
## Keys of request[:data] (If authed)

    databases: ["db1", "db2"]
    email: "jiacheng_chuan@outlook.com"
    sequences: "ACACTGACTGTCGATGACAC"
    token: "QpjWHvAG8E1hcHcfJEC4CmMgoTOD7kKP4cYdOccIC1xBkzwxoAQV1YTj1wh"
    username: "root"

## Keys of request[:data] (If not authed)

    databases: ["db1", "db2"]
    email: nothing
    sequences: ">abc\nACATGCAGTGCTAGTCA"
    token: nothing
    username: nothing
"""
function api_new_analysis_multi_db(request)
    data = try
        get_request_data!(request) |> JSON.parse
    catch
        return json_response(request, 400)
    end

    databases = get(data, "databases", Any[])
    isempty(databases) && (return json_response(request, 440))
    for database in databases
        haskey(CLASNIP_DB_INFO, database) || (return json_response(request, 440))
    end

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
    
    seq_uuid5, seq_dir, seq_file = seq_paths

    # do analysis for each database
    jobs = Job[]
    db_name_formats = String[]
    for database in databases
        # analysis dir
        db_name_format = format_database_name(database)
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
            fail_info_path = joinpath(analysis_dir, ".clasnip.fail.info")
            mlst_path = joinpath(analysis_dir, "seq.fasta.fq.bam.all.vcf.mlst.partial.txt")
            classification_res_path = joinpath(analysis_dir, "seq.fasta.fq.bam.all.vcf.mlst.classification_result.txt")

            # check done before
            isfile(done_marker_path) && isfile(mlst_path) && isfile(classification_res_path) && return

            isfile(fail_info_path) && return

            # do classify
            reference_genome = CLASNIP_DB_INFO[database]["refGenome"]
            db_vcf = CLASNIP_DB_INFO[database]["dbVcfReduced"]
            res = ClasnipPipeline.clasnip_classify(
                joinpath(analysis_dir, "seq.fasta"), reference_genome, db_vcf,
                clean = Config.CLEAN_TMP_FILES, log_file = joinpath(analysis_dir, "log.txt"), fail_info_path = fail_info_path
            )

            if isfile(mlst_path) && isfile(classification_res_path)
                touch(done_marker_path)
                return
            elseif isfile(fail_info_path)
                return
            else
                # job failed
                error("Clasnip Classification Failed: No Outputs.")
            end
        end
        job = Job(task,
            name = job_name,
            user = owner,
            priority = owner == "<public>" ? 19 : 15,
            ncpu = 1,
            wall_time = Hour(1)
        )
        submit!(job)
        push!(jobs, job)
        push!(db_name_formats, db_name_format)
    end
    
    job_ids = join([job.id for job in jobs], ".")
    job_names = "$seq_uuid5.$(join(db_name_formats, "."))"
    return json_response(request, 200, data = Dict(
        "jobID" => job_ids,
        "jobName" => job_names
    ))
end

"""
    api_new_analysis(request) = api_new_analysis_multi_db(request)
"""
api_new_analysis(request) = api_new_analysis_multi_db(request)

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

    seq_dir = get_seq_dir(seq_uuid5)
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

function get_seq_dir(seq_uuid::String)
    # seq_dir = joinpath(Config.ANALYSIS_DIR, seq_uuid)
    # if isdir(seq_dir)
    #     return seq_dir
    # end
    # new dir
    sub1 = seq_uuid[1:2]
    sub2 = seq_uuid[3:4]
    seq_dir = joinpath(Config.ANALYSIS_DIR, sub1, sub2, seq_uuid)
end

function get_analysis_dir(seq_uuid::AbstractString, db_server_basename::AbstractString)
    # analysis_dir = joinpath(Config.ANALYSIS_DIR, seq_uuid, "analysis", db_server_basename)
    # if isdir(analysis_dir)
    #     return analysis_dir
    # end
    # new dir
    sub1 = seq_uuid[1:2]
    sub2 = seq_uuid[3:4]
    analysis_dir = joinpath(Config.ANALYSIS_DIR, sub1, sub2, seq_uuid, "analysis", db_server_basename)
end