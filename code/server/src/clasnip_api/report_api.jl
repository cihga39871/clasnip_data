"""
# request data
    token: nothing or string
    username: nothing or string
    queryString: format: 000000000000000//12345678-90ab-cdef-1234-567890abcdef.database_name
"""
function api_report_query(request)
    data = try
        get_request_data!(request) |> JSON.parse
    catch
        return json_response(request, 400)
    end

    # query_string = "670851427623522//142d3825-54da-56b4-a552-047f0434b3fa.Candidatus_Liberibacter_solanacearum" job_id//job_name
    query_string = get(data, "queryString", nothing)
    isnothing(query_string) && (return json_response(request, 400))

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

    job_name = "" # 142d3825-54da-56b4-a552-047f0434b3fa.Candidatus_Liberibacter_solanacearum
    job_name_match = match(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\..*", query_string)
    if !isnothing(job_name_match)
        job_name = job_name_match.match
    end

    job_info = "null"  # json string
    job_id_match = match(r"^[0-9]{12,}", query_string)
    job = nothing
    if !isnothing(job_id_match)
        job_id = parse(Int64, job_id_match.match)
        job = job_query(job_id)
        if !isnothing(job)

            if job_name == ""
                job_name = job.name
            elseif job_name != job.name
                # invalid job
                return json_response(request, 462)
            end
        end
    end
    job_name == "" && (return json_response(request, 462))

    # if this is a Main DB Build job, special things need to be done:
    # Result of Main DB Build is a Job. If Main DB Build is not done, return the state of it. Else, we need to find whether the state of the job.
    if occursin(r"^Main DB Build", job_name)
        res = Dict{String, Any}()
        res["job"] = "___job_info___"  # will be replaced to real job_info at last
        # conver to json str
        res["log"] = nothing
        res["seq"] = nothing
        res["classificationResult"] = nothing
        res["mlstTable"] = nothing

        if job.state == DONE && result(job) isa Job
            new_job = result(job)
            job_info = json(new_job)
            # change state to running if queuing
            job_info = replace(job_info, "\"state\":\"queuing\"" => "\"state\":\"running\"")
        else
            job_info = json(job)
        end

        data = replace(json(res), "\"___job_info___\"" => job_info)
        return json_response(request, 200, data=data)
    else
        job_info = json(job)
    end

    # analysis dir check
    seq_uuid, database = split(job_name, "."; limit=2)
    analysis_dir = joinpath(Config.ANALYSIS_DIR, seq_uuid, "analysis", database)
    isdir(analysis_dir) || (return json_response(request, 462))

    # permission check
    public_owner_file = joinpath(analysis_dir, "owner.<public>")
    if !isfile(public_owner_file)
        # not public analysis
        owner_file = joinpath(analysis_dir, "owner.$owner")
        # user has no permission
        isfile(owner_file) || (return json_response(request, 462))
    end

    # list files
    res = Dict{String, Any}()
    res["job"] = "___job_info___"  # will be replaced to real job_info at last

    fs = readdir(analysis_dir)
    res["log"] = file_locate("log.txt", analysis_dir, fs)
    res["seq"] = file_locate("seq.fasta", analysis_dir, fs)
    res["classificationResult"] = file_locate("seq.fasta.fq.bam.all.vcf.mlst.classification_result.txt", analysis_dir, fs)
    res["mlstTable"] = file_locate("seq.fasta.fq.bam.all.vcf.mlst.partial.txt", analysis_dir, fs)

    # conver to json str
    data = replace(json(res), "\"___job_info___\"" => job_info)
    return json_response(request, 200, data=data)
end
