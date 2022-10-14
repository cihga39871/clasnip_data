
"""
# request data
    token: nothing or string
    username: nothing or string
    queryString: format: 00000.11111//12345678-90ab-cdef-1234-567890abcdef.database_name1.database_name2

- `queryString`: job_id1.job_id2...//seq_uuid.database_name1.database_name2...

eg: 3241899211403266.3241899211403266//188e5fd3-8149-5d39-b4b8-8ecf07493196.clso_v5_genomic.clso_v5_16-23s

# return json
    res["jobs"] = Job[]
    res["seq"] = nothing or "path"
    res["logs"] = String[]
    res["classificationResults"] = String[]
    res["mlstTables"] = String[]
    res["classificationFailInfo"] = String[]
"""
function api_multi_report_query(request)
    data = try
        get_request_data!(request) |> JSON.parse
    catch
        return json_response(request, 400)
    end

    query_string = get(data, "queryString", "")
    length(query_string) < 9 && (return json_response(request, 400))

    res = Dict{String, Any}()

    jobs = Job[]
    job_ids = ClasnipApi.get_job_ids(query_string)
    if !isnothing(job_ids)
        for job_id in job_ids
            job = job_query(parse(Int, job_id))
            if !isnothing(job)
                push!(jobs, job)

                # if this is a Main DB Build job, special things need to be done:
                # Result of Main DB Build is a Job. Add this job to jobs
                if occursin(r"^Main DB Build", job.name)
                    if job.state == DONE && result(job) isa Job
                        new_job = result(job)
                        push!(jobs, new_job)
                    end
                end
            end
        end
    end
    res["jobs"] = "___job_info___"

    res["seq"] = nothing
    res["logs"] = String[]
    res["classificationResults"] = String[]
    res["mlstTables"] = String[]
    res["classificationFailInfo"] = String[]

    name_res = ClasnipApi.get_seq_uuid_and_db_names(query_string)
    if !isnothing(name_res)
        seq_uuid, databases = name_res

        for database in databases
            analysis_dir = ClasnipApi.get_analysis_dir(seq_uuid, database)
            isdir(analysis_dir) || (return json_response(request, 462))

            fs = readdir(analysis_dir)
            if isnothing(res["seq"])
                res["seq"] = file_locate("seq.fasta", analysis_dir, fs)
            end

            log_file = file_locate("log.txt", analysis_dir, fs)
            isnothing(log_file) || push!(res["logs"], log_file)

            file = file_locate("seq.fasta.fq.bam.all.vcf.mlst.classification_result.txt", analysis_dir, fs)
            if isnothing(file)
                fail_info_path = file_locate(".clasnip.fail.info", analysis_dir, fs)
                if !isnothing(fail_info_path)
                    db_name_user_friendly = get_user_friendly_db_name(database; formatted=true)
                    fail_info = db_name_user_friendly * ": " * String(read(fail_info_path))
                    push!(res["classificationFailInfo"], fail_info)
                end
            else
                push!(res["classificationResults"], file)
            end

            file = file_locate("seq.fasta.fq.bam.all.vcf.mlst.partial.txt", analysis_dir, fs)
            isnothing(file) || push!(res["mlstTables"], file)
        end
    end

    # check if both are nothing
    if length(jobs) == 0 && isnothing(name_res)
        return json_response(request, 462)
    end

    data = replace(json(res), "\"___job_info___\"" => to_json(jobs))
    return json_response(request, 200, data=data)
end

"""
    api_report_query(request) = api_multi_report_query(request)
"""
api_report_query(request) = api_multi_report_query(request)

function to_json(job::Job)
    """
    {"id":$(job.id),"state":"$(job.state)","name":"$(job.name)","user":"$(job.user)","ncpu":$(job.ncpu),"create_time":"$(job.create_time)","start_time":"$(job.start_time)","stop_time":"$(job.stop_time)","wall_time":"$(job.wall_time)","priority":$(job.priority),"stdout_file":"$(job.stdout_file)","stderr_file":"$(job.stderr_file)"}"""
end
function to_json(jobs::Vector{Job})
    if length(jobs) == 0
        return "[]"
    end
    str = "["
    for (i, job) in enumerate(jobs)
        if i > 1
            str *= ","
        end
        str *= to_json(job)
    end
    str *= "]"
    return str
end


function get_seq_uuid_and_db_names(s::AbstractString)
    m = match(r"([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\.(.*)", s)
    if isnothing(m)
        return nothing
    else
        seq_uuid = m.captures[1]
        dbs_str = m.captures[2]
        if isempty(dbs_str)
            return nothing
        end
        dbs = split(dbs_str, ".", keepempty=false)
        return seq_uuid, dbs
    end
end

function get_job_ids(s::AbstractString)
    m = match(r"^[0-9\.]{8,}", s)
    if isnothing(m)
        return nothing
    else
        job_ids = split(m.match, ".", keepempty=false)
    end
end
