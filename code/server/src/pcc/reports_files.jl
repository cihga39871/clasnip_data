
REGEX_PCC_ANALYSIS_FOLDER = r"/pcc-\d+-[^/]*$"
REGEX_PCC_INFO_FILE = r"/pcc-(arg|log)s-([^.]+)[^/]*$"

function pcc_file_info(path::AbstractString)
	m = match(REGEX_PCC_INFO_FILE, path)
	isnothing(m) && (return nothing)
	length(m.captures) < 2 && (return nothing)
	analysis_type = m.captures[1]
	analysis_name = m.captures[2]
	if analysis_type == "log"
		if path[end - 6:end - 4] == "err"
			analysis_type = "error_log"
		end
	end
	return analysis_type, analysis_name
end

"""
	unsafe_get_report_files(project_dir::AbstractString)

Unsafe: do not check whether project_dir exists.
"""
function unsafe_get_report_files(project_dir::AbstractString)

	submitted_jobs = Dict{String,Dict{String,Vector{String}}}()
    for i in readdir(project_dir; join=true)
		if isfile(i)
			file_info = pcc_file_info(i)
			isnothing(file_info) && continue  # not a valid info file (not start with pcc-args- or pcc-logs)
			analysis_type, analysis_name = file_info
			if haskey(submitted_jobs, analysis_name)
				if haskey(submitted_jobs[analysis_name], analysis_type)
					push!(submitted_jobs[analysis_name][analysis_type], i)
				else
					submitted_jobs[analysis_name][analysis_type] = [i]
				end
    			else
				submitted_jobs[analysis_name] = Dict{String,Vector{String}}(analysis_type => [i])
			end
		else
			# link: regular report files under root folders do not contain links
			# folder: folder will not handle here
			nothing
		end
	end

	### get QC files from analysis_folders
	qc_files = Dict{String,Any}("job_info" => submitted_jobs)

	pcc_folder_methods = [
		"pcc-0-raw"      => unsafe_get_report_files__0_raw
		"pcc-1-trimming" => unsafe_get_report_files__1_trimming
		"pcc-2-mapping"  => unsafe_get_report_files__2_mapping
		"pcc-3-assembly" => unsafe_get_report_files__3_assembly
	]

	for i in pcc_folder_methods
		folder, func = i
		folder_path = joinpath(project_dir, folder)
		isdir(folder_path) || continue
		qc_files[folder] = func(folder_path)
	end
	return qc_files
end

function unsafe_get_report_files__0_raw(path::AbstractString)
	# path = "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-0-raw"
	fs = readdir(path; join=true)
	Dict{String,Vector{String}}(
		"multiQC" => filter(f -> occursin(r"^multiqc_report\..*\.html$", basename(f)), fs),
		"fastQC" => filter(f -> occursin(r"_fastqc.html$", basename(f)), fs)
	)
end

function unsafe_get_report_files__1_trimming(path::AbstractString)
	unsafe_get_report_files__0_raw(path)
end

function unsafe_get_report_files__2_mapping(path::AbstractString)
	# path = "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-2-mapping"
	res = Dict{String,Any}()
	res["filtered_fastqs"] = unsafe_get_report_files__0_raw(path)

	# bam stats under "bam-stats"
	bam_stats_folder = joinpath(path, "bam-stats")
	if isdir(bam_stats_folder)
		fs = readdir(bam_stats_folder, join=true)
		res["summary_tables"] = filter(f -> occursin(r"^stat.samtools-stats.*\.tsv$", basename(f)), fs)
		res["samples"] = Dict{String,Vector{String}}()
		for f in fs
			if occursin(r"samtools-stats\.plots$", f) && isdir(f)
				sample_name = replace(basename(f), r"\.samtools-stats\.plots$" => "")
				pngs = filter!(x -> occursin(r"\.png$", x), readdir(f, join=true))
				res["samples"][sample_name] = pngs
			end
		end
	end
	res
end

function unsafe_get_report_files__3_assembly(path::AbstractString)
	# path = "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-3-assembly"
	res = Dict{String,Any}()
	fs = readdir(path; join=true)

	sample_fastas = filter(x -> occursin(r"^(?!\.).*\.(fa|fasta)(\.gz)?$"i, basename(x)), fs)

	ani_summary_heatmaps = filter(x -> occursin(r"^stat\..*\.plot\.html$", basename(x)), fs)
	ani_summary_matrices = filter(x -> occursin(r"^stat\..*\.plot\.html\.matrix\.txt$", basename(x)), fs)

	ani_sample_top_list = filter(x -> occursin(r"^(?!stat\.).*\.plot\.html\.top-list\.txt$", basename(x)), fs)
	ani_sample_heatmaps = filter(x -> occursin(r"^(?!stat\.).*\.plot\.html$", basename(x)), fs)
	ani_sample_matrices = filter(x -> occursin(r"^(?!stat\.).*\.plot\.html\.matrix\.txt$", basename(x)), fs)

	res["fastas"] = sample_fastas
	res["ani"] = Dict{String,Any}(
		"summary_heatmaps" => ani_summary_heatmaps,
		"summary_matrices" => ani_summary_matrices,
		"sample_top_lists" => ani_sample_top_list,
		"sample_heatmaps" => ani_sample_heatmaps,
		"sample_matrices" => ani_sample_matrices
	)
	return res
end
