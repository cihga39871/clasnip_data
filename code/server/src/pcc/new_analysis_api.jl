"""
    api_get_analysis_options(request)

Get new analysis options.

## Request

nothing is required.

## Response

- `200`: data in JSON format, for example:

```json
{
    "analysisProfileOptionDetails": {
        "Default": {
            "analysisProfile": "Default",
            "disableAllowEditProfile": false,
            "allowEditProfile": true,

            "fastqc": true,
            "trimming": true,
            "trimmingMethod": "Atria",
            "trimmingAdapter1": "AGATCGGAAGAGCACACGTCTGAACTCCAGTCA",
            "trimmingAdapter2": "AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT",

            "mapping": false,
            "mappingReference": "",
            "mappingFiltration": false,
            "mappingFiltrationMethod": "",
            "mappingDiscardOriginal": true,

            "assembly": true,
            "assembler": "Velvet",

            "fastaAnalysis": true,
            "fastaANI": true
        }
    },
    "analysisProfileOptions": [
        "Default"
    ],
    "assemblerOptions": {
        "Velvet": "VELVET"
    },
    "cpuLimit": 8,
    "mappingFiltrationMethodOptions": {
        "Use unmapped read pairs": "12-0-0",
        "Use properly mapped read pairs": "2-0-0"
    },
    "mappingReferenceOptions": {
        "Dickeya fangzhongdai Reference Genome (GCA_000758345.1_ASM75834v1)": "/usr/database/processed/polychrome_classifier/genomes/Dickeya/Dickeya_fangzhongdai/representative_assembly/GCA_000758345.1_ASM75834v1_genomic.fasta",
        "Tomato SL4.0 (Sol Genomics Network)": "/usr/database/SolGenomics/ftp.solgenomics.net/tomato_genome/assembly/build_4.00/S_lycopersicum_chromosomes.4.00.fa"
    },
    "maxCpuLimit": 12,
    "maxGenomeDepth": 5,
    "pccDb": "/usr/database/processed/polychrome_classifier",
    "pccGenomesOptions": [
        "ClavibacterNCBI",
        "ClavibacterNCBI/Clavibacter_michiganensis"
    ],
    "resume": true,
    "trimmingMethodOptions": {
        "Atria": "ATRIA"
    }
}
```
"""
function api_get_analysis_options(request)
    data = Dict(
        "pccDb" => Config.PCC_DATABASE,
        "pccGenomesOptions" => PCC_GENOMES,
        "maxGenomeDepth" => Config.MAX_GENOME_DEPTH,
        "analysisProfileOptions" => collect(keys(ANALYSIS_PROFILES)),
        "analysisProfileOptionDetails" => ANALYSIS_PROFILES,
        "trimmingMethodOptions" => Config.TRIMMING_METHOD_OPTIONS,
        "mappingReferenceOptions" => Config.MAPPING_REFERENCE_OPTIONS,
        "mappingFiltrationMethodOptions" => Config.MAPPING_FILTRATION_METHOD_OPTIONS,
        "assemblerOptions" => Config.ASSEMBER_OPTIONS,
        "cpuLimit" => Config.CPU_LIMIT,
        "maxCpuLimit" => Config.MAX_CPU_LIMIT,
        "resume" => Config.RESUME_ANALYSIS
    )
    json_response(request, 200, data = data)
end


"""
    api_submit_job(request;
        search_limit::Regex = Config.FILE_SEARCH_LIMIT_GENERAL,
        log_request::Bool = true
    )

Submit an analysis job.

## Request

- `request[:data]`: for example:

```json
{
    "analysisProfile": "Default",
    "assembler": "Velvet",
    "assembly": true,
    "cpuLimit": 12,
    "fastaANI": true,
    "fastaAnalysis": true,
    "fastqc": true,
    "genomeDepth": 1,
    "inputFasta": [
        "/__PROJECT_ROOT_FOLDER__/root/908C_S6_L001_R1_001.atria.velvet-contigs.fa"
    ],
    "inputR1Fastq": [
        "/__PROJECT_ROOT_FOLDER__/root/CMM3_S1_L001_R1_001.fastq.gz"
    ],
    "inputR2Fastq": [
        "/__PROJECT_ROOT_FOLDER__/root/CMM3_S1_L001_R2_001.fastq.gz"
    ],
    "mapping": false,
    "mappingDiscardOriginal": true,
    "mappingFiltration": false,
    "mappingFiltrationMethod": "",
    "mappingReference": "",
    "pccGenomes": [
        "Dickeya",
        "Dickeya/Dickeya_fangzhongdai"
    ],
    "projectDir": "/__PROJECT_ROOT_FOLDER__/root/web_analysis",
    "resume": true,
    "trimming": true,
    "trimmingAdapter1": "AGATCGGAAGAGCACACGTCTGAACTCCAGTCA",
    "trimmingAdapter2": "AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT",
    "trimmingMethod": "Atria"
}

## Reponse

- `400`: invalid request, such as (1) empty `"projectDir"`, (2) no input files, (3) file counts of `"inputR1Fastq"` and `"inputR2Fastq"` not the same, (4) `"mappingReference"` not the key in `Config.MAPPING_REFERENCE_OPTIONS`

- `458`: any input files out of `search_limit`.

- `461`: `"projectDir"` is rejected by server (no write permission).

- `200`: job successfully submitted. Return data in JSON format: `{"jobID": Int, "jobName": String}`.
```
"""
function api_submit_job(request;
    search_limit::Regex = Config.FILE_SEARCH_LIMIT_GENERAL,
    log_request::Bool = true
)
    #=
    request = Dict{Any,Any}(:query => "",:method => "POST",:params => Dict{Any,Any}(),:path => SubString{String}[],:cookies => HTTP.Cookies.Cookie[],:uri => HTTP.URI("/pcc/submit_job"),:data => "{\"token\":\"iqFeNP1CbjmHBY5eO2qI7Y5FKsHm4jK0QskpizhOjPFLYvuKcM1OMcWMXti3\",\"username\":\"root\",\"projectDir\":\"/__PROJECT_ROOT_FOLDER__/root/web_analysis\",\"inputFasta\":[\"/__PROJECT_ROOT_FOLDER__/root/908C_S6_L001_R1_001.atria.velvet-contigs.fa\"],\"inputR1Fastq\":[\"/__PROJECT_ROOT_FOLDER__/root/CMM3_S1_L001_R1_001.fastq.gz\"],\"inputR2Fastq\":[\"/__PROJECT_ROOT_FOLDER__/root/CMM3_S1_L001_R2_001.fastq.gz\"],\"pccGenomes\":[\"Dickeya\",\"Dickeya/Dickeya_fangzhongdai\"],\"genomeDepth\":1,\"analysisProfile\":\"Default\",\"fastqc\":true,\"trimming\":true,\"trimmingMethod\":\"Atria\",\"trimmingAdapter1\":\"AGATCGGAAGAGCACACGTCTGAACTCCAGTCA\",\"trimmingAdapter2\":\"AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT\",\"mapping\":false,\"mappingReference\":\"\",\"mappingFiltration\":false,\"mappingFiltrationMethod\":\"\",\"mappingDiscardOriginal\":true,\"assembly\":true,\"assembler\":\"Velvet\",\"fastaAnalysis\":true,\"fastaANI\":true,\"cpuLimit\":12,\"resume\":true}",:headers => Pair{SubString{String},SubString{String}}["Host" => "localhost:9391", "User-Agent" => "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:78.0) Gecko/20100101 Firefox/78.0", "Accept" => "application/json, text/plain, */*", "Accept-Language" => "en-CA,en-US;q=0.7,en;q=0.3", "Accept-Encoding" => "gzip, deflate", "Content-Type" => "application/x-www-form-urlencoded", "Content-Length" => "885", "Origin" => "http://localhost:8080", "Connection" => "keep-alive", "Referer" => "http://localhost:8080/"])
    =#
    time_request = now()
    data = get_request_data!(request) |> JSON.parse

    ### validate dirs and files
    data["projectDir"] = get(data, "projectDir", "") |> replace_project_root_folder
    data["projectDir"] == "" && (return json_response(request, 400))
    occursin(search_limit, data["projectDir"]) || (return json_response(request, 458))

    data["inputR1Fastq"] = get(data, "inputR1Fastq", []) .|> replace_project_root_folder
    data["inputR2Fastq"] = get(data, "inputR2Fastq", []) .|> replace_project_root_folder
    all(occursin.(search_limit, data["inputR1Fastq"])) || (return json_response(request, 458))
    all(occursin.(search_limit, data["inputR2Fastq"])) || (return json_response(request, 458))
    length(data["inputFasta"]) + length(data["inputR1Fastq"]) + length(data["inputR2Fastq"]) == 0 && (return json_response(request, 400))
    length(data["inputR1Fastq"]) == length(data["inputR2Fastq"]) || (return json_response(request, 400))

    data["inputFasta"] = get(data, "inputFasta", []) .|> replace_project_root_folder
    all(occursin.(search_limit, data["inputFasta"])) || (return json_response(request, 458))


    ### build command
    cmd = `$(Config.POLYCHROME) classifier`

    # --procs
    push!(cmd.exec, "--procs", get(data, "cpuLimit", Config.CPU_LIMIT) |> string)
    # --resume
    get(data, "resume", true) && push!(cmd.exec, "--resume")


    # --read1
    if length(data["inputR1Fastq"]) > 0
        push!(cmd.exec, "--read1")
        append!(cmd.exec, data["inputR1Fastq"])
    end
    # --read2
    if length(data["inputR2Fastq"]) > 0
        push!(cmd.exec, "--read2")
        append!(cmd.exec, data["inputR2Fastq"])
    end
    # --fasta
    if length(data["inputFasta"]) > 0
        push!(cmd.exec, "--fasta")
        append!(cmd.exec, data["inputFasta"])
    end
    # --output-dir
    push!(cmd.exec, "--output-dir", data["projectDir"])


    # --pcc-db
    push!(cmd.exec, "--pcc-db", Config.PCC_DATABASE)
    # --compare-to
    push!(cmd.exec, "--compare-to")
    append!(cmd.exec, data["pccGenomes"])
    # --depth
    push!(cmd.exec, "--depth", get(data, "genomeDepth", 1) |> string)


    # --do-fastqc
    push!(cmd.exec, "--do-fastqc", get(data, "fastqc", true) ? "YES" : "NO")
    # --do-trim
    push!(cmd.exec, "--do-trim", get(data, "trimming", true) ? "YES" : "NO")
    if get(data, "trimming", true)
        # --trimmer
        trimming_method = get(data, "trimmingMethod", "")
        if haskey(Config.TRIMMING_METHOD_OPTIONS, trimming_method)
            push!(cmd.exec, "--trimmer", Config.TRIMMING_METHOD_OPTIONS[trimming_method])
        end
    end


    # --do-map
    push!(cmd.exec, "--do-map", get(data, "mapping", false) ? "YES" : "NO")
    if get(data, "mapping", false)
        # --mapper
        mapping_method = get(data, "mappingMethod", "")
        if haskey(Config.MAPPING_METHOD_OPTIONS, mapping_method)
            push!(cmd.exec, "--mapper", Config.MAPPING_METHOD_OPTIONS[mapping_method])
        end
        # --map-ref
        mapping_ref = get(data, "mappingReference", "")
        if haskey(Config.MAPPING_REFERENCE_OPTIONS, mapping_ref)
            push!(cmd.exec, "--map-ref", Config.MAPPING_REFERENCE_OPTIONS[mapping_ref])
        else
            json_response(request, 400)
        end
        # --bam-to-fastq
        bam_to_fastq_value = if get(data, "mappingFiltration", false)
            mapping_filter_method = get(data, "mappingFiltrationMethod", "")
            if haskey(Config.MAPPING_FILTRATION_METHOD_OPTIONS, mapping_filter_method)
                Config.MAPPING_FILTRATION_METHOD_OPTIONS[mapping_filter_method]
            else
                "0-0-0" # disable bam to fastq
            end
        else
            "0-0-0"
        end
        push!(cmd.exec, "--bam-to-fastq", bam_to_fastq_value)
        # --keep-unfiltered-fastq
        push!(cmd.exec, "--keep-unfiltered-fastq", get(data, "mappingDiscardOriginal", true) ? "NO" : "YES")
    end


    # --do-assembly
    push!(cmd.exec, "--do-assembly", get(data, "assembly", true) ? "YES" : "NO")
    if get(data, "assembly", true)
        # --assembler
        assembler = get(data, "assembler", "")
        if haskey(Config.ASSEMBER_OPTIONS, assembler)
            push!(cmd.exec, "--assembler", Config.ASSEMBER_OPTIONS[assembler])
        end
    end

    # --do-fasta-analysis
    push!(cmd.exec, "--do-fasta-analysis", get(data, "fastaAnalysis", true) ? "YES" : "NO")
    if get(data, "fastaAnalysis", true)
        # --do-ani
        push!(cmd.exec, "--do-ani", get(data, "fastaANI", true) ? "YES" : "NO")
    end

    log_request && @info(request, TimeRequest = time_request, Username = get(data, "username", "Unknown Username"), Command = cmd)

    # submit the job
    analysis_name = generate_analysis_name(data["pccGenomes"], depth=get(data, "genomeDepth", 1))
    job_name = basename(data["projectDir"]) * "/" * analysis_name
    try
        mkpath(data["projectDir"]; mode=0o755)
        tmp_file = joinpath(data["projectDir"], randstring())
        touch(tmp_file)
        rm(tmp_file)
    catch
        return json_response(request, 461)  # Project Name (Path) Rejected by Server
    end
    stdout_file = joinpath(data["projectDir"], "pcc-logs-$analysis_name.$time_request.out.txt")
    stderr_file = joinpath(data["projectDir"], "pcc-logs-$analysis_name.$time_request.err.txt")
    job = Job(
        cmd;
        stdout = stdout_file,
        stderr = stderr_file,
        name = job_name,
        user = get(data, "username", ""),
        ncpu = get(data, "cpuLimit", Config.CPU_LIMIT),
        create_time = time_request,
        priority = 20
    )
    submit!(job)

    return json_response(request, 200, data=Dict(
        "jobID" => job.id,
        "jobName" => job_name
    ))
end
