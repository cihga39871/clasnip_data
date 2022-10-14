# only allow to use plot for one thread at the same time
# otherwise error might be thrown.
PLOT_LOCK = SpinLock()

"""
    clasnip_db_build(fastas::Vector{String}, labels::Vector{String}, ref::String, db_prefix::String = joinpath(dirname(ref), splitext(basename(ref))[1] * ".jl-v$VERSION.db-vcf"); working_dir = "", outdir = working_dir, user = "", do_cross_validation::Bool = false)

- `fastas`: file path of fasta files. (full path)

- `labels`: GROUP/SAMPLE of fastas.

- `ref`: the reference genome/fasta. (full path)

- `db_prefix`: database output prefix. (full path)

- `working_dir`: the working dir to build clasnip database.

- `outdir`: the dir to output clasnip data, stats and plots.
"""
function clasnip_db_build(fastas::Vector{String}, labels::Vector{String}, ref::String, db_prefix::String = joinpath(dirname(ref), splitext(basename(ref))[1] * ".jl-v$VERSION.db-vcf"); working_dir = "", outdir = working_dir, user = "", do_cross_validation::Bool = false)

    @static if false
        cd("/usr/database/processed/CLso_genes/CLso_12haplotypes_corrected")
        groups = filter(isdir, readdir())
        fastas = readlines(pipeline(`find $groups -type f`, `grep -E "fasta\$"`, `grep -v all.fasta`))
        labels = fastas
        ref = "/usr/database/processed/polychrome_classifier/genomes/Liberibacter/Candidatus_Liberibacter_solanacearum/HB/GCA_000183665.1_ASM18366v1/GCA_000183665.1_ASM18366v1_genomic.fasta"
        ref = "B/GCA_000183665.1_ASM18366v1_genomic.fasta"
        db_prefix = splitext(basename(ref))[1] * ".jl-v$VERSION.db-vcf"
        outdir = working_dir = pwd()
        user = "test"
        clasnip_db_build(fastas, labels, ref, db_prefix)

        cd("/home/jiacheng/analysis/CLso_12haplotypes_corrected5_clasnip_db/extracted")
        groups = filter(isdir, readdir())
        labels = fastas = readlines(pipeline(`find $groups -type f`, `grep -E "fasta\$"`, `grep -v all.fasta`))
        ref = "F/MH259699.1.16S.CLso-HF.fasta"
        db_prefix = splitext(basename(ref))[1] * ".jl-v$VERSION.db-vcf"
        outdir = working_dir = pwd()
        user = "test"
    end

    working_dir = abspath(working_dir)
    outdir = abspath(outdir)

    @info Pipelines.timestamp() * "clasnip_db_build" db_prefix working_dir outdir user do_cross_validation

    isdir(working_dir) || mkpath(working_dir, mode = 0o755)
    isdir(outdir) || mkpath(outdir, mode = 0o755)

    log_io = open(joinpath(outdir, "build.log"), "w+")
    if Config.JOB_LOGS_TO_STD
	    common_kwargs = (stdout = Pipelines.stdout_origin, stderr = Pipelines.stdout_origin, stdlog = nothing, user = user, verbose = :min)
    else
	    common_kwargs = (stdout = log_io, stderr = log_io, stdlog = log_io, append = true, user = user, verbose = :min)
    end

    ### fasta to fastq
    # run the first job to precompile (if not compiled)
    fa2fq_job = Job(ClasnipPipeline.program_fa2fq, "FASTA" => fastas[1]; dir = working_dir, common_kwargs...)
    submit!(fa2fq_job)

    fa2fq_jobs = [Job(ClasnipPipeline.program_fa2fq, "FASTA" => f; dir = working_dir, dependency = [DONE => fa2fq_job], common_kwargs...) for f in fastas[2:end]]
    submit!.(fa2fq_jobs)

    pushfirst!(fa2fq_jobs, fa2fq_job)

    yield()

    ### mapping to ref
    bowtie2_jobs = Job[]
    for (i, job) in enumerate(fa2fq_jobs)
        in_bowtie2 = Dict(
            "REF" => ref,
            "FASTQ" => fastas[i] * ".fq"
        )
        bowtie2_job = Job(ClasnipPipeline.program_bowtie2, in_bowtie2; dependency = [DONE => job], dir = working_dir, common_kwargs...)
        push!(bowtie2_jobs, bowtie2_job)
    end
    submit!.(bowtie2_jobs)

    yield()

    ### SNP calling
    snp_jobs = Job[]
    for (i, job) in enumerate(bowtie2_jobs)
        in_snp = Dict(
            "REF" => ref,
            "BAM" => fastas[i] * ".fq.bam"
        )
        snp_job = Job(ClasnipPipeline.program_freebayes, in_snp; dependency = [DONE => job], dir = working_dir, common_kwargs...)
        push!(snp_jobs, snp_job)
    end
    submit!.(snp_jobs)

    yield()

    # Run vcf_classifier: generate db vcf mode:
    job_deps = [DONE => x for x in snp_jobs]
    in_gen_db = Dict(
        "VCF_FILES" => `$fastas.fq.bam.all.vcf`,
        "LABELS" => labels,
        "REF_INDEX" => ref * ".fai",
    )
    out_gen_db = Dict("DB_VCF" => db_prefix)
    gen_db_job = Job(ClasnipPipeline.program_vcf_classifier_generate_db, in_gen_db, out_gen_db; dependency = job_deps, dir = working_dir, mem = 12GB, ncpu = 5, common_kwargs...)
    submit!(gen_db_job)

    yield()

    ## Clasnip classification using new fasta and db
    vcf2mlst_deps = [DONE => gen_db_job]
    vcf2mlst_jobs = Job[]

    # run the fist sample to precompile
    in_vcf2mlst = Dict(
        "VCF" => fastas[1] * ".fq.bam.all.vcf",
        "DB_VCF_JLD2" => db_prefix * ".reduced.jld2",
        "WRITE_MLST" => false
    )
    vcf2mlst_job = Job(ClasnipPipeline.program_vcf2mlst, in_vcf2mlst; dependency = vcf2mlst_deps, dir = working_dir, ncpu = 2, mem = 2GB, common_kwargs...)
    submit!(vcf2mlst_job)

    # rest samples
    for fasta in fastas[2:end]
        in_vcf2mlst = Dict(
            "VCF" => fasta * ".fq.bam.all.vcf",
            "DB_VCF_JLD2" => db_prefix * ".reduced.jld2",
            "WRITE_MLST" => false
        )
        push!(vcf2mlst_jobs, Job(ClasnipPipeline.program_vcf2mlst, in_vcf2mlst; dependency = [DONE => vcf2mlst_job], dir = working_dir, ncpu = 2, mem = 2GB, common_kwargs...))
    end
    submit!.(vcf2mlst_jobs)

    pushfirst!(vcf2mlst_jobs, vcf2mlst_job)

    yield()

    identity_stats_deps = [DONE => x for x in vcf2mlst_jobs]
    in_db_qa = Dict(
        "VCF2MLST_JOBS" => vcf2mlst_jobs,
        "LABELS" => labels,
        "OUTDIR" => outdir,
        "DB_VCF_JLD2" => db_prefix * ".reduced.jld2"
    )
    db_qa_job = Job(ClasnipPipeline.program_clasnip_db_quality_assess, in_db_qa; dependency = identity_stats_deps, dir = outdir, common_kwargs...)
    submit!(db_qa_job)
	close_in_future(log_io, db_qa_job) # close

	last_job = db_qa_job

    if do_cross_validation
        in_db_cv = Dict(
	        "DB_VCF_PATH" => db_prefix,
			"USER" => user
        )
		db_cv_job = Job(ClasnipPipeline.program_clasnip_db_cross_validation_wrapper, in_db_cv; dependency = [DONE => db_qa_job], dir = outdir, common_kwargs...)
		submit!(db_cv_job)
		last_job = db_cv_job
    end

	return last_job
end

function clasnip_db_build(fastas::Vector{String}, label_regex::Regex, ref::String, db_prefix::String = splitext(basename(ref))[1] * ".jl-v$VERSION.db-vcf")
    labels = map(fastas) do input
        m = match(label_regex, input)
        if isnothing(m)
            throw(ErrorException("LABELS::Regex failed to match one of fasta files: $input"))
        else
            length(m.captures) == 0 ? m.match : join(m.captures, "/")
        end
    end
    clasnip_db_build(fastas, labels, ref, db_prefix)
end

"""
    clasnip_db_quality_assess(labels::Vector{String}, identity_results::Vector{DataFrame}; outdir::AbstractString = ".", db_vcf::AbstractString = "", coverage_cutoff::Real = 5.0)

Database quality assessment, including generating P value models.

- `labels`: labels of samples

- `identity_results`: dataframes of identity result tables

- `outdir`: output directory

- `db_vcf`: database file ending with db-vcf.reduced.jld2

- `coverage_cutoff`: if a sample's coverage of its labeled group is less than NUMBER, the sample is excluded in db quality assessment.
"""
function clasnip_db_quality_assess(labels::Vector{String}, identity_results::Vector{DataFrame}; outdir::AbstractString = ".", db_vcf::AbstractString = "", coverage_cutoff::Real = 5.0)

    outdir = abspath(outdir)
    isdir(outdir) || mkpath(outdir, mode = 0o755)

    @info Pipelines.timestamp() * "clasnip_db_quality_assess" outdir

    outfiles = Dict{String, Any}()
    nsample = length(labels)

    if nsample != length(identity_results)
        error("Lengths of vector arguments not same!")
    end

    # generating identity results for all samples
    @info Pipelines.timestamp() * "clasnip_db_quality_assess: generating identity results for all samples" outdir
    for i in 1:nsample
        label = labels[i]
        identity_res = identity_results[i]
        real_group = String(split(label, "/")[1])
        rank_for_enough_coverage = identity_res.PERCENT_MATCHED .* (identity_res.COVERED_SNP_SCORE .> coverage_cutoff)
        identity_res[!, :RANK] = denserank(rank_for_enough_coverage, rev=true)
        identity_res[!, :TIED_RANK] = tiedrank(rank_for_enough_coverage, rev=true)
        identity_res[!, :LABELED_GROUP] .= real_group
        identity_res[!, :SAME] = identity_res.GROUP .== identity_res.LABELED_GROUP
        identity_res[!, :LABEL] .= label
    end

    all_identity_res = vcat(identity_results...)

    ### stats: identity distribution for each labeled group
    # using AverageShiftedHistograms
    @info Pipelines.timestamp() * "clasnip_db_quality_assess: identity distribution for each labeled group" outdir
    self_identity_res_cvg = @subset(all_identity_res, :SAME .== true, :COVERED_SNP_SCORE .>= coverage_cutoff)
    gdf_self_identity_res_cvg = groupby(self_identity_res_cvg, :LABELED_GROUP)
    identity_distributions = Dict{String, AverageShiftedHistograms.Ash}()
    for df in gdf_self_identity_res_cvg
        group = df.LABELED_GROUP[1]
        identities = sort(df.PERCENT_MATCHED)
        # ash: a fast kernel estimation. m = Number of adjacent histograms to smooth over
        dist = AverageShiftedHistograms.ash(identities, rng = 0:0.001:1, m = 100)
        # use AverageShiftedHistograms.cdf(dist, value) to estimate probability
        identity_distributions[group] = dist
    end
    # saved as jld2 after stats: overall accuracy


    ### compute probability based on identity distributions
    @info Pipelines.timestamp() * "clasnip_db_quality_assess: compute probability based on identity distributions" outdir
    @rtransform!(all_identity_res,
        # :P_VALUE = cumulated_density(identity_distributions, :GROUP, :PERCENT_MATCHED)
        :CDF = ClasnipPipeline.cumulated_density(identity_distributions, :GROUP, :PERCENT_MATCHED)
    )

    ### compute normalized probability for all sample
    @info Pipelines.timestamp() * "clasnip_db_quality_assess: compute normalized probability for all sample" outdir
    gdf_sample_identity_res = groupby(all_identity_res, :LABEL)
    @transform!(gdf_sample_identity_res,
        :PROBABILITY = ClasnipPipeline.value_normalize(:CDF)
    )

    outfiles["DATA_IDENTITY_SCORES"] = joinpath(outdir, "data.identity_scores.txt")
    CSV.write(outfiles["DATA_IDENTITY_SCORES"], all_identity_res, delim='\t')

    ### Get identity GROUP == LABELED_GROUP
    self_identity_res = @subset(all_identity_res, :SAME .== true)

    ### stats: wrongly classified samples
    @info Pipelines.timestamp() * "clasnip_db_quality_assess: find wrongly classified samples" outdir
    wrongly_classified = @subset(self_identity_res, :RANK .!= 1)
    outfiles["STAT_WRONG_CLASSIFIED"] = joinpath(outdir, "stat.wrongly_classified.txt")
    CSV.write(outfiles["STAT_WRONG_CLASSIFIED"], wrongly_classified, delim='\t')

    ### stats: low coverage samples
    @info Pipelines.timestamp() * "clasnip_db_quality_assess: find low coverage samples" outdir
    low_coverages = @subset(self_identity_res, :COVERED_SNP_SCORE .< coverage_cutoff)
    outfiles["STAT_LOW_COVERAGES"] = joinpath(outdir, "stat.low_coverages.txt")
    CSV.write(outfiles["STAT_LOW_COVERAGES"], low_coverages, delim='\t')

    ### stats: accuracy and identity
    @info Pipelines.timestamp() * "clasnip_db_quality_assess: compute accuracy and identity" outdir
	if nrow(self_identity_res_cvg) > 0
		accuracy_and_identity = @chain self_identity_res begin
	        @subset(:COVERED_SNP_SCORE .>= coverage_cutoff)
	        groupby([:LABELED_GROUP])
	        @combine(:N_SAMPLE = length(:LABEL),
	                 :N_ACCURATE = sum(:RANK .== 1),
	                 :IDENTITY_Q5 = quantile(skipmissing(:PERCENT_MATCHED), 0.05),
	                 :IDENTITY_Q25 = quantile(skipmissing(:PERCENT_MATCHED), 0.25),
	                 :IDENTITY_MEDIAN = quantile(skipmissing(:PERCENT_MATCHED), 0.50)
	        )
	        @transform!(:TRUE_POSITIVE_RATE = :N_ACCURATE ./ :N_SAMPLE)
	    end
	else
		# Fall back. Do not remove low covered samples
		accuracy_and_identity = @chain self_identity_res begin
	        groupby([:LABELED_GROUP])
	        @combine(:N_SAMPLE = length(:LABEL),
	                 :N_ACCURATE = sum(:RANK .== 1),
	                 :IDENTITY_Q5 = quantile(skipmissing(:PERCENT_MATCHED), 0.05),
	                 :IDENTITY_Q25 = quantile(skipmissing(:PERCENT_MATCHED), 0.25),
	                 :IDENTITY_MEDIAN = quantile(skipmissing(:PERCENT_MATCHED), 0.50)
	        )
	        @transform!(:TRUE_POSITIVE_RATE = :N_ACCURATE ./ :N_SAMPLE)
	    end
	end



    outfiles["STAT_ACCURACY_AND_IDENTITY"] = joinpath(outdir, "stat.accuracy_and_identity.txt")
    CSV.write(outfiles["STAT_ACCURACY_AND_IDENTITY"], accuracy_and_identity, delim='\t')

    # stats: overall accuracy
    @info Pipelines.timestamp() * "clasnip_db_quality_assess: compute overall accuracy" outdir
    db_accuracy = sum(accuracy_and_identity.N_ACCURATE) / sum(accuracy_and_identity.N_SAMPLE)
    outfiles["IDENTITY_DISTRIBUTIONS"] = joinpath(outdir, "stat.identity_distributions.jld2")
    @save outfiles["IDENTITY_DISTRIBUTIONS"] identity_distributions db_accuracy

    ### stats: ROC and more classifier performance metrics
    @info Pipelines.timestamp() * "clasnip_db_quality_assess: compute classifier_performance" outdir
    df_performance = ClasnipPipeline.classifier_performance(all_identity_res, outdir)
    outfiles["PLOT_ROC"] = []
    outfiles["STAT_CLASSIFIER_PERFORMANCE"] = joinpath(outdir, "stat.classifier_performance.txt")
    CSV.write(outfiles["STAT_CLASSIFIER_PERFORMANCE"], df_performance, delim='\t')


    ### density plots for each group
    @info Pipelines.timestamp() * "clasnip_db_quality_assess: density plots for each group" outdir
    all_identity_res_cvg = @subset(all_identity_res, :COVERED_SNP_SCORE .>= coverage_cutoff)
    gdf_identity_res_cvg = groupby(all_identity_res_cvg, :LABELED_GROUP)
    density_plot_files = String[]
    for group_identity_res_cvg in gdf_identity_res_cvg
        group = group_identity_res_cvg.LABELED_GROUP[1]
		ClasnipPipeline.wait_for_lock(ClasnipPipeline.PLOT_LOCK) do
	        density_plot = StatsPlots.@df group_identity_res_cvg density(
	            :PERCENT_MATCHED,
	            group = :GROUP,
	            legend = :topleft,
	            bandwidth = 0.0025,
	            boundary = (0,1),
	            palette = :tab20,
	            title = "Density Plot of Identity (Group $group)",
	            xlabel = "Identity"
	        )
	        density_plot_file = joinpath(outdir, "plot.density_of_identity.$group.svg")
	        Plots.svg(density_plot, density_plot_file)
			push!(density_plot_files, density_plot_file)
		end
    end
    outfiles["PLOT_DENSITIES"] = density_plot_files

    ### heatmap of identity
    @info Pipelines.timestamp() * "clasnip_db_quality_assess: heatmap of identity" outdir
	if isempty(all_identity_res_cvg)
		# not plot
        @warn Pipelines.timestamp() * "clasnip_db_quality_assess: heatmap of identity: skip plot for empty all_identity_res_cvg" outdir
		outfiles["STAT_HEATMAP_IDENTITY"] = ""
		outfiles["PLOT_HEATMAP_IDENTITY"] = ""
	else
		pairwise_identity = @chain all_identity_res_cvg begin
	        groupby([:LABELED_GROUP, :GROUP])
	        @combine(:MEAN_IDENTITY = mean(skipmissing(:PERCENT_MATCHED)))
	        sort([:LABELED_GROUP, :GROUP])
	    end
	    # row: LABELED_GROUP; col: GROUP
	    pairwise_identity_long = unstack(pairwise_identity,
	        :LABELED_GROUP, :GROUP, :MEAN_IDENTITY
	    )

		# check whether missing rows or columns because of coverage threshold
		# if yes, fall back to no coverage threshold
		if !(nrow(pairwise_identity_long) == ncol(pairwise_identity_long) - 1 == length(unique(all_identity_res.LABELED_GROUP)))
			pairwise_identity = @chain all_identity_res begin
		        groupby([:LABELED_GROUP, :GROUP])
		        @combine(:MEAN_IDENTITY = mean(skipmissing(:PERCENT_MATCHED)))
		        sort([:LABELED_GROUP, :GROUP])
		    end
		    # row: LABELED_GROUP; col: GROUP
		    pairwise_identity_long = unstack(pairwise_identity,
		        :LABELED_GROUP, :GROUP, :MEAN_IDENTITY
		    )
		end


	    outfiles["STAT_HEATMAP_IDENTITY"] = joinpath(outdir, "stat.heatmap_identity.txt")
	    CSV.write(outfiles["STAT_HEATMAP_IDENTITY"], pairwise_identity_long, delim='\t')

	    row_labels = pairwise_identity_long.LABELED_GROUP
	    col_labels = names(pairwise_identity_long)[2:end]
	    ngroup = length(row_labels)

	    # pd: matrix
	    pd = Matrix(select(pairwise_identity_long, Not(:LABELED_GROUP)))
	    pd[ismissing.(pd)] .= 0.0
	    pd = convert(Matrix{Float64}, pd)

	    dm = Distances.pairwise(Distances.Euclidean(), pd, dims=2)
	    hcl2 = Clustering.hclust(dm, linkage=:average, branchorder=:optimal)

        heatmap_width = ifelse(ngroup <= 20, 600, 30 * ngroup)  # 600 * ngroup / 20

		wait_for_lock(PLOT_LOCK) do
		    heatmap_identity = plot(
		        plot(hcl2, xticks=false, yticks=false, grid=false, showaxis=false,
		            bottom_margin=0*Plots.Measures.mm,
		            top_margin=1*Plots.Measures.mm,
		        ),
		        Plots.heatmap(pd[hcl2.order, hcl2.order], colorbar=false,
		            xticks=(1:ngroup, [col_labels[i] for i in hcl2.order]),
		            yticks=(1:ngroup, [row_labels[i] for i in hcl2.order]),
		            c = :Blues_5,
		            ymirror = true,
		            xrotation = -45,
		            top_margin=-3.5*Plots.Measures.mm  #-3.5*Plots.Measures.mm if GR backend
		        ),
		        layout = grid(2,1, heights=[0.2,0.8]),
		        legend = false,
		        tick_direction = :none,
                size = (heatmap_width, heatmap_width)
		    )
		    outfiles["PLOT_HEATMAP_IDENTITY"] = joinpath(outdir, "plot.heatmap_identity.svg")
		    Plots.svg(heatmap_identity, outfiles["PLOT_HEATMAP_IDENTITY"])
		    Plots.html(heatmap_identity, replaceext(outfiles["PLOT_HEATMAP_IDENTITY"], "html"))
		end
	end

    ### count pairwise SNP
    @info Pipelines.timestamp() * "clasnip_db_quality_assess: compute pairwise_snp_score_for_db_groups" outdir
    if db_vcf == ""
        @warn Pipelines.timestamp() * "clasnip_db_quality_assess: compute pairwise_snp_score_for_db_groups: skip for db not provided" outdir
        # db not provided, skip
        outfiles["STAT_PAIRWISE_SNP_SCORE"] = ""
        outfiles["STAT_PAIRWISE_SNP_SCORE_NAME_ORDERED"] = ""
        outfiles["PLOT_HEATMAP_SNP_SCORE"] = ""
    else
		outfiles["PLOT_HEATMAP_SNP_SCORE"] = joinpath(outdir, "plot.heatmap_snp_score.svg")

        snp_matrix, snp_matrix_name_ordered = ClasnipPipeline.pairwise_snp_score_for_db_groups(db_vcf, outplot_svg = outfiles["PLOT_HEATMAP_SNP_SCORE"], coverage_cutoff = coverage_cutoff)

		if isnothing(snp_matrix) # failed
            @error Pipelines.timestamp() * "clasnip_db_quality_assess: compute pairwise_snp_score_for_db_groups: failed: snp_matrix is nothing" outdir
            outfiles["STAT_PAIRWISE_SNP_SCORE"] = ""
			outfiles["STAT_PAIRWISE_SNP_SCORE_NAME_ORDERED"] = ""
			outfiles["PLOT_HEATMAP_SNP_SCORE"] = ""
		else
	        outfiles["STAT_PAIRWISE_SNP_SCORE"] = joinpath(outdir, "stat.pairwise_snp_score.txt")
	        outfiles["STAT_PAIRWISE_SNP_SCORE_NAME_ORDERED"] = joinpath(outdir, "stat.pairwise_snp_score.name_ordered.txt")

	        DelimitedFiles.writedlm(outfiles["STAT_PAIRWISE_SNP_SCORE"], snp_matrix)
	        DelimitedFiles.writedlm(outfiles["STAT_PAIRWISE_SNP_SCORE_NAME_ORDERED"], snp_matrix_name_ordered)
		end
    end

    return outfiles
end

"""
    cumulated_density(identity_distributions::Dict{String, AverageShiftedHistograms.Ash}, group::AbstractString, value::Real)

Calculate the estimated cumulative density based on the average shifted (kernel density) distribution using cumulated density funtion `AverageShiftedHistograms.cdf`.

- `identity_distributions`: Dictionary, `group => Ash distribution`

- `group`: the group of value

- `value`: new value.
"""
function cumulated_density(identity_distributions::Dict{String, AverageShiftedHistograms.Ash}, group::AbstractString, value::Real)
    dist = get(identity_distributions, group, nothing)
    isnothing(dist) && (return NaN)
    AverageShiftedHistograms.cdf(dist, value)
end

function classifier_performance_for_group(all_identity_res::DataFrame, group::AbstractString, outdir::AbstractString)
    # * -1: simulate higher is better for ROC
    target = filter([:GROUP, :SAME] => (g, s) -> g == group && s, all_identity_res).RANK .* -1.0
    # NOTE: non_target use TIED_RANK!!!
    non_target = filter([:GROUP, :SAME] => (g, s) -> g == group && !s, all_identity_res).TIED_RANK .* -1.0

    # roc_result = ROCAnalysis.roc(target, non_target)
    # p = plot(roc_result, traditional=true,
    #     title = "ROC (Group $group)",
    #     xguide = "False Positive Rate (1 - Specificity)",
    #     yguide = "True Positive Rate (Sensitivity)"
    # );
    # roc_plot_path = joinpath(outdir, "ROC.plot.$group.svg")
    # Plots.svg(p, roc_plot_path)
    ## compute the Area Under the ROC, should be close to 0.078
    # auc_value = ROCAnalysis.AUC(roc_result)

    # use cutoff == 1
    TP = sum(target .== -1.0)
    FP = sum(non_target .== -1.0)
    TN = length(non_target) - FP
    FN = length(target) - TP
	return ClassifierMetrics(TP, FP, TN, FN)
    # return ClassifierMetrics(TP, FP, TN, FN), auc_value, roc_plot_path
end

function classifier_performance(all_identity_res::DataFrame, outdir::AbstractString)
    groups = sort(unique(all_identity_res.LABELED_GROUP))
    ngroup = length(groups)
    # auc_values = Vector{Float64}(undef, ngroup)
    # roc_plot_paths = Vector{String}(undef, ngroup)
    classifier_metrics = Vector{ClassifierMetrics}()
    for (i, group) in enumerate(groups)
		# metrics, auc_value, roc_plot_path = classifier_performance_for_group(all_identity_res, group, outdir)
        metrics = classifier_performance_for_group(all_identity_res, group, outdir)
        push!(classifier_metrics, metrics)
        # auc_values[i] = auc_value
        # roc_plot_paths[i] = roc_plot_path
    end
	# df_performance = DataFrame(LABELED_GROUP = groups, AUC = auc_values)
    df_performance = DataFrame(LABELED_GROUP = groups)
    df_performance = hcat(df_performance, DataFrame(classifier_metrics))
	# df_performance, roc_plot_paths
    df_performance
end

struct ClassifierMetrics
    TP::Int
    FP::Int
    TN::Int
    FN::Int
    TPR::Float64
    TNR::Float64
    PPV::Float64
    NPV::Float64
    FNR::Float64
    FPR::Float64
    FDR::Float64
    FOR::Float64
    ACC::Float64
    F1::Float64
end
function ClassifierMetrics(TP::Int, FP::Int, TN::Int, FN::Int)
    # https://en.wikipedia.org/wiki/Sensitivity_and_specificity
    # sensitivity, recall, hit rate, or true positive rate (TPR)
    TPR = TP / (TP + FN)
    #specificity, selectivity or true negative rate (TNR)
    TNR = TN / (TN + FP)
    # precision or positive predictive value (PPV)
    PPV = TP / (TP + FP)
    # negative predictive value (NPV)
    NPV = TN / (TN + FN)
    # miss rate or false negative rate (FNR)
    FNR = 1 - TPR
    # fall-out or false positive rate (FPR)
    FPR = 1 - TNR
    # false discovery rate (FDR)
    FDR = 1 - PPV
    # false omission rate (FOR)
    FOR = 1 - NPV
    # accuracy (ACC)
    ACC = (TP + TN) / (TP + TN + FP + FN)
    # F1 score is the harmonic mean of precision and sensitivity:
    F1 = 2TP / (2TP + FP + FN)
    ClassifierMetrics(TP, FP, TN, FN, TPR, TNR, PPV, NPV, FNR, FPR, FDR, FOR, ACC, F1)
end

"""
    pairwise_snp_score_for_db_groups(db_vcf::AbstractString; outplot_svg::AbstractString = "plot.heatmap_snp_score.svg", coverage_cutoff::Real = 5.0)

Return `heatmap_plot::Plots.Plot, snp_matrix::Matrix, snp_matrix_name_ordered::Matrix`
"""
function pairwise_snp_score_for_db_groups(db_vcf::AbstractString; outplot_svg::AbstractString = "plot.heatmap_snp_score.svg", coverage_cutoff::Real = 5.0)

    @info Pipelines.timestamp() * "pairwise_snp_score_for_db_groups" db_vcf outplot_svg
    if !isfile(db_vcf)
		@error Pipelines.timestamp() * "pairwise_snp_score_for_db_groups: Cannot load db_vcf: not a file: $db_vcf"
        return nothing, nothing
    end
    try
        clasnip_load_database(db_vcf)
    catch e
        @error Pipelines.timestamp() * "pairwise_snp_score_for_db_groups: Cannot load db_vcf: $db_vcf" exception=e
        return nothing, nothing
    end

    db_vcf_parsed, groups, group_dict, nsample_group = clasnip_get_all(db_vcf);
    ngroup = length(groups)

    snp_score_matrix = zeros(Float64, ngroup, ngroup)
    snp_coverage_matrix = zeros(Int, ngroup, ngroup)
    for ALT2PROB in db_vcf_parsed.ALT2PROBs
        # row: group
        # col: SNP
        alt2prob_matrix = hcat(values(ALT2PROB)...)
        snp_bit_matrix = alt2prob_matrix .> 0

        for x in 1:ngroup
            x_snps = @view snp_bit_matrix[x,:]
            any(x_snps) || continue # no coverage, skip

            x_probs = @view alt2prob_matrix[x,:]

            for y in x:ngroup
                y_snps = @view snp_bit_matrix[y,:]
                any(y_snps) || continue # no coverage, skip

                y_probs = @view alt2prob_matrix[y,:]
                xy_diff = x_snps .⊻ y_snps
                xy_snp_score = (sum(view(x_probs, xy_diff)) +  sum(view(y_probs, xy_diff))) / 2

                snp_score_matrix[x,y] += xy_snp_score
                snp_score_matrix[y,x] += xy_snp_score

                snp_coverage_matrix[x,y] += 1
                snp_coverage_matrix[y,x] += 1
            end
        end
    end

    snp_percent_matrix = snp_score_matrix ./ snp_coverage_matrix

    # before clustering, make nan to 0, so Euclidean() will not fail
    snp_percent_matrix[isnan.(snp_percent_matrix)] .= 0

    # clustering
    dm = pairwise(Euclidean(), snp_percent_matrix, dims=2)
    hcl2 = hclust(dm, linkage=:average, branchorder=:optimal)

    # if coverage < 10, set to NaN when displaying
    for (ind, coverage) in enumerate(snp_coverage_matrix)
        if coverage < coverage_cutoff
            snp_score_matrix[ind] = NaN
            snp_percent_matrix[ind] = NaN
        end
    end

    # med_coverage = median(snp_coverage_matrix)
    # snp_standardized_matrix = snp_percent_matrix .* med_coverage

    snp_label_matrix = Matrix{String}(undef, ngroup, ngroup)
    snp_label_score_matrix = Matrix{Plots.PlotText}(undef, ngroup, ngroup)
    snp_label_coverage_matrix = Matrix{Plots.PlotText}(undef, ngroup, ngroup)
    for (ind, score) in enumerate(snp_score_matrix)
        if isnan(score)
            snp_label_matrix[ind] = ""
            snp_label_score_matrix[ind] = text("", 6, :bottom)
            snp_label_coverage_matrix[ind] = text("", 6, :top, :grey)
        else
            coverage = snp_coverage_matrix[ind]
            snp_label_matrix[ind] = string(round(score; digits = 1), " / ", coverage)
            snp_label_score_matrix[ind] = text(round(score; digits = 1), 6, :bottom)
            snp_label_coverage_matrix[ind] = text(coverage, 6, :top, :grey)
        end
    end

    # group name ordered tables
    name_perm = sortperm(groups)
    snp_label_matrix_name_ordered_header = [
        "DIFF/COVERAGE" permutedims(groups[name_perm]);
        groups[name_perm] snp_label_matrix[name_perm,name_perm];
    ]

    # cluster ordered tables
    snp_label_matrix_ordered = snp_label_matrix[hcl2.order, hcl2.order]
    snp_label_score_matrix_ordered = snp_label_score_matrix[hcl2.order, hcl2.order]
    snp_label_coverage_matrix_ordered = snp_label_coverage_matrix[hcl2.order, hcl2.order]
    snp_percent_matrix_reodered = snp_percent_matrix[hcl2.order, hcl2.order]
    groups_ordered = groups[hcl2.order]

    snp_label_matrix_ordered_header = [
        "DIFF/COVERAGE" permutedims(groups[hcl2.order]);
        groups[hcl2.order] snp_label_matrix_ordered;
    ]

    @info "pairwise_snp_score_for_db_groups: plot heatmap" db_vcf outplot_svg

    n_digit = ceil(Int, log10(maximum(snp_coverage_matrix))) + 3
    heatmap_width = max(600, 6 * n_digit * ngroup)

	wait_for_lock(PLOT_LOCK) do
	    plot_heat = Plots.heatmap(snp_percent_matrix_reodered, colorbar=false,
	        xticks=(1:ngroup, groups_ordered),
	        yticks=(1:ngroup, groups_ordered),
	        c = cgrad(:Blues_5, rev=true),
	        ymirror = true,
	        xrotation = -45,
	        top_margin=-3.5*Plots.Measures.mm  #-3.5*Plots.Measures.mm if GR backend
	    )
	    # label in cells
	    xs = Base.repeat(1:ngroup, inner = ngroup);
	    ys = Base.repeat(1:ngroup, outer = ngroup);
	    scatter!(plot_heat, xs, ys,
	        series_annotations = snp_label_score_matrix_ordered[:],
	        fillalpha = 0,
	        markeralpha = 0,
	        label = nothing,
	    )
	    scatter!(plot_heat, xs, ys,
	        series_annotations = snp_label_coverage_matrix_ordered[:],
	        fillalpha = 0,
	        markeralpha = 0,
	        label = nothing,
	        ymirror = true,
	        foreground_color_axis = RGBA(0,0,0,0),
	        lims = (0.5,ngroup+0.5)
	    )

	    full_plot = plot(
	        plot(hcl2, xticks=false, yticks=false, grid=false, showaxis=false,
	            bottom_margin=0*Plots.Measures.mm,
	            top_margin=1*Plots.Measures.mm,
	        ),
	        plot_heat,
	        layout=grid(2,1, heights=[0.15,0.85]),
	        size = (heatmap_width, heatmap_width),
	        legend = false,
	        tick_direction = :none,
	    )
		Plots.svg(full_plot, outplot_svg)
		Plots.html(full_plot, replaceext(outplot_svg, "html"))
	end
    return snp_label_matrix_ordered_header, snp_label_matrix_name_ordered_header
end

function reorder(matrix_with_header::Matrix)
    groups = matrix_with_header[1,2:end]
    idx = sortperm(groups)
    idx_df = [1; idx .+ 1]

    matrix_with_header[idx_df, idx_df]
end
