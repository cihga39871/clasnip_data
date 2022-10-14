
function get_fasta_analysis_dir(db_dir)
	extracted = abspath(db_dir, "extracted")
	if isdir(extracted)
		subs = readdir(extracted, join = true)
		if length(subs) == 1 && isdir(subs[1])
			return subs[1]
		else
			return extracted
		end
	else
		return db_dir
	end
end
"""
	clasnip_db_cross_validation_wrapper(
	    db_vcf_path::AbstractString;
		fasta_analysis_dir::AbstractString = get_fasta_analysis_dir(dirname(db_vcf_path)),
	    stats_low_coverages_path::AbstractString = abspath(dirname(db_vcf_path), "stat.low_coverages.txt"),
	    repeat::Int = 3,
	    min_prob::Float64 = 0.05,
		user = user
	)

Stratified 2-fold cross-validation for Clasnip database after creation of full database.

- `db_vcf_path`: the path to db_vcf file (.db-vcf)
- `stats_low_coverages_path`: file named stat.low_coverages.txt
- `repeat`: number of repeat of random sampling.
- `min_prob`: for each group at each location, if the probability of the SNP is less tham `min_prob`, the SNP will be removed.

Return path of cross-validation databases in JLD2 format with the following variables:

    db_vcf_parsed_A, db_vcf_parsed_B,
    groups_AB      ,
    group_A_dict   , group_B_dict   ,
    nsample_group_A, nsample_group_B,
    samples_A      , samples_B
"""
function clasnip_db_cross_validation_wrapper(
    db_vcf_path::AbstractString;
    fasta_analysis_dir::AbstractString=get_fasta_analysis_dir(dirname(db_vcf_path)),
    stats_low_coverages_path::AbstractString=abspath(dirname(db_vcf_path), "stat.low_coverages.txt"),
	reference_index_path = infer_reference_index_path(dirname(db_vcf_path)),
    repeat::Int=3,
    min_prob::Float64=0.05,
    user=user
)
    #=
    	using JLD2
    	using Plots
    	using AverageShiftedHistograms
    	using StatsPlots
        db_vcf_path = "/home/jiacheng/ClasnipWebData/database/clso_cv_16s/database.jl-v1.7.2.db-vcf"
    	db_vcf_path = "/home/jc/ClasnipWebData/database/precompile_test/database.jl-v1.7.2.db-vcf"
    	fasta_analysis_dir = ClasnipPipeline.get_fasta_analysis_dir(dirname(db_vcf_path))
    	stats_low_coverages_path = abspath(dirname(db_vcf_path), "stat.low_coverages.txt")
		reference_index_path = infer_reference_index_path(dirname(db_vcf_path))
    	# cd(dirname(db_vcf_path))
    	repeat = 3
    	min_prob = 0.05
    	n_repeat = 1
    	user = ""
    	try
    		pwd()
    	catch
    		cd(Config.PROJECT_ROOT_FOLDER)
    	end
    =#

	@info Pipelines.timestamp() * "clasnip_db_cross_validation_wrapper" db_vcf_path fasta_analysis_dir reference_index_path

    low_coverages = CSV.read(stats_low_coverages_path, DataFrame; ntasks=1, stringtype=String)
    low_coverage_samples = Set(low_coverages.LABEL)

    db_vcf_jld2_path = db_vcf_path * ".reduced.jld2"
    @load db_vcf_jld2_path group_dict nsample_group

    # remove low covered samples from db_vcf
    for label in low_coverage_samples
        group, sample = split(label, '/')
        filter!(x -> x != sample, group_dict[group])
        nsample_group[group] -= 1
    end
    # db_vcf = ClasnipPipeline.vcf_load(db_vcf_path)
    # filter!(:SAMPLE => (x -> !(x in low_coverage_samples)), db_vcf)

    db_vcf_jld2_path_ABs = String[]
    db_qa_jobs = Job[]

    outdir = dirname(db_vcf_path)
    log_io = open(joinpath(outdir, "cross-validation.log"), "w+")
    
	for n_repeat in 1:repeat
		@info Pipelines.timestamp() * "Started: Generating Clasnip DB for Cross Validation #$(n_repeat)"
		group_A_dict, group_B_dict, nsample_group_A, nsample_group_B = stratifed_split(group_dict, nsample_group)

		samples_A = group_dict_to_labels(group_A_dict)
		samples_B = group_dict_to_labels(group_B_dict)

		vcf_paths_A = [joinpath(fasta_analysis_dir, label) * ".fq.bam.all.vcf" for label in samples_A]
		vcf_paths_B = [joinpath(fasta_analysis_dir, label) * ".fq.bam.all.vcf" for label in samples_B]
		# generate_parsed_clasnip_db(inputs, labels, reference_index_path; min_prob::Float64=0.05)

		db_vcf_parsed_A, groups_AB, group_A_dict, nsample_group_A = generate_parsed_clasnip_db(vcf_paths_A, collect(samples_A), reference_index_path; min_prob=0.05)

		db_vcf_parsed_B, groups_AB, group_B_dict, nsample_group_B = generate_parsed_clasnip_db(vcf_paths_B, collect(samples_B), reference_index_path; min_prob=0.05)

		db_vcf_jld2_path_AB = "$db_vcf_path.cross-validation.$(n_repeat).jld2"
		push!(db_vcf_jld2_path_ABs, db_vcf_jld2_path_AB)

		@info Pipelines.timestamp() * "Saving parsed db vcf (cross-validation #$(n_repeat))"

		db_vcf_parsed_A = ClasnipPipeline.parsed_db_vcf_to_mlst!(db_vcf_parsed_A::DataFrame, groups_AB::Vector)
		db_vcf_parsed_B = ClasnipPipeline.parsed_db_vcf_to_mlst!(db_vcf_parsed_B::DataFrame, groups_AB::Vector)

		unique_reference_for_db_vcf_parsed!(db_vcf_parsed_A)
		unique_reference_for_db_vcf_parsed!(db_vcf_parsed_B)

		cv_db = ClasnipPipeline.ClasnipCvDb(db_vcf_jld2_path_AB,
			db_vcf_parsed_A, db_vcf_parsed_B,
			groups_AB,
			group_A_dict, group_B_dict,
			nsample_group_A, nsample_group_B,
			samples_A, samples_B, fasta_analysis_dir
		)
		@save db_vcf_jld2_path_AB cv_db

		ClasnipPipeline.clasnip_cache_cv_database(cv_db, reload=true) # save cv_db to cache CLASNIP_CV_DB

		# cross validation
		db_qa_job_train_ab, db_qa_job_test_ab = clasnip_db_cross_validation(
			db_vcf_jld2_path_AB;
			db_reverse=false,
			outdir=replaceext(db_vcf_jld2_path_AB, "analysis-AB"),
			user=user, log_io=log_io
		)
		db_qa_job_train_ba, db_qa_job_ba = clasnip_db_cross_validation(
			db_vcf_jld2_path_AB;
			db_reverse=true,
			outdir=replaceext(db_vcf_jld2_path_AB, "analysis-BA"),
			user=user, log_io=log_io
		)
		push!(db_qa_jobs, db_qa_job_train_ab)
		push!(db_qa_jobs, db_qa_job_test_ab)
		push!(db_qa_jobs, db_qa_job_train_ba)
		push!(db_qa_jobs, db_qa_job_ba)

		# unload database after all job past
		unload_cv_job = Job(
			() -> ClasnipPipeline.clasnip_unload_cv_database(db_vcf_jld2_path_AB),
			name="Unload CV DB",
			user=user,
			dependency=[
				PAST => db_qa_job_train_ab,
				PAST => db_qa_job_test_ab,
				PAST => db_qa_job_train_ba,
				PAST => db_qa_job_ba
			])
		submit!(unload_cv_job)
	end

    cv_summary_deps = [DONE => x for x in db_qa_jobs]
    input_cv_summary = Dict(
        "DB_QA_JOBS" => db_qa_jobs,
        "OUTDIR" => dirname(db_vcf_path)
    )
    common_kwargs = (dir=outdir, stdout=log_io, stderr=log_io, stdlog=log_io, append=true, user=user, verbose=:min)
    cv_summary_job = Job(ClasnipPipeline.program_clasnip_db_cross_validation_summary, input_cv_summary; dependency=cv_summary_deps, common_kwargs...)
    submit!(cv_summary_job)

    close_in_future(log_io, cv_summary_job)
    return cv_summary_job
end


function stratifed_split(group_dict::Dict, nsample_group::Dict; training_percent::Float64 = 0.5)
    # remove group with only one sample
    group_dict = filter(x -> length(x.second) > 1, group_dict)

    group_A_dict = typeof(group_dict)()
    group_B_dict = typeof(group_dict)()
    nsample_group_A = typeof(nsample_group)()
    nsample_group_B = typeof(nsample_group)()

    for (group, samples) in group_dict
        nsample = length(samples)
        idx = randperm(nsample)
        split_at = Int(rand([ceil, floor])(training_percent * nsample))
        if split_at == 0
            split_at += 1
        elseif nsample == split_at
            split_at -= 1
        end
        A = samples[view(idx, 1:split_at)]
        B = samples[view(idx, split_at + 1:nsample)]
        group_A_dict[group] = A
        group_B_dict[group] = B
        nsample_group_A[group] = split_at
        nsample_group_B[group] = nsample - split_at
    end
    group_A_dict, group_B_dict, nsample_group_A, nsample_group_B
end

function group_dict_to_labels(group_dict::Dict)
    labels = eltype(group_dict).types[2]()  # vector
    for (group, samples) in group_dict
        for sample in samples
            push!(labels, group * "/" * sample)
        end
    end
    Set(labels)
end

"""
    clasnip_db_cross_validation(
        db_vcf_jld2_path_AB,
        db_vcf_parsed_A, db_vcf_parsed_B,
        groups_AB,
        group_A_dict, group_B_dict,
        nsample_group_A, nsample_group_B,
        samples_A, samples_B
    )

A = training set. B = test set.
"""
function clasnip_db_cross_validation(
    db_vcf_jld2_path_AB;
	db_reverse::Bool = false,
    outdir = replaceext(db_vcf_jld2_path_AB, "analysis"),
    user = "",
	log_io = nothing
)
	@info Pipelines.timestamp() * "clasnip_db_cross_validation" outdir user
	# prepare
    mkpath(outdir, mode=0o755)
    common_kwargs = (dir = outdir, stdout = log_io, stderr = log_io, stdlog = log_io, append = true, user = user, verbose = :min)

	cv_db = ClasnipPipeline.get_clasnip_cv_db(db_vcf_jld2_path_AB);
	### test dataset
    # Clasnip classification using new fasta and db
	# find fasta location
    vcf2mlst_jobs = Job[]
    for fasta in cv_db.samples_B
        vcf_path = joinpath(cv_db.fasta_analysis_dir, fasta * ".fq.bam.all.vcf")
        outprefix = joinpath(outdir, fasta * ".fq.bam.all.vcf.mlst")
        in_vcf2mlst = Dict(
            "VCF" => vcf_path,
            "db_vcf_jld2_path_AB" => db_vcf_jld2_path_AB,
			"db_reverse" => db_reverse,
            "OUT_PREFIX" => outprefix
        )
		if isempty(vcf2mlst_jobs)
			j = Job(ClasnipPipeline.program_vcf2mlst_with_cv_db, in_vcf2mlst; ncpu = 2, mem = 2GB, common_kwargs...)
		else
			j = Job(ClasnipPipeline.program_vcf2mlst_with_cv_db, in_vcf2mlst; ncpu = 2, mem = 2GB, dependency = [PAST => vcf2mlst_jobs[1]], common_kwargs...)
		end
        push!(vcf2mlst_jobs, j)
    end
    submit!.(vcf2mlst_jobs)

	yield()

	# db QA
	identity_stats_deps = [DONE => x for x in vcf2mlst_jobs]
    in_db_qa = Dict(
        "VCF2MLST_JOBS" => vcf2mlst_jobs,
        "LABELS" => collect(cv_db.samples_B),
        "OUTDIR" => joinpath(outdir, db_reverse ? "training_performance" : "test_performance"),
        "DB_VCF_JLD2" => ""  # not provided = do not count pairwise SNP
    )
	#=
	i=in_db_qa
	vcf2mlst_jobs = i["VCF2MLST_JOBS"]
	labels = i["LABELS"]
	outdir = i["OUTDIR"]
	db_vcf = i["DB_VCF_JLD2"]
	coverage_cutoff = 5.0

	identity_results = map(vcf2mlst_jobs) do job
	   res = result(job)[2]
	   res["identity_res"]
	end
	group = "A"

	using Clustering, Distances
	clasnip_db_quality_assess(labels, identity_results, outdir=outdir, db_vcf=db_vcf, coverage_cutoff=coverage_cutoff)

	## OR
	db_vcf_jld2_path_AB = "/home/jiacheng/ClasnipWebData/database/precompile_test/database.jl-v1.7.2.db-vcf.cross-validation.3.jld2"
	labels = ["A/MK726036.1.16S.CLso-HA.fasta", "B/MK726037.1.16S.CLso-HB.fasta", "B/KU588194.1.16S.CLso-HB.fasta", "A/MK726035.1.16S.CLso-HA.fasta", "D/MH061376.1.16S.CLso-HD.fasta", "B/KU588195.1.16S.CLso-HB.fasta", "D/MG911712.1.16S.CLso-HD.fasta", "A/KR935886.1.16S.CLso-HA.fasta", "B/MK726033.1.16S.CLso-HB.fasta", "D/KX163276.1.16S.CLso-HD.fasta"]
	outdir = "/home/jiacheng/ClasnipWebData/database/precompile_test/database.jl-v1.7.2.db-vcf.cross-validation.3.analysis-BA/test_performance"
	db_vcf = ""
	coverage_cutoff = 5.0

	identity_results = map(labels) do label
	   res_txt = abspath(outdir, "..", label * ".fq.bam.all.vcf.mlst.classification_result.txt")
	   df = CSV.read(res_txt, DataFrame)
	end

	using Clustering, Distances
	clasnip_db_quality_assess(labels, identity_results, outdir=outdir, db_vcf=db_vcf, coverage_cutoff=coverage_cutoff)
	=#
    db_qa_job = Job(ClasnipPipeline.program_clasnip_db_quality_assess, in_db_qa; dependency = identity_stats_deps, common_kwargs...)
	submit!(db_qa_job)


	### training dataset
	vcf2mlst_jobs_train = Job[]
	for fasta in cv_db.samples_A
		vcf_path = joinpath(cv_db.fasta_analysis_dir, fasta * ".fq.bam.all.vcf")
		outprefix = joinpath(outdir, fasta * ".fq.bam.all.vcf.mlst")
		in_vcf2mlst = Dict(
            "VCF" => vcf_path,
            "db_vcf_jld2_path_AB" => db_vcf_jld2_path_AB,
			"db_reverse" => db_reverse,
            "OUT_PREFIX" => outprefix
        )
		if isempty(vcf2mlst_jobs_train)
			j = Job(ClasnipPipeline.program_vcf2mlst_with_cv_db, in_vcf2mlst; ncpu = 2, mem = 2GB, common_kwargs...)
		else
			j = Job(ClasnipPipeline.program_vcf2mlst_with_cv_db, in_vcf2mlst; ncpu = 2, mem = 2GB, dependency = [PAST => vcf2mlst_jobs_train[1]], common_kwargs...)
		end
		push!(vcf2mlst_jobs_train, j)
	end
	submit!.(vcf2mlst_jobs_train)

	yield()

	# db QA
	identity_stats_deps = [DONE => x for x in vcf2mlst_jobs_train]
	in_db_qa = Dict(
		"VCF2MLST_JOBS" => vcf2mlst_jobs_train,
		"LABELS" => collect(cv_db.samples_A),
		"OUTDIR" => joinpath(outdir, db_reverse ? "test_performance" : "training_performance"),
		"DB_VCF_JLD2" => ""  # not provided = do not count pairwise SNP
	)
	db_qa_job_train = Job(ClasnipPipeline.program_clasnip_db_quality_assess, in_db_qa; dependency = identity_stats_deps, common_kwargs...)
	submit!(db_qa_job_train)

	return db_qa_job_train, db_qa_job # train and test
end

function clasnip_db_cross_validation_summary(classifier_performance_paths::Vector, outdir::AbstractString)
	@info Pipelines.timestamp() * "clasnip_db_cross_validation_summary" outdir
	
	training_paths = filter(x -> occursin("/training_performance/", x), classifier_performance_paths)
	test_paths = filter(x -> occursin("/test_performance/", x), classifier_performance_paths)

	training_summary = joinpath(outdir, "stat.classifier_performance.training.txt")
	test_summary = joinpath(outdir, "stat.classifier_performance.test.txt")

	ReplicateStats.replicate_stats(training_paths, training_summary)
	ReplicateStats.replicate_stats(test_paths, test_summary)

	return training_summary, test_summary
end
