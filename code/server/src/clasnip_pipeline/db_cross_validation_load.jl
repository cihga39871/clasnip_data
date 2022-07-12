struct ClasnipCvDb
    db_vcf_jld2_path_AB::String
    db_vcf_parsed_A::DataFrame
    db_vcf_parsed_B::DataFrame
    groups_AB::Vector{SubString{String}}
    group_A_dict::Dict{SubString{String}, Vector{SubString{String}}}
    group_B_dict::Dict{SubString{String}, Vector{SubString{String}}}
    nsample_group_A::Dict{SubString{String}, Int64}
    nsample_group_B::Dict{SubString{String}, Int64}
    samples_A::Set{SubString{String}}
    samples_B::Set{SubString{String}}
    fasta_analysis_dir::String
end

"""
    CLASNIP_CV_DB = Dict{String, Any}(
        db_vcf_jld2_path_AB => [db_mlst, groups, group_dict, nsample_group, last_modified::DateTime, memory_in_bytes::Int]
    )
"""
CLASNIP_CV_DB = Dict{String, ClasnipCvDb}()
CLASNIP_CV_DB_LOADING = Dict{String, Bool}()
CLASNIP_CV_DB_LOAD_LOCK = SpinLock()



"""
    clasnip_cache_cv_database(cv_db::ClasnipCvDb; reload::Bool=false)

Save cv_db to cache `CLASNIP_CV_DB[cv_db.db_vcf_jld2_path_AB]`.

See also `clasnip_unload_cv_database(db_vcf_jld2_path_AB)`
"""
function clasnip_cache_cv_database(cv_db::ClasnipCvDb; reload::Bool=false)
    global CLASNIP_CV_DB

    db_vcf_jld2_path_AB = cv_db.db_vcf_jld2_path_AB
    (!reload && haskey(CLASNIP_CV_DB, db_vcf_jld2_path_AB)) && return nothing

    # check whether other program is loading
    wait_for_lock(CLASNIP_CV_DB_LOAD_LOCK)

    try
        CLASNIP_CV_DB_LOADING[db_vcf_jld2_path_AB] = true

        CLASNIP_CV_DB[db_vcf_jld2_path_AB] = cv_db
    catch e
        @error Pipelines.timestamp() * "Fail to load clasnip CV database: $db_vcf_jld2_path_AB" exception=e
    finally
        delete!(CLASNIP_CV_DB_LOADING, db_vcf_jld2_path_AB)
        unlock(CLASNIP_CV_DB_LOAD_LOCK);
    end
    return nothing
end

"""
    clasnip_unload_cv_database(db_vcf_jld2_path_AB)

Remove `db_vcf_jld2_path_AB` in `CLASNIP_CV_DB`.

See also `clasnip_unload_cv_database(cv_db::ClasnipCvDb; reload::Bool=false)`
"""
function clasnip_unload_cv_database(db_vcf_jld2_path_AB::AbstractString)
    global CLASNIP_CV_DB
    wait_for_lock(CLASNIP_CV_DB_LOAD_LOCK)

    ret = try
        if haskey(CLASNIP_CV_DB, db_vcf_jld2_path_AB)
            delete!(CLASNIP_CV_DB, db_vcf_jld2_path_AB)
            true
        else
            false
        end
    catch e
        @error "clasnip_unload_cv_database: $db_vcf_jld2_path_AB" exception=(e, catch_backtrace())
        false
    finally
        unlock(CLASNIP_CV_DB_LOAD_LOCK);
    end
    return ret
end

"""
    get_clasnip_cv_db(db_vcf_jld2_path_AB::AbstractString)

Return `cv_db::ClasnipCvDb`
"""
function get_clasnip_cv_db(db_vcf_jld2_path_AB::AbstractString)
    global CLASNIP_CV_DB
    wait_for_lock(CLASNIP_CV_DB_LOAD_LOCK)

    if !haskey(CLASNIP_CV_DB, db_vcf_jld2_path_AB)
        unlock(CLASNIP_CV_DB_LOAD_LOCK);
        @error "get_clasnip_cv_db_elements: database not cached $db_vcf_jld2_path_AB"
        return nothing
    end
    cv_db = CLASNIP_CV_DB[db_vcf_jld2_path_AB]
    unlock(CLASNIP_CV_DB_LOAD_LOCK);
    return cv_db
end

"""
    get_clasnip_cv_db_elements(db_vcf_jld2_path_AB::AbstractString, db_reverse::Bool=false)

    return (
        db_vcf_parsed,
        groups,
        group_dict,
        nsample_group
    )

- `db_reverse::Bool`: if no, A as returned training database, B as test set. if yes, reverse.
"""
function get_clasnip_cv_db_elements(db_vcf_jld2_path_AB::AbstractString, db_reverse::Bool=false)
    cv_db = get_clasnip_cv_db(db_vcf_jld2_path_AB)
    if isnothing(cv_db)
        @error "get_clasnip_cv_db_elements: database not cached $db_vcf_jld2_path_AB"
        return (nothing, nothing, nothing, nothing)
    end
    if db_reverse
        return (
            cv_db.db_vcf_parsed_B,
            cv_db.groups_AB,
            cv_db.group_B_dict,
            cv_db.nsample_group_B
        )
    else
        return (
            cv_db.db_vcf_parsed_A,
            cv_db.groups_AB,
            cv_db.group_A_dict,
            cv_db.nsample_group_A
        )
    end
end
