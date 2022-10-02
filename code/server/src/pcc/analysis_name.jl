# those function should be identical from PolyChrome and CJCBioTools

function generate_analysis_name(pcc_genome_dirs::Vector; depth=NaN)
    analysis_name = join(sort!(basename.(pcc_genome_dirs)), "_")
    if length(analysis_name) > 10
        # simplify full name
        analysis_name = analysis_name[1:6] * "_" * shortened_identifier(analysis_name, pad=3)
    end
    if !isnan(depth)
        analysis_name *= "_depth$depth"
    end
    analysis_name
end

function generate_sample_identifier(samples::Vector)
    sample_identifier = join(sort!(basename.(samples)), "_")
    if length(sample_identifier) > 10
        # simplify
        nsamples = length(samples)
        sample_identifier = "$(nsamples)samples_" * shortened_identifier(sample_identifier, pad=1)
    end
    sample_identifier
end

function shortened_identifier(s::AbstractString; pad=1)
    string(sum(Int.(collect(s))), base=62, pad=pad)
end

function shortened_identifier(a::Array; pad=1)
    s = join(sort!(basename.(a)), "_")
    shortened_identifier(s, pad=pad)
end
