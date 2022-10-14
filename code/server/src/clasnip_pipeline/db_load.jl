mutable struct ClasnipDb
    const db_vcf_jld2_path::String
    const db_vcf_parsed::DataFrame
    const groups::Vector{String}
    const group_dict::Dict{String, Vector{String}}
    const nsample_group::Dict{String, Int64}
    access_time::DateTime
    memory_size::Int
end

function Base.empty!(db::ClasnipDb)
    empty!(db.db_vcf_parsed)
    empty!(db.groups)
    for (k,v) in db.group_dict
        empty!(v)
    end
    empty!(db.group_dict)
    empty!(db.nsample_group)
    nothing
end

function Base.empty!(vv::Vector{Vector})
    # this is useful when empty Dict{T,Vector{Vector}}, eg db.ALT2PROBs
    for v in vv
        empty!(v)
    end
    empty!(vv)
end
function Base.empty!(vv::Dict{T, Vector}) where T
    # this is useful when empty Dict{T,Vector{Vector}}, eg db.ALT2PROBs
    for (k,v) in vv
        empty!(v)
    end
    empty!(vv)
end

"""
    CLASNIP_DB = Dict{String, ClasnipDb}(
        db_vcf_jld2_path => [db_mlst, groups, group_dict, nsample_group, last_modified::DateTime, memory_in_bytes::Int]
    )
"""
CLASNIP_DB = Dict{String, ClasnipDb}()
CLASNIP_DB_LOADING = Dict{String, Bool}()
CLASNIP_DB_LOAD_LOCK = SpinLock()
function wait_for_lock(lock::SpinLock)
    while !trylock(lock)
        sleep(0.05)
    end
end
function wait_for_lock(f::Function, lock::SpinLock)
    while !trylock(lock)
        sleep(0.05)
    end
    try
        f()
    finally
        unlock(lock)
    end
end

function clasnip_load_database(db_vcf_jld2_path::AbstractString; reload::Bool=false)
    global CLASNIP_DB

    (!reload && haskey(CLASNIP_DB, db_vcf_jld2_path)) && return nothing

    # check whether other program is loading
    wait_for_lock(CLASNIP_DB_LOAD_LOCK)

    time0 = now()
    try
        CLASNIP_DB_LOADING[db_vcf_jld2_path] = true

        # start loading
        @load db_vcf_jld2_path db_vcf_parsed groups group_dict nsample_group
        
        # fix if db_vcf_parsed isa JLD2.ReconstructedTypes.var"##DataFrame#416"
        # which caused from using a different version of DataFrame when building db
        db_vcf_parsed = reconstruct_dataframe(db_vcf_parsed)

        db_vcf_parsed = parsed_db_vcf_to_mlst!(db_vcf_parsed::DataFrame, groups::Vector)
        ClasnipPipeline.unique_reference_for_db_vcf_parsed!(db_vcf_parsed) # reduce memory usage to 60%

        estimated_db_size = filesize(db_vcf_jld2_path) * 2
        clasnip_db = ClasnipDb(db_vcf_jld2_path, db_vcf_parsed, groups, group_dict, nsample_group, now(), estimated_db_size)
        CLASNIP_DB[db_vcf_jld2_path] = clasnip_db

        # Compute the amount of memory, in bytes
        
        # estimate memory size replaced by 
        #     estimated_db_size = filesize(db_vcf_jld2_path) * 2. 
        # because Base.summarysize will use more momory!
        # job_compute_memory_size = Job(name = "Memory Size: $db_id") do 
        #     clasnip_db.memory_size = Base.summarysize(clasnip_db)
        #     nothing
        # end
        # submit!(job_compute_memory_size)
        time1 = now()
        elapsed_second = (time1 - time0).value / 1000
        @info "Load database ($(elapsed_second)s): $db_vcf_jld2_path"
    catch e
        @error Pipelines.timestamp() * "Fail to load clasnip database: $db_vcf_jld2_path" exception=e
    finally
        delete!(CLASNIP_DB_LOADING, db_vcf_jld2_path)
        unlock(CLASNIP_DB_LOAD_LOCK);
    end
    return nothing
end

reconstruct_dataframe(db_vcf_parsed::DataFrame) = db_vcf_parsed
function reconstruct_dataframe(db_vcf_parsed)
    if fieldnames(typeof(db_vcf_parsed)) == (:columns, :colindex)
        db_vcf_parsed.colindex
        db_vcf_parsed.columns
        col_names = db_vcf_parsed.colindex.names
        DataFrame([name => db_vcf_parsed.columns[db_vcf_parsed.colindex.lookup[name]] for name in col_names])
    else
        @error "Fail to reconstruct DataFrame from jld2 file!"
        df
    end
end

function clasnip_unload_database(db_vcf_jld2_path::AbstractString)
    global CLASNIP_DB
    wait_for_lock(CLASNIP_DB_LOAD_LOCK)

    ret = try
        if haskey(CLASNIP_DB, db_vcf_jld2_path)
            empty!(CLASNIP_DB[db_vcf_jld2_path])
            delete!(CLASNIP_DB, db_vcf_jld2_path)
            true
        else
            false
        end
    catch e
        @error Pipelines.timestamp() * "clasnip_unload_database: $db_vcf_jld2_path" exception=(e, catch_backtrace())
        false
    finally
        unlock(CLASNIP_DB_LOAD_LOCK);
    end
    return ret
end

function clasnip_get_db(db_vcf_jld2_path::AbstractString)
    global CLASNIP_DB
    wait_for_lock(CLASNIP_DB_LOAD_LOCK) do
        if !haskey(CLASNIP_DB, db_vcf_jld2_path)
            return nothing
        end
        clasnip_db = CLASNIP_DB[db_vcf_jld2_path]
        clasnip_db.access_time = now()
        clasnip_db.db_vcf_parsed
    end
end
function clasnip_get_groups(db_vcf_jld2_path::AbstractString)
    global CLASNIP_DB
    wait_for_lock(CLASNIP_DB_LOAD_LOCK) do
        if !haskey(CLASNIP_DB, db_vcf_jld2_path)
            return nothing
        end
        clasnip_db = CLASNIP_DB[db_vcf_jld2_path]
        clasnip_db.access_time = now()
        clasnip_db.groups
    end
end
function clasnip_get_group_dict(db_vcf_jld2_path::AbstractString)
    global CLASNIP_DB
    wait_for_lock(CLASNIP_DB_LOAD_LOCK) do

        if !haskey(CLASNIP_DB, db_vcf_jld2_path)
            return nothing
        end
        clasnip_db = CLASNIP_DB[db_vcf_jld2_path]
        clasnip_db.access_time = now()
        clasnip_db.group_dict
    end
end
function clasnip_get_group_nsample(db_vcf_jld2_path::AbstractString)
    global CLASNIP_DB
    wait_for_lock(CLASNIP_DB_LOAD_LOCK) do
        if !haskey(CLASNIP_DB, db_vcf_jld2_path)
            return nothing
        end
        clasnip_db = CLASNIP_DB[db_vcf_jld2_path]
        clasnip_db.access_time = now()
        clasnip_db.nsample_group
    end
end
function clasnip_get_all(db_vcf_jld2_path::AbstractString)
    global CLASNIP_DB
    wait_for_lock(CLASNIP_DB_LOAD_LOCK) do
        if !haskey(CLASNIP_DB, db_vcf_jld2_path)
            return nothing,nothing,nothing,nothing
        end
        clasnip_db = CLASNIP_DB[db_vcf_jld2_path]
        clasnip_db.access_time = now()
        return (clasnip_db.db_vcf_parsed, clasnip_db.groups, clasnip_db.group_dict, clasnip_db.nsample_group)
    end
end


### automatically unload occasionally
function db_unload_check!()
    global CLASNIP_DB
    global DB_MEM_LIMIT
    global DB_PROTECT_TIME

    db_to_unload = String[]
    
    wait_for_lock(CLASNIP_DB_LOAD_LOCK) do

        used_mem = 0
        for clasnip_db in values(CLASNIP_DB)
            used_mem += clasnip_db.memory_size
        end

        if used_mem <= DB_MEM_LIMIT  # do not unload dbs
            return
        end

        for (db, clasnip_db) in CLASNIP_DB
            if clasnip_db.access_time + DB_PROTECT_TIME < now()
                # ready for unload
                push!(db_to_unload, db)
            end
        end
    end

    for db in db_to_unload
        clasnip_unload_database(db)
        GC.gc()
    end
end

function db_unload_task()
    global DB_UNLOAD_CHECK_INTERVAL
    while true
        db_unload_check!()
        sleep(DB_UNLOAD_CHECK_INTERVAL)
    end
end

DB_UNLOAD_TASK = @task db_unload_task()

"""
    db_unload_start()
Start periodically unloading old clasnip database if memory occupation is exceeded.
"""
function db_unload_start(; verbose=true)
    global DB_UNLOAD_TASK

    if istaskfailed(DB_UNLOAD_TASK) || istaskdone(DB_UNLOAD_TASK)
        verbose && @warn "DB_UNLOAD_TASK was interrupted or done. Restart."
        DB_UNLOAD_TASK = @task db_unload_task()
        schedule(DB_UNLOAD_TASK)
    elseif istaskstarted(DB_UNLOAD_TASK) # if done, started is also true
        verbose && @warn "DB_UNLOAD_TASK is running."
    else
        verbose && @info "DB_UNLOAD_TASK starts."
        schedule(DB_UNLOAD_TASK)
    end
end


"""
    db_unload_status() :: Symbol
Print the status of DB_UNLOAD_TASK. Return `:not_running` or `:running`.
"""
function db_unload_status(; verbose=true)
    global DB_UNLOAD_TASK
    if istaskfailed(DB_UNLOAD_TASK) || istaskdone(DB_UNLOAD_TASK)
        verbose && @info "DB_UNLOAD_TASK is not running."
        :not_running
    elseif istaskstarted(DB_UNLOAD_TASK)
        verbose && @info "DB_UNLOAD_TASK is running."
        :running
    else
        verbose && @info "DB_UNLOAD_TASK is not running."
        :not_running
    end
end

db_unload_start()
