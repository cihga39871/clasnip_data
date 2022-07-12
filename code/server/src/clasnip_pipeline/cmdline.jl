
# include(joinpath(ENV["CJCBioTools"], "api", "julia", "ARGS_to_julia_function.jl"))

"""
	clasnip_classify fastas::AbstractString... reference_genome::AbstractString db_vcf::AbstractString [resume::Bool=true] [clean::Bool=false] [dir="."]

Clasnip pipeline for sample classification (from fasta to vcf).

- `fastas`: fasta samples.

- `reference_genome`: fasta genome.

- `db_vcf`: clasnip database vcf file ends with `.db-vcf.reduced.jld2`.

"""
function cmd_clasnip_classify end

function cmd_clasnip_classify(raw_args)
    psargs, kwargs = ARGS_parse(raw_args;
		positional_types = (String, String, String),
		npositional_min = 3,
		keyword_names    = ("resume", "clean", "dir"),
		keyword_types    = (Bool, Bool, String),
		keyword_defaults = (true, false, "."),
		docs_when_error  = @eval(cmd_doc(@doc cmd_clasnip_classify)))

	npsargs = length(psargs)
	if npsargs == 3
		clasnip_classify(psargs...; resume = kwargs["resume"], clean = kwargs["clean"], dir = kwargs["dir"])
	else
		fastas = psargs[1:end-2]
		reference_genome = psargs[end-1]
		db_vcf = psargs[end]
		for fasta in fastas
			clasnip_classify(fasta, reference_genome, db_vcf; resume = kwargs["resume"], clean = kwargs["clean"], dir = kwargs["dir"])
		end
	end
end
