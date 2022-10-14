
function get_chr_order(chr_iter)
    chr_order = Dict{String,Int64}()
    for (i,chr) in enumerate(chr_iter)
        chr_order[chr] = i
    end
    chr_order
end

"""
    generate_parsed_clasnip_db(inputs, labels, reference_index_path; min_prob::Float64=0.05)

- `inputs`: vector of input vcf files
- `labels`: vector of labels of inputs
- `reference_index_path`: the .fai index of the reference fasta used for mapping.
- `min_prob`: discard SNVs if their probabilities < FLOAT64.

This function is more memory efficient and aims to replace the following code:

```julia
@time generate_db_vcf(db_vcf_path, inputs, labels)

@info "Getting sample information"
group_dict, nsample_group = @time get_sample_info_from_db_vcf(db_vcf_path)
groups = collect(keys(nsample_group))

@info "Loading db vcf"
db_vcf = @time vcf_load(db_vcf_path)

# parse db_vcf, generating dict of probability
@info "Parsing db vcf"
db_vcf_parsed = @time parse_group_db_vcf(db_vcf, nsample_group; missing_as_ref=!args["all-positions"], min_prob=args["min-prob"])
```
"""
function generate_parsed_clasnip_db(inputs, labels, reference_index_path; min_prob::Float64=0.05)
    @info Pipelines.timestamp() * "## Generating db vcf :: Start ##"
    @info Pipelines.timestamp() * "Parsing reference index"
    faidx = parse_faidx(reference_index_path)
    chr_order = Dict{String,Int64}()
    for (i,chr) in enumerate(faidx.CHROM)
        chr_order[chr] = i
    end

    group_dict, group_indices, nsample_group, groups = parse_group_from_label(labels)

    # vectors in parsed_db::DataFrame
    CHROM = String[]
    POS = Int64[]
    REF = String[]
    ALT2PROBs = Dict{String,Vector{Float64}}[]

    N_ROW_EACH_BATCH = 1000
    db_group_vcf_snv = DataFrame(
        REF = Union{String,Missing}[missing for _ in 1:N_ROW_EACH_BATCH]
    )
    # alt2prob = Dict{String,Float64}()
    db_group_alt2prob = DataFrame([
        group => [Dict{String,Float64}() for _ in 1:N_ROW_EACH_BATCH]
        for group in groups
    ])

    # io of inputs
    io_dict = Vector{Dict{String, Any}}(undef, length(inputs))
    for (ivcf, vcf) in enumerate(inputs)
        io_dict[ivcf] = Dict{String,Any}("meio" => MemoryEfficientIO(vcf))
    end

    for faidx_row in eachrow(faidx)
        chr = faidx_row.CHROM
        chr_length = faidx_row.LENGTH
        pos_starts = 1:N_ROW_EACH_BATCH:chr_length
        
        # processing batch of chr + pos
        for pos_start in pos_starts
            pos_end = min(pos_start + N_ROW_EACH_BATCH - 1, chr_length)
            
            if pos_start % 50000 == 1
                @info Pipelines.timestamp() * "$(now()) - Generate Clasnip DB: processing $chr:$pos_start"
            end

            # empty REF before each batch processing
            fill!(db_group_vcf_snv.REF, missing)

            # each group
            for group in groups
                io_dict_group = @view io_dict[group_indices[group]]
                
                # one sample, io_info::Dict
                # load each vcf into db_group_vcf_snv
                for (isample, io_info) in enumerate(io_dict_group)
                    column_to_fill = isample + 1  # first column is relative position
                    fill_batch_vcf_db!(db_group_vcf_snv, io_info, column_to_fill, chr_order, chr, pos_start, pos_end)
                end

                # after loading this group's vcf,
                # start compute alt2prob fir this group
                nsample = nsample_group[group]
                group_vcf_db_to_alt2prob!(db_group_alt2prob, db_group_vcf_snv, group, nsample; min_prob = min_prob)
            end

            # evaluate alt2probs among all groups
            for irow in 1:nrow(db_group_alt2prob)
                row = db_group_alt2prob[irow,:]
                alt2probs = summary_alt2probs_among_groups(row)

                if length(keys(alt2probs)) <= 1
                    # do not store this alt2probs
                    continue
                end

                # store alt2probs
                pos = pos_start + irow - 1
                ref = db_group_vcf_snv[irow, 1]
                push!(CHROM, chr)
                push!(POS, pos)
                push!(REF, ref)
                push!(ALT2PROBs, alt2probs)
                
            end
                
        end
    end

    # close ios
    for io_info in io_dict
        close(io_info["meio"])
    end

    vcf_db_parsed = DataFrame(
        "CHROM" => CHROM,
        "POS" => POS,
        "REF" => REF,
        "ALT2PROBs" => ALT2PROBs
    )
    unique_reference_for_db_vcf_parsed!(vcf_db_parsed)

    return vcf_db_parsed, groups, group_dict, nsample_group
end

"""
    parse_faidx(reference_index_path::AbstractString)

Parse fasta/fastq index file (.fai). Return a `DataFrame` with columns `["CHROM", "LENGTH", "OFFSET", "LINEBASES", "LINEWIDTH", "QUALOFFSET"]`.
"""
function parse_faidx(reference_index_path::AbstractString)
    faidx = CSV.read(reference_index_path, DataFrame; delim='\t', header=["CHROM", "LENGTH", "OFFSET", "LINEBASES", "LINEWIDTH", "QUALOFFSET"], ntasks=1, stringtype=String)
    faidx[!, :CHROM] = [String(s) for s in faidx.CHROM]
    faidx
end

function infer_reference_index_path(dir)
    fais = filter!(x -> occursin(r"\.fai$", x), readdir(dir, join=true))
    if length(fais) != 1
        @error Pipelines.timestamp() * "Cannot infer reference index path: file ending with .fai is missing or multiple .fai files were found under dir: $dir"
        return nothing
    else
        return fais[1]
    end
end

function get_vcf_format_data(name, format, data)
    formats = split(format, ':')
    vals = split(data, ':')
    if length(vals) != length(formats)
        return nothing
    end
    idx = findfirst(x -> x == name, formats)
    if isnothing(idx)
        return nothing
    end
    String(vals[idx])
end

function fill_batch_vcf_db!(db_group_vcf_snv::DataFrame, io_info::Dict, column_to_fill::Int64, chr_order::Dict{String,Int64}, chr::String, pos_start::Int64, pos_end::Int64)
    # empty column_to_fill
    if ncol(db_group_vcf_snv) == column_to_fill - 1
        db_group_vcf_snv[!, string("col", ncol(db_group_vcf_snv)+1)] = Union{VCFLineInfo,Missing}[missing for _ in 1:nrow(db_group_vcf_snv)]
    elseif ncol(db_group_vcf_snv) >= column_to_fill
        fill!(db_group_vcf_snv[!, column_to_fill], missing)
    else
        error("Unexpected calling fill_batch_vcf_db! column_to_fill not expected.")
    end
    
    vcf_io = io_info["meio"]

    ## get necessary header indices of VCF
    header_indices = get(io_info, "header_indices", nothing)
    if isnothing(header_indices)
        header = nothing
        for line in eachline(vcf_io)
            length(line) < 3 && continue
            line[1] == '#' && line[2] == '#' && continue
            if occursin(r"^#CHROM", line)
                # header line
                header_string = replace(line, "#" => "", count=1)
                header = split(header_string, '\t')
                break
            end
            line[1] == '#' || break
        end
        isnothing(header) && error("No header line found in VCF file: $vcf_path ")

        CHROM = findfirst(x -> x == "CHROM", header)
        POS = findfirst(x -> x == "POS", header)
        REF = findfirst(x -> x == "REF", header)
        ALT = findfirst(x -> x == "ALT", header)
        FORMAT = findfirst(x -> x == "FORMAT", header)
        DATA = findfirst(x -> x == "unknown", header)  # freebayes column unknown
        isnothing(CHROM) && error("Column CHROM missing in VCF file: $vcf_path")
        isnothing(POS) && error("Column POS missing in VCF file: $vcf_path")
        isnothing(REF) && error("Column REF missing in VCF file: $vcf_path")
        isnothing(ALT) && error("Column ALT missing in VCF file: $vcf_path")
        isnothing(FORMAT) && error("Column FORMAT missing in VCF file: $vcf_path")
        isnothing(DATA) && error("Column 'unknown' missing in VCF file: $vcf_path")
        @assert CHROM == 1
        @assert POS == 2
        @assert REF == 4
        @assert ALT == 5
        @assert FORMAT == 9
        @assert DATA == 10
        io_info["header_indices"] = true
    # else
        #CHROM, POS, REF, ALT, FORMAT, DATA = header_indices
    end
    
    ## check previous lines
    last_line = get(io_info, "last_line_info", nothing)
    if !isnothing(last_line)
        # check range of last line
        line_range = check_range(chr_order, chr, pos_start, pos_end, last_line.chr, last_line.pos)
        if line_range === :in_range
            fill_vcf!(db_group_vcf_snv, column_to_fill, pos_start, last_line)
            # discard last_line
            io_info["last_line_info"] = nothing
        elseif line_range === :on_left
            @error Pipelines.timestamp() * "last_line on the left will not be used." last_line
            io_info["last_line_info"] = nothing
        else  # :on_right: nothing to do, just return
            return
        end
    end

    while !eof(vcf_io)
        # process of lines
        line = readline(vcf_io)
        line_info = VCFLineInfo(line)

        # invalid line_info
        if isnothing(line_info)
            continue
        end

        # check range 
        line_range = check_range(chr_order, chr, pos_start, pos_end, line_info.chr, line_info.pos)
        if line_range === :in_range
            fill_vcf!(db_group_vcf_snv, column_to_fill, pos_start, line_info)
            continue
        elseif line_range === :on_left
            @error Pipelines.timestamp() * "line on the left will not be used." line_info
        else  # :on_right: store as last_line
            io_info["last_line_info"] = line_info
            break
        end
    end
end

"""
    parse_group_from_label(labels::Vector)

- Element format of `labels`: GROUP/SAMPLE

return `group_dict::Dict{String, Vector{String}}, group_indices::Dict{String,Vector{Int64}}, nsample_group::Dict{String, Int64}, groups::Vector{String}`
"""
function parse_group_from_label(labels::Vector)
    group_dict = Dict{String,Vector{String}}()
    group_indices = Dict{String,Vector{Int64}}()
    for (i, label) in enumerate(labels)
        group, sample = split(label, '/', limit=2)
        sample_list = get(group_dict, group, nothing)
        sample_indices = get(group_indices, group, nothing)
        if isnothing(sample_list)
            group_dict[group] = String[sample]
            group_indices[group] = Int64[i]
        else
            push!(sample_list, sample)
            push!(sample_indices, i)
        end
    end
    nsample_group = Dict([
        String(i.first) => length(i.second) for i in group_dict
    ])
    groups = collect(keys(nsample_group))
    return group_dict, group_indices, nsample_group, groups
end

@inline function check_range(chr_order::Dict{String,Int64}, chr::AbstractString, pos_start::Int64, pos_end::Int64, chr_to_check::AbstractString, pos_to_check::Int64)
    if chr == chr_to_check
        if pos_start <= pos_to_check <= pos_end
            return :in_range
        elseif pos_to_check > pos_end
            return :on_right
        else
            return :on_left
        end
    else
        chr_idx = chr_order[chr]
        chr_to_check_idx = get(chr_order, chr_to_check, -1)  # if chr_to_check not exist, return on_left
        if chr_to_check_idx > chr_idx
            return :on_right
        elseif chr_to_check_idx < chr_idx
            return :on_left
        else
            @error Pipelines.timestamp() * "Unexpected in check_range" chr_order chr pos_start pos_end chr_to_check pos_to_check
            error("Unexpected in check_range")
        end
    end
end

@inline function fill_vcf!(db_group_vcf_snv::DataFrame, column_to_fill::Int, pos_start::Int, line_info::VCFLineInfo)
    irow = line_info.pos - pos_start + 1
    db_group_vcf_snv[irow, column_to_fill] = line_info
    # first column is REF
    if ismissing(db_group_vcf_snv[irow, 1])
        db_group_vcf_snv[irow, 1] = line_info.ref
    end
end

@inline function group_vcf_db_to_alt2prob!(db_group_alt2prob, db_group_vcf_snv, group, nsample; min_prob::Float64 = 0.05)
    n_row = nrow(db_group_vcf_snv)
    
    for irow in 1:n_row
        alt2prob = db_group_alt2prob[irow, group]
        # clear all elements first
        empty!(alt2prob)

        sample_indices = 2:nsample+1
        row = db_group_vcf_snv[irow, :]
        for i_sample in sample_indices
            if ismissing(row[i_sample])
                continue
            end

            sample_ALTs = split(row[i_sample].alt, ',')

            sample_DEPTHs = parse.(Int, split(row[i_sample].ad, ','))
            sample_PROBs = sample_DEPTHs ./ sum(sample_DEPTHs)

            if length(sample_ALTs) + 1 == length(sample_PROBs)
                # REF get some coverage: add REF (.) to alt2prob
                if sample_DEPTHs[1] > 0
                    if haskey(alt2prob, ".")
                        alt2prob["."] += sample_PROBs[1]
                    else
                        alt2prob["."] = sample_PROBs[1]
                    end
                end
                # Add ALT to alt2prob
                for (idx_ALT, ALT) in enumerate(sample_ALTs)
                    # + 1 index offset
                    if haskey(alt2prob, ALT)
                        alt2prob[ALT] += sample_PROBs[1+idx_ALT]
                    else
                        alt2prob[ALT] = sample_PROBs[1+idx_ALT]
                    end
                end
            elseif length(sample_ALTs) == length(sample_PROBs)
                # . in sample_ALTs
                for (idx_ALT, ALT) in enumerate(sample_ALTs)
                    if haskey(alt2prob, ALT)
                        alt2prob[ALT] += sample_PROBs[idx_ALT]
                    else
                        alt2prob[ALT] = sample_PROBs[idx_ALT]
                    end
                end
            else
                @error Pipelines.timestamp() * "Bugs here. Invalid sample_ALTs and sample_DEPTHs" sample_ALTs sample_DEPTHs group nsample sample_indices df
            end
        end

        value_normalize!(alt2prob)

        # filter: remove low probability < min_prob
        if min_prob > 0.0
            filter!(x -> x.second >= min_prob, alt2prob)
            value_normalize!(alt2prob)
        end
    end
end

@inline function summary_alt2probs_among_groups(iter_alt2prob)
    alt2probs = Dict{String,Vector{Float64}}()

    ngroup = length(iter_alt2prob)
    for (igroup, alt2prob) in enumerate(iter_alt2prob)
        # copy items from alt2prob (for the group) to ALT2PROBs (summary of groups)
        for ALT in collect(keys(alt2prob))
            if haskey(alt2probs, ALT)
                alt2probs[ALT][igroup] += alt2prob[ALT]
            else
                alt2probs[ALT] = zeros(ngroup)
                alt2probs[ALT][igroup] += alt2prob[ALT]
            end
        end
    end
    return alt2probs
end


function vcf_load_overlapped(vcf_path::AbstractString, db_vcf_parsed::DataFrame)
    chr_order = get_chr_order(unique(db_vcf_parsed.CHROM))

    CHROM = Vector{String}()
    POS = Vector{Int64}()
    SAMPLE = Vector{String}() # ALT
    DEPTH = Vector{String}()  # AD

    vcf_io = MemoryEfficientIO(vcf_path)

    nrow_db = nrow(db_vcf_parsed)
    irow_db = 1
    while !eof(vcf_io)
        line = readline(vcf_io)
        line_info = VCFLineInfo(line)
        
        # invalid line_info
        if isnothing(line_info)
            continue
        end

        @label compare_corrdinates

        chr_db = db_vcf_parsed[irow_db, 1]
        pos_db = db_vcf_parsed[irow_db, 2]
        line_range = check_range(chr_order, chr_db, pos_db, pos_db, line_info.chr, line_info.pos)

        if line_range === :in_range
            # overlapped with db, use it
            push!(CHROM, line_info.chr)
            push!(POS, line_info.pos)
            push!(SAMPLE, line_info.alt)
            push!(DEPTH, line_info.ad)

        elseif line_range === :on_left
            # read the next
            continue
        else  # :on_right: store as last_line
            # increase irow_db
            irow_db += 1
            if irow_db > nrow_db
                break
            else
                @goto compare_corrdinates
            end
        end
    end
    close(vcf_io)
    
    unique_string_reference!(CHROM; sorted = true)
    unique_string_reference!(SAMPLE; sorted = true)
    unique_string_reference!(DEPTH; sorted = true)

    vcf_df = DataFrame(
        :CHROM => CHROM,
        :POS => POS,
        :SAMPLE => SAMPLE,
        :DEPTH => DEPTH
    )
end




"""
    unique_reference_for_db_vcf_parsed!(db_vcf_parsed::DataFrame)

Reduce memory usage by make unique `String` and `Vector{Float64}` references.

Reference: `InternedStrings.intern!` https://github.com/JuliaString/InternedStrings.jl/blob/master/src/InternedStrings.jl
"""
function unique_reference_for_db_vcf_parsed!(db_vcf_parsed::DataFrame)
    # Base.summarysize(db_vcf_parsed) = 1_172_012_810 > 819961429
    ref_dict = Dict{String,Nothing}()

    # Base.summarysize(db_vcf_parsed.CHROM) == 23343610 > 6225058
    unique_string_reference!(db_vcf_parsed.CHROM; sorted = true)
    # Base.summarysize(db_vcf_parsed.REF) == 13296603 > 6271033
    unique_string_reference!(db_vcf_parsed.REF; ref_dict = ref_dict)
    # Base.summarysize(db_vcf_parsed.ALT2PROBs) == 786355083 > 458475334
    unique_string_reference!(db_vcf_parsed.ALT2PROBs; ref_dict = ref_dict)

    unique_vec_float64_reference!(db_vcf_parsed.ALT2PROBs)

    for i in 5:ncol(db_vcf_parsed)
        unique_string_reference!(db_vcf_parsed[:,i]; ref_dict = ref_dict)
    end
    db_vcf_parsed
end

function unique_string_reference!(vec::Vector{String}; sorted::Bool = false, ref_dict::Dict{String,Nothing} = Dict{String,Nothing}())
    n = length(vec)
    n <= 2 && return vec
    if sorted
        i = 1
        j = 2
        @inbounds while j <= n
            if vec[i] == vec[j]
                vec[j] = Ref(vec, i)[]
            end
            i += 1
            j += 1
        end
    else # not sorted
        @inbounds for i in eachindex(vec)
            key = vec[i]
            index = Base.ht_keyindex2!(ref_dict, key) # returns index if present, or -index if not
            if index > 0
                # found it
                vec[i] = Ref(ref_dict.keys, index)[]
            else
                # Not found, so add it,
                ref_dict[Ref(key)[]] = nothing
            end
        end
    end
    vec
end

function unique_string_reference!(dict::Dict{String, T}; ref_dict::Dict{String,Nothing} = Dict{String,Nothing}()) where T
    for i in eachindex(dict.slots)
        @inbounds if dict.slots[i] == 0x01
            key = dict.keys[i]
            index = Base.ht_keyindex2!(ref_dict, key) # returns index if present, or -index if not
            if index > 0
                # found it
                dict.keys[i] = Ref(ref_dict.keys, index)[]
            else
                # Not found, so add it,
                ref_dict[Ref(key)[]] = nothing
            end
        end
    end
    dict
end
unique_string_reference!(dict::Dict{Any}; ref_dict::Dict{String,Nothing} = Dict{String,Nothing}()) = dict
function unique_string_reference!(vec::Vector{Dict{String, T}}; ref_dict::Dict{String,Nothing} = Dict{String,Nothing}()) where T
    for dict in vec
        unique_string_reference!(dict; ref_dict = ref_dict)
    end
    vec
end
unique_string_reference!(a; ref_dict=nothing, sorted=true) = a

function unique_vec_float64_reference!(dict::Dict{T, Vector{Float64}}; ref_dict::Dict{Vector{Float64},Nothing} = Dict{Vector{Float64},Nothing}()) where T
    for i in eachindex(dict.slots)
        @inbounds if dict.slots[i] == 0x01
            key = dict.vals[i]
            index = Base.ht_keyindex2!(ref_dict, key) # returns index if present, or -index if not
            if index > 0
                # found it
                if pointer(dict.vals[i]) != pointer(Ref(ref_dict.keys, index)[])
                    empty!(dict.vals[i])
                end
                dict.vals[i] = Ref(ref_dict.keys, index)[]
            else
                # Not found, so add it,
                ref_dict[Ref(key)[]] = nothing
            end
        end
    end
    dict
end
function unique_vec_float64_reference!(vec::Vector{Dict{T, Vector{Float64}}}; ref_dict::Dict{Vector{Float64},Nothing} = Dict{Vector{Float64},Nothing}()) where T
    for dict in vec
        unique_vec_float64_reference!(dict; ref_dict = ref_dict)
    end
    vec
end