"""
	clasnip_classify(fasta::AbstractString, reference_genome::AbstractString, db_vcf::AbstractString; resume::Bool = true, clean::Bool = false, log_file = nothing, fail_info_path = nothing, dir="")

Clasnip pipeline for sample classification (from fasta to vcf). Return `Dict{String,Cmd}("VCF" => filepath::Cmd)`

- `fail_info_path::Union{Nothing,AbstractString}`: if classification failed but can be handled, fail information will write to the file if it is not `nothing`.
"""
function clasnip_classify(fasta::AbstractString, reference_genome::AbstractString, db_vcf::AbstractString; resume::Bool = true, write_mlst::Bool = true, clean::Bool = false, log_file = nothing, fail_info_path = nothing, dir="")

	if dir != ""
		dir_backup = pwd()
		cd(dir)
	end

	@info Pipelines.timestamp() * "clasnip_classify" fasta reference_genome db_vcf

	run_args = (skip_when_done = resume, stdout = log_file, stderr = log_file, stdlog = log_file, append = true)
    
	# fa 2 fq
    input_of_fa2fq = Dict("FASTA" => fasta)
	success, output_of_fa2fq = run(ClasnipPipeline.program_fa2fq, input_of_fa2fq; run_args...)
	# out: FASTQ
	yield()

    # bowtie2
    output_of_fa2fq["REF"] = reference_genome
    success, output_of_bowtie2 = run(ClasnipPipeline.program_bowtie2, output_of_fa2fq; run_args...)
	# out: BAM, BAM.bai
	yield()

    # freebayes to vcf
    output_of_bowtie2["REF"] = reference_genome
    success, output_of_freebayes = run(ClasnipPipeline.program_freebayes, output_of_bowtie2; run_args...)
	# out: VCF, VCF.mlst.all.txt
	yield()

	# check whether identity distribution exists.
	# if exists, compute P value in clasnip_vcf2mlst
	identity_distribution_jld2 = joinpath(dirname(reference_genome), "stat.identity_distributions.jld2")
	if !isfile(identity_distribution_jld2)
		identity_distribution_jld2 = nothing
	end

    # vcf 2 mlst
    output_of_mlst, identity_res = Pipelines.redirect_to_files(log_file; mode="a+") do
		ClasnipPipeline.clasnip_vcf2mlst(str(output_of_freebayes["VCF"]), db_vcf; resume = resume, identity_distribution_jld2 = identity_distribution_jld2, fail_info_path = fail_info_path, write_mlst = write_mlst)
	end

	if clean
		rm(output_of_fa2fq["FASTQ"], force=true)
		rm(output_of_bowtie2["BAM"], force=true)
		rm(output_of_bowtie2["BAM"] * ".bai", force=true)
		rm(output_of_freebayes["VCF"], force=true)
		rm(output_of_freebayes["VCF"] * ".mlst.all.txt", force=true)
		fs = readdir()
		for f in fs
			if f[1] == '.' && f != ".clasnip"
				rm(f)
			end
		end
	end
	if dir != ""
		cd(dir_backup)
	end
    return output_of_mlst
end

function clasnip_vcf2mlst(vcf_path::AbstractString, db_vcf::AbstractString; outprefix = vcf_path * ".mlst", resume::Bool = true, identity_distribution_jld2 = nothing, fail_info_path = nothing, write_mlst::Bool = true)

	@info Pipelines.timestamp() * "clasnip_vcf2mlst: Loading database for Clasnip SNP statistics." vcf_path

    clasnip_load_database(db_vcf)

    db_vcf_parsed, groups, group_dict, nsample_group = clasnip_get_all(db_vcf);

	clasnip_vcf2mlst(vcf_path, db_vcf_parsed, groups, group_dict, nsample_group; outprefix = outprefix, resume = resume, identity_distribution_jld2 = identity_distribution_jld2, fail_info_path = fail_info_path, write_mlst = write_mlst)
end

function clasnip_vcf2mlst_with_cv_db(vcf_path::AbstractString, db_vcf_jld2_path_AB::AbstractString; db_reverse::Bool = false, outprefix = vcf_path * ".mlst", resume::Bool = true, write_mlst::Bool = false)

	@info Pipelines.timestamp() * "clasnip_vcf2mlst_with_cv_db: Loading CV database for Clasnip SNP statistics." vcf_path

    # If run the function, the cv_db has been loaded already
    db_vcf_parsed, groups, group_dict, nsample_group = get_clasnip_cv_db_elements(db_vcf_jld2_path_AB, db_reverse);

	if isnothing(db_vcf_parsed)
		error("Nothing was returned in get_clasnip_cv_db_elements(\"$db_vcf_jld2_path_AB\", $db_reverse)")
	end

	clasnip_vcf2mlst(vcf_path, db_vcf_parsed, groups, group_dict, nsample_group; outprefix = outprefix, resume = resume, write_mlst = write_mlst)
end

function clasnip_vcf2mlst(vcf_path::AbstractString, db_vcf_parsed::DataFrame, groups::Vector, group_dict::Dict, nsample_group::Dict; outprefix = vcf_path * ".mlst", resume::Bool = true, identity_distribution_jld2 = nothing, fail_info_path = nothing, write_mlst::Bool = true)
	@info Pipelines.timestamp() * "Started: Clasnip SNP statistics."

	# outfiles
	mlst_all_file = ""  # this file will not be generated anymore
	mlst_partial_file = ifelse(write_mlst, "$outprefix.partial.txt", "")
	identity_res_file = "$outprefix.classification_result.txt"

	isdir(dirname(outprefix)) || mkpath(dirname(outprefix), mode=0o755)

	# loading input vcf file
	@info Pipelines.timestamp() * "Loading mapped nucleotides."
    # input_vcf_all = vcf_load(vcf_path)
    input_vcf_overlapped = ClasnipPipeline.vcf_load_overlapped(vcf_path, db_vcf_parsed)


	# if input vcf file is empty, return empty
	if isnothing(input_vcf_overlapped) || nrow(input_vcf_overlapped) == 0
		fail_info = "The sample has no SNP matched in the database!"
		@error Pipelines.timestamp() * fail_info

		if !isnothing(fail_info_path)
			open(fail_info_path, "w+") do io
				println(io, fail_info)
			end
		end
		mlst = empty(db_vcf_parsed)
		mlst.SAMPLE = []
		mlst.DEPTH = []
		identity_res = ClasnipPipeline.compute_identity(mlst, groups)

		return Dict{String, Cmd}(
	        "MLST_ALL_TABLE" => `$mlst_all_file`,
	        "MLST_PARTIAL_TABLE" => `""`,
	        "MLST_RES_TABLE" => `$identity_res_file`
	    ), mlst, identity_res
	end

	# check whether db_vcf_parsed contain MLST rows
	for group in groups
		if !hasproperty(db_vcf_parsed, Symbol(group))
			error("clasnip_vcf2mlst(): db_vcf_parsed is not mature: no rows of group names found. Plase use `parsed_db_vcf_to_mlst(db_vcf_parsed, groups)` to generate the mature db_vcf_parsed.")
		end
	end

	@info Pipelines.timestamp() * "Selecting common variants."

	# join mlst table with database table
    mlst = innerjoin(db_vcf_parsed, input_vcf_overlapped; on = [:CHROM, :POS])
	input_vcf_overlapped = nothing  # free

	# filter out missing in mlst
	filter!(r -> !( ismissing(r.SAMPLE) || ismissing(r.DEPTH) ), mlst)

	@info Pipelines.timestamp() * "Writing the MLST table."
    # CSV.write(mlst_all_file, select(mlst, Not(:ALT2PROBs)); delim='\t')

    # filter: at least two haplotypes
    filter!(:ALT2PROBs => d -> length(keys(d)) > 1, mlst)  #TODO: remove when all database contain the filtration.
	if write_mlst
    	CSV.write(mlst_partial_file, select(mlst, Not(:ALT2PROBs)); delim='\t')
	end

	@info Pipelines.timestamp() * "Computing identity."

	# compute identity for each group
    identity_res = @time ClasnipPipeline.compute_identity(mlst, groups)

	# empty mlst to reduce memory
	empty!(mlst)

	# compute P value if identity_distribution_jld2 is not nothing
	if !isnothing(identity_distribution_jld2)
		try
			@info Pipelines.timestamp() * "Loadding identity distributions in database."
			@load identity_distribution_jld2 identity_distributions
			@info Pipelines.timestamp() * "Computing estimated cumulated density."
			@rtransform!(identity_res,
		        :CDF = cumulated_density(identity_distributions, :GROUP, :PERCENT_MATCHED)
		    )
			# CDF can be NaN, convert to 0
			for (irow, val) in enumerate(identity_res.CDF)
				if isnan(val)
					identity_res.CDF[irow] = 0
				end
			end

			@info Pipelines.timestamp() * "Computing final probabilities."
			@transform!(identity_res,
				:PROBABILITY = value_normalize(:CDF)
		    )
		catch e
			@error Pipelines.timestamp() * "Failed to compute CDF or probabilities." exception=e identity_distribution_jld2
		end
	end

	# save classification result file
	CSV.write(identity_res_file, identity_res; delim='\t')

	# analysis pass, remove fail_info file
	if !isnothing(fail_info_path) && isfile(fail_info_path)
		rm(fail_info_path)
	end

	@info Pipelines.timestamp() * "Finished: Clasnip SNP statistics."

    return Dict{String, Cmd}(
        "MLST_ALL_TABLE" => `$mlst_all_file`,
        "MLST_PARTIAL_TABLE" => `$mlst_partial_file`,
        "MLST_RES_TABLE" => `$identity_res_file`
    ), identity_res
end

function compute_identity(mlst::DataFrame, groups::Vector)
    ngroup = length(groups)
    n_snps = Vector{Float64}(undef, ngroup)  # all COVERED_SNP_SCORE
    n_ident_snps = Vector{Float64}(undef, ngroup)  # MATCHED_SNP_SCORE
    n_row = nrow(mlst)

	# predefined ALTs to reduce LOTS of memory
	predefined_alt_empty = Array{SubString{String},1}()
	predefined_alt_dot = split(".", ",")

    mlst.ALTs = map(mlst.SAMPLE) do alt
        if length(alt) == 0
            predefined_alt_empty
        elseif alt[1] == '.'
            predefined_alt_dot
        else
            split(".," * alt, ",")
        end
    end;

	# predefined WEIGHTs to reduce LOTS of memory
	predefined_weight_single = [1.0]

	mlst.WEIGHTs = map(mlst.DEPTH) do depth
		if occursin(',', depth)
			depths = split(depth, ",")
			vals = parse.(Float64, depths)
			vals ./= sum(vals)
		else
			predefined_weight_single
		end
    end

    for i = 1:ngroup
        group = groups[i]
        group_symbol = Symbol(group)

        n_snp = 0.0  # total score of valid SNPs,
        n_ident_snp = 0.0  # score of sample == group
        for i_row in 1:n_row
            # skip missing in group
            if isempty(mlst[i_row, group_symbol])
                continue
            end

            alt2prob = mlst[i_row, :ALT2PROBs]
            alts = mlst[i_row, :ALTs]
            ws = mlst[i_row, :WEIGHTs]

            # n_snp += 1  # NOTE: OUTDATE: the score is 1,
            n_snp += maximum(getindex.(values(alt2prob), i))  # the score is the maximum ALT probability

            n_alt = length(alts)
            n_alt == length(ws) || error("Depth of ALT not the same as DEPTH!")
            for j in 1:n_alt
                probs = get(alt2prob, alts[j], nothing)
                isnothing(probs) && continue
                n_ident_snp += probs[i] * ws[j]
            end
        end

        n_snps[i] = n_snp
        n_ident_snps[i] = n_ident_snp
    end
    res = DataFrame(
        :GROUP => groups,
        :PERCENT_MATCHED => n_ident_snps ./ n_snps,
        :MATCHED_SNP_SCORE => n_ident_snps,
        :COVERED_SNP_SCORE => n_snps
    )
	replace!(res.PERCENT_MATCHED, NaN => 0)  # NaN occurs when n_snps == 0
    sort!(res, :PERCENT_MATCHED, rev=true)
    res
end
