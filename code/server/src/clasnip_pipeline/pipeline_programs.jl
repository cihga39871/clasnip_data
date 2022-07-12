# Pipeline functions for Clasnip
# Linux only.

# requirements:
# samtools
# bowtie2
# freebayes ^1.3.2

# using Pipelines
# include("../dependencies.jl")

check_dependency(SAMTOOLS)
check_dependency(BOWTIE2)
check_dependency(FREEBAYES)

# fa2fq = joinpath(ENV["CJCBioTools"], "DataTypeConvert", "fa2fq.jl")
# check_dependency_file(fa2fq)

const vcf_classifier = joinpath(@__DIR__, "vcf_classifier.jl")
isfile(vcf_classifier) || @warn("vcf_classifier.jl not found.")
#
# FA2FQ = CmdDependency(
#     exec = `$julia $fa2fq`,
#     test_args = `--help`
# )
# check_dependency(FA2FQ)

function fa2fq(input::AbstractString; output::AbstractString = input * ".fq",  read_length::Int = 120, sliding_step::Int = 10)
    reader = if occursin(r"\.gz$", input)
        @error "Gzip file is not supported: $input"
        return nothing
        # FASTA.Reader(GzipDecompressorStream(open(input, "r")))
    else
        FASTA.Reader(open(input, "r"))
    end

    out_stream = open(output, "w+")

    for record in reader
        record_len = length(FASTA.sequence(record))

        @info "FA2FQ Loading sequence: $(FASTA.identifier(record)) (length=$record_len)"

		sliding_end = max(1, record_len - read_length + sliding_step)

        for START in 1:sliding_step:sliding_end
            name = FASTA.identifier(record) * "-$START"
            END = min(START + read_length - 1, record_len)
            seq = FASTA.sequence(record, START:END)
            qual = fill(41, length(seq))

            println(out_stream, FASTQ.Record(name, seq, qual))
        end
    end
    close(out_stream)
    close(reader)
end

program_fa2fq = JuliaProgram(
    name = "Fasta to Fastq",
    id_file = ".fa2fq",
    # cmd_dependencies = [FA2FQ],
    inputs = "FASTA",
	outputs = "FASTQ" => "<FASTA>.fq",
    validate_inputs = inputs -> check_dependency_file(inputs["FASTA"]),
    main = (i,o) -> begin
		fa2fq(i["FASTA"], output = o["FASTQ"])
		return o
	end,
	validate_outputs = outputs -> begin
		check_dependency_file(outputs["FASTQ"])
	end,
)

function check_bowtie2_index(inputs, outputs)
    fasta = inputs["REF"]
	build_bowtie2_index(fasta)
end

function has_bowtie2_index(fasta)
	in_building_file = fasta * ".bowtie2-building"
	while isfile(fasta * ".bowtie2-building")
		sleep(2)
	end
	exts = [".1.bt2", ".2.bt2", ".3.bt2", ".4.bt2", ".rev.1.bt2", ".rev.2.bt2"]
	for ext in exts
		isfile(fasta * ext) || (return false)
	end
	return true
end
function build_bowtie2_index(fasta)
	if has_bowtie2_index(fasta)
		return true
	else
		in_building_file = fasta * ".bowtie2-building"
		is_success = false
		try
			touch(in_building_file)
			run(`bowtie2-build $fasta $fasta`)
			run(`samtools faidx $fasta`) # cannot use gzip/bgzip, freebayes not compatible
			is_success = true
		catch e
			rethrow(e)
			@error "Cannot build bowtie2 index for $fasta"
		finally
			rm(in_building_file)
		end
		return is_success
	end
end

program_bowtie2 = CmdProgram(
	name = "Alignment",
	id_file = ".bowtie2",
	cmd_dependencies = [BOWTIE2, SAMTOOLS],

	inputs = ["FASTQ", "REF", "THREADS" => Int => 1],
	validate_inputs = inputs -> begin
		check_dependency_file(inputs["FASTQ"]) &&
		check_dependency_file(inputs["REF"])
	end,

	prerequisites = check_bowtie2_index,

	outputs = "BAM" => "<FASTQ>.bam",

	validate_outputs = outputs -> begin
		check_dependency_file(outputs["BAM"])
	end,

	cmd = pipeline(`$BOWTIE2 -p THREADS -x REF -q FASTQ -k 10`, `$SAMTOOLS sort -@ THREADS -O bam -o BAM`),

	wrap_up = (inputs, outputs) -> run(`$SAMTOOLS index -@ THREADS $(outputs["BAM"])`)
)

program_freebayes = CmdProgram(
    name = "Variant Calling",
    id_file = ".freebayes",
    cmd_dependencies = [FREEBAYES],
    inputs = ["BAM", "REF"],
    validate_inputs = inputs -> begin
        check_dependency_file(inputs["BAM"]) &&
        check_dependency_file(inputs["REF"])
    end,
    outputs = "VCF" => "<BAM>.all.vcf",
    cmd = `$FREEBAYES -f REF -p 4 --gvcf -v VCF -g 500 --haplotype-length 0 --min-alternate-count 1 --min-alternate-fraction 0 --pooled-continuous --report-monomorphic --haplotype-length 0 --use-duplicate-reads BAM`,
	validate_outputs = outputs -> begin
		isfile(outputs["VCF"]) && filesize(outputs["VCF"]) > 0
	end
)

program_vcf_classifier_generate_db = CmdProgram(
	name = "VCF Classifier - Generating Database VCF",
	id_file = ".vcf-classifier-gen-db",
	cmd_dependencies = [julia],
	inputs = [
		"VCF_FILES",
		"LABELS",
		"MIN_PROB" => 0.05 => Float64
	],
	outputs = [
		"DB_VCF" => String,
		"SAMPLE_RESULTS" => "<input>.classifier" => String
	],
	cmd = `$julia $vcf_classifier --generate-db-vcf --all-positions --db-vcf DB_VCF -o SAMPLE_RESULTS --labels LABELS --inputs VCF_FILES --min-prob MIN_PROB`
)

program_vcf2mlst = JuliaProgram(
	name = "VCF to Clasnip MLST",
	id_file = ".vcf-classifier-vcf2mlst",
	inputs = [
		"VCF",
		"DB_VCF_JLD2",
		"OUT_PREFIX" => "<VCF>.mlst",
		"keep_mlst" => false => Bool
	],
	outputs = [
		"MLST_ALL_TABLE" => "<OUT_PREFIX>.all.txt",
		"MLST_PARTIAL_TABLE" => "<OUT_PREFIX>.partial.txt",
		"MLST_RES_TABLE" => "<OUT_PREFIX>.classification_result.txt",
		"mlst" => false,
		"identity_res" => false
	],
	main = (in, out) -> begin
		out, mlst, identity_res = ClasnipPipeline.clasnip_vcf2mlst(in["VCF"], in["DB_VCF_JLD2"]; outprefix=in["OUT_PREFIX"])
		out = convert(Dict{String,Any}, out)
		out["mlst"] = in["keep_mlst"] ? mlst : false
		out["identity_res"] = identity_res
		out
	end
)
program_vcf2mlst_with_cv_db = JuliaProgram(
	name = "VCF to Clasnip MLST (CV)",
	id_file = ".vcf-classifier-vcf2mlst",
	inputs = [
		"VCF",
		"db_vcf_jld2_path_AB" => String,
		"db_reverse" => Bool,
		"OUT_PREFIX" => "<VCF>.mlst",
		"keep_mlst" => false => Bool
	],
	outputs = [
		"MLST_ALL_TABLE" => "<OUT_PREFIX>.all.txt",
		"MLST_PARTIAL_TABLE" => "<OUT_PREFIX>.partial.txt",
		"MLST_RES_TABLE" => "<OUT_PREFIX>.classification_result.txt",
		"mlst" => false,
		"identity_res" => false
	],
	main = (in, out) -> begin
		out, mlst, identity_res = ClasnipPipeline.clasnip_vcf2mlst_with_cv_db(in["VCF"], in["db_vcf_jld2_path_AB"]; db_reverse=in["db_reverse"], outprefix=in["OUT_PREFIX"])
		out = convert(Dict{String,Any}, out)
		out["mlst"] = in["keep_mlst"] ? mlst : false
		out["identity_res"] = identity_res
		out
	end
)

program_clasnip_db_quality_assess = JuliaProgram(
	name = "Clasnip Database Quality Assessment",
	id_file = ".clasnip-db-qa",
	inputs = [
		"VCF2MLST_JOBS" => Vector{Job},
		"LABELS" => Vector{String},
		"OUTDIR" => "." => AbstractString,
		"DB_VCF_JLD2" => "" => AbstractString,
		"COVERAGE_CUTOFF" => 5.0 => Real
	],
	outputs = [
		"IDENTITY_DISTRIBUTIONS" => "",
		"DATA_IDENTITY_SCORES" => "",
		"STAT_WRONG_CLASSIFIED" => "",
		"STAT_LOW_COVERAGES" => "",
		"STAT_ACCURACY_AND_IDENTITY" => "",
		"PLOT_ROC" => String[],
		"STAT_CLASSIFIER_PERFORMANCE" => "",
		"PLOT_DENSITIES" => String[],
		"STAT_HEATMAP_IDENTITY" => "",
		"PLOT_HEATMAP_IDENTITY" => "",
		"STAT_PAIRWISE_SNP_SCORE" => "",
		"STAT_PAIRWISE_SNP_SCORE_NAME_ORDERED" => "",
		"PLOT_HEATMAP_SNP_SCORE" => ""
	],
	prerequisites = (i, o) -> begin
		mkpath(i["OUTDIR"], mode = 0o755)
	end,

	main = (i, o) -> begin
		vcf2mlst_jobs = i["VCF2MLST_JOBS"]
		labels = i["LABELS"]
		outdir = i["OUTDIR"]
		db_vcf = i["DB_VCF_JLD2"]
		coverage_cutoff = i["COVERAGE_CUTOFF"]

		identity_results = map(vcf2mlst_jobs) do job
		   res = result(job)[2]
		   res["identity_res"]
	    end
		clasnip_db_quality_assess(labels, identity_results, outdir=outdir, db_vcf=db_vcf, coverage_cutoff=coverage_cutoff)
	end
)

program_clasnip_db_cross_validation_wrapper = JuliaProgram(
	name = "Wrapper of Clasnip Database Cross Validation",
	id_file = ".clasnip-db-cv-wrapper",
	inputs = [
		"DB_VCF_PATH" => AbstractString,
		"MIN_PROB" => 0.05 => Float64,
		"USER" => "",
		"REPEAT" => 3 => Int
	],
	outputs = "CV_SUMMARY_JOB" => "",
	main = (i, o) -> begin
		cv_summary_job = clasnip_db_cross_validation_wrapper(i["DB_VCF_PATH"]; min_prob = i["MIN_PROB"], user = i["USER"], repeat = i["REPEAT"])
		o["CV_SUMMARY_JOB"] = cv_summary_job
		return o
	end
)

program_clasnip_db_cross_validation_summary = JuliaProgram(
	name = "Clasnip Database Cross Validation Summary",
	id_file = ".clasnip-db-cv-summary",
	inputs = [
		"DB_QA_JOBS" => Vector{Job},
		"OUTDIR" => "." => AbstractString
	],
	outputs = [
		"TRAINING_SUMMARY" => "" => AbstractString,
		"TEST_SUMMARY" => "" => AbstractString
	],
	main = (i, o) -> begin
		db_qa_jobs = i["DB_QA_JOBS"]
		outdir = i["OUTDIR"]
		classifier_performance_paths = [result(db_qa_job)[2]["STAT_CLASSIFIER_PERFORMANCE"] for db_qa_job in db_qa_jobs]
		training_summary, test_summary = clasnip_db_cross_validation_summary(classifier_performance_paths::Vector, outdir::AbstractString)
		return Dict(
			"TRAINING_SUMMARY" => training_summary,
			"TEST_SUMMARY" => test_summary
		)
	end
)
