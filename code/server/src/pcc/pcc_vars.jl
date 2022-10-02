function get_pcc_genomes(pcc_db::String)
    # find $CJC_PCC_DB/genomes/ -type d | grep -v "GCA" | sed -r "s#.*/genomes/##"
    isdir(pcc_db) || return ["PolyChrome Genome Database is not valid. Please contact your PolyChrome maintainer."]

    pcc_genomes = readlines(pipeline(`find $pcc_db/genomes/ -type d`, `grep -v -E "GC[AF]_"`, `sed -r 's#.*/genomes/##'`, `awk 'NR>1'`))
end

const PCC_GENOMES = get_pcc_genomes(Config.PCC_DATABASE)


function get_analysis_profiles(path::String)::Dict{String,Dict}
    isdir(path) || return Dict{String, Dict}()

    profile_files = readdir(path, join=true)

    profiles = Dict{String, Dict}()
    for profile_file in profile_files
        profile_settings = JSON.parse(readchomp(profile_file))
        profile_name = get(profile_settings, "analysisProfile", splitext(basename(profile_file))[1])
        profiles[profile_name] = profile_settings
    end
    return profiles
end

const ANALYSIS_PROFILES = get_analysis_profiles(joinpath(@__DIR__, "..", "..", "analysis_profiles"))
