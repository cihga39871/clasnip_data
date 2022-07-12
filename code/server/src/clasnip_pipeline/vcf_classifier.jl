#!julia --color=yes

using ArgParse
using DataFrames, DataFramesMeta
using CSV
using JLD2
using StatsBase
using GenomicFeatures, GFF3

include("api.vcf_stats.jl")

description = """
Classifier using VCF.
"""

function parsing_args(args)
    settings = ArgParseSettings(description=description)
    add_arg_group!(settings, "Database VCF Generation/Loading")
    @add_arg_table! settings begin
        "--generate-db-vcf"
            help = "generate db-vcf file from inputs, and do no run sample classifier. If not specified, assume the inputs are new samples"
            action = :store_true
        "--all-positions"
            help = "(with --generate-db-vcf) whether input vcf files contain all positions? If no, missing are treated as ref."
            action = :store_true
        "--db-vcf", "-d"
            help = "(with --generate-db-vcf) output 'db-vcf' file. NOTE: the parsed db-vcf file named *.db-vcf.jld2 will be generated for later use"
            default = ""
        "--min-prob", "-m"
            help = "(with --generate-db-vcf) For each group at each location, if the probability of the SNP is less tham `min_prob`, the SNP will be removed."
            default = 0.05
            arg_type = Float64
        "--db-vcf-jld2", "-D"
            help = "(without --generate-db-vcf) input parsed db vcf in JLD2 format (result of `vcf_classifier.jl --generate-db-vcf`)"
            default = ""
        "--save-all-locus"
            action = :store_true
    end
    add_arg_group!(settings, "Sample VCF Input")
    @add_arg_table! settings begin
        "--inputs", "-i"
            help = "input vcf files (containing all positions in --db-vcf)"
            nargs = '+'
        "--labels", "-l"
            help = "input file labels (same arg count as --input); if inputs are reference samples (with --generate-db-vcf), the format of label has to be GROUP/SAMPLE, such as HB/S1; incomparible with --label-regex"
            nargs = '*'
        "--label-regex", "-r"
            help = "generating labels by applying REGEX to --inputs; incomatible with --labels"
            metavar = "REGEX"
    end
    add_arg_group!(settings, "Sample Classification Output")
    @add_arg_table! settings begin
        "-o", "--out-prefix"
            help = "(not valid with --generate-db-vcf) file prefix of output sample clasisfication; <input> will be replaced by input file name"
            default = "<input>.classifier"
        "-s", "--SNP-cutoff"
            help = "if the SNP coverage for input sample is less than it, the classification will become `Negative or Low Covered SNP (<NUM)`. It is interpreted as percentage if <= 1, as count if > 1."
            default = 50.0
            arg_type = Float64
    end
    return parse_args(args, settings)
end

args = parsing_args(ARGS)

inputs = args["inputs"]
outprefix = args["out-prefix"]
SNP_coverage_cutoff = args["SNP-cutoff"]

# generate labels
if isempty(args["labels"]) && isnothing(args["label-regex"])
    # auto generate
    if args["generate-db-vcf"]
        @info "All input labels will be auto-generated as 'last_dir/BasenameOfInput'"
        labels = map(inputs) do input
            path = abspath(input)
            base_input = splitext(basename(path))[1]
            last_dir = basename(dirname(path))
            string(last_dir, "/", base_input)
        end
    else
        @info "All input labels will be auto-generated as 'ClassifiedResult/BasenameOfInput'"
        labels = [":auto" for i in 1:length(inputs)]
    end
elseif !isempty(args["labels"]) && !isnothing(args["label-regex"])
    # arg conflict: throw error
    error("Argument Error: Conflicts in --labels and --label-regex. Please only use one of them.")
elseif !isempty(args["labels"])
    labels = args["labels"]
    if length(labels) != length(inputs)
        error("Argument Error: number of argument differs in --inputs and --labels.")
    end
elseif !isnothing(args["label-regex"])
    label_regex = args["label-regex"] |> Regex
    labels = map(inputs) do input
        m = match(label_regex, input)
        if isnothing(m)
            if args["generate-db-vcf"]
                error("--label-regex $(label_regex) match failed for input $input")
                exit(3)
            else
                @warn "--label-regex match failed. A label will be auto-generated as 'ClassifiedResult/BasenameOfInput'" input
                return ":auto"
            end
        else
            # label_regex works. If () found in regex, it will capture strings.
            # those strings will be joined by "/" because the default label should be GROUP/SAMPLE_ID
            # otherwise, return matched strings
            if length(m.captures) == 0
                return m.match
            else
                return join(m.captures, "/")
            end
        end
    end
end


### generate db-vcf
if args["generate-db-vcf"]
    db_vcf_path = args["db-vcf"]
    db_vcf_path == "" && error("--db-vcf cannot be empty with --generate-db-vcf")

    @info "Generating db vcf"
    @time generate_db_vcf(db_vcf_path, inputs, labels)

    ### load infos
    @info "Getting sample information"
    group_dict, nsample_group = @time get_sample_info_from_db_vcf(db_vcf_path)
    groups = collect(keys(nsample_group))

    @info "Loading db vcf"
    db_vcf = @time vcf_load(db_vcf_path)

    # parse db_vcf, generating dict of probability
    @info "Parsing db vcf"
    db_vcf_parsed = @time parse_group_db_vcf(db_vcf, nsample_group; missing_as_ref=!args["all-positions"], min_prob=args["min-prob"])

    if args["save-all-locus"]
        @info "Saving parsed db vcf"
        db_vcf_jld2_path = "$db_vcf_path.jld2"
        @time @save db_vcf_jld2_path db_vcf_parsed groups group_dict nsample_group
        @info "Raw data (db_vcf_parsed groups group_dict nsample_group) saved to $db_vcf_jld2_path"
    end

    @info "Saving parsed db vcf (reduced one)"
    filter!(:ALT2PROBs => d -> length(keys(d)) > 1, db_vcf_parsed)
    db_vcf_jld2_path = "$db_vcf_path.reduced.jld2"
    @time @save db_vcf_jld2_path db_vcf_parsed groups group_dict nsample_group
    @info "Reduced raw data (db_vcf_parsed groups group_dict nsample_group) saved to $db_vcf_jld2_path"
    @info "--generate-db-vcf mode: Done. Exit."

    exit()
else
    db_vcf_jld2_path = args["db-vcf-jld2"]
    db_vcf_jld2_path == "" && error("--db-vcf-jld2 cannot be empty without --generate-db-vcf.")
    isfile(db_vcf_jld2_path) || error("--db-vcf-jld2 $db_vcf_jld2_path does not exist.")
    @info "Loading parsed db vcf"
    @time @load db_vcf_jld2_path db_vcf_parsed groups group_dict nsample_group
end

### analysis input samples

## initiate columns in result summary
res_label = String[]
res_classification = String[]
res_count_covered_SNP = Int[]
res_count_all_SNP = Int[]

res_score_dict = Dict{SubString{String}, Vector{Float64}}()
for group in groups
    res_score_dict[group] = Vector{Float64}()
end

## main analysis for each sample
for (i_input, input_file) in enumerate(inputs)
    input_label = labels[i_input]
    @info "VCF Classifier: Start classification" input_file input_label

    input_file, label, classify_to, vcf, result, count_covered_SNP, count_all_SNP = classifier_single_sample(input_file, outprefix, db_vcf_parsed, groups; input_label=input_label, SNP_coverage_cutoff=SNP_coverage_cutoff);

    if isnothing(input_file)
        # input vcf does not contain vcf data rows
        continue
    end

    push!(res_label, label)
    push!(res_classification, classify_to)
    push!(res_count_covered_SNP, count_covered_SNP)
    push!(res_count_all_SNP, count_all_SNP)

    for (igroup, group) in enumerate(result.GROUP)
        push!(res_score_dict[group], result[igroup, :SCORE])
    end
end

## output of result summary
res_df = DataFrame(
    INPUT = inputs,
    CLASSIFICATION = res_classification,
    COVERED_SNPS = res_count_covered_SNP,
    ALL_SNPS = res_count_all_SNP,
    LABEL = res_label
)
for group in groups
    res_df[!, Symbol("SCORE_" * uppercase(group))] = res_score_dict[group]
end

out_res_path = replace(outprefix, r"<input>[\.\_\-]*" => "") * ".summary.tsv"
CSV.write(out_res_path, res_df; delim='\t')
@info "VCF Classifier: Write summary for all samples" OUT_FILE=out_res_path
