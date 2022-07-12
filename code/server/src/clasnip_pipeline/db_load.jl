
"""
    CLASNIP_DB = Dict{String, Any}(
        db_vcf_jld2_path => [db_mlst, groups, group_dict, nsample_group, last_modified::DateTime, memory_in_bytes::Int]
    )
"""
CLASNIP_DB = Dict{String, Any}()
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

    # db_vcf_jld2_path = "/home/jc/test/Clasnip/data/CLso_genes/haplotypes/GCA_000183665.1_ASM18366v1_genomic.db-vcf.jld2"
    (!reload && haskey(CLASNIP_DB, db_vcf_jld2_path)) && return nothing

    # check whether other program is loading
    wait_for_lock(CLASNIP_DB_LOAD_LOCK)

    try
        CLASNIP_DB_LOADING[db_vcf_jld2_path] = true

        # start loading
        @load db_vcf_jld2_path db_vcf_parsed groups group_dict nsample_group
        db_mlst = parsed_db_vcf_to_mlst(db_vcf_parsed::DataFrame, groups::Vector)
        CLASNIP_DB[db_vcf_jld2_path] = [db_mlst, groups, group_dict, nsample_group, now(), 0]

        # Compute the amount of memory, in bytes
        CLASNIP_DB[db_vcf_jld2_path][6] = Base.summarysize(CLASNIP_DB[db_vcf_jld2_path])
    catch e
        @error Pipelines.timestamp() * "Fail to load clasnip database: $db_vcf_jld2_path" exception=e
    finally
        delete!(CLASNIP_DB_LOADING, db_vcf_jld2_path)
        unlock(CLASNIP_DB_LOAD_LOCK);
    end


    return nothing
end

function clasnip_unload_database(db_vcf_jld2_path::AbstractString)
    global CLASNIP_DB
    wait_for_lock(CLASNIP_DB_LOAD_LOCK)

    ret = try
        if haskey(CLASNIP_DB, db_vcf_jld2_path)
            delete!(CLASNIP_DB, db_vcf_jld2_path)
            true
        else
            false
        end
    catch e
        @error "clasnip_unload_database: $db_vcf_jld2_path" exception=(e, catch_backtrace())
        false
    finally
        unlock(CLASNIP_DB_LOAD_LOCK);
    end
    return ret
end

function clasnip_get_db(db_vcf_jld2_path::AbstractString)
    global CLASNIP_DB
    wait_for_lock(CLASNIP_DB_LOAD_LOCK)

    if !haskey(CLASNIP_DB, db_vcf_jld2_path)
        unlock(CLASNIP_DB_LOAD_LOCK);
        return nothing
    end
    CLASNIP_DB[db_vcf_jld2_path][5] = now()
    res = CLASNIP_DB[db_vcf_jld2_path][1]
    unlock(CLASNIP_DB_LOAD_LOCK);
    return res
end
function clasnip_get_groups(db_vcf_jld2_path::AbstractString)
    global CLASNIP_DB
    wait_for_lock(CLASNIP_DB_LOAD_LOCK)

    if !haskey(CLASNIP_DB, db_vcf_jld2_path)
        unlock(CLASNIP_DB_LOAD_LOCK);
        return nothing
    end
    CLASNIP_DB[db_vcf_jld2_path][5] = now()
    res = CLASNIP_DB[db_vcf_jld2_path][2]
    unlock(CLASNIP_DB_LOAD_LOCK);
    return res
end
function clasnip_get_group_dict(db_vcf_jld2_path::AbstractString)
    global CLASNIP_DB
    wait_for_lock(CLASNIP_DB_LOAD_LOCK)

    if !haskey(CLASNIP_DB, db_vcf_jld2_path)
        unlock(CLASNIP_DB_LOAD_LOCK);
        return nothing
    end
    CLASNIP_DB[db_vcf_jld2_path][5] = now()
    res = CLASNIP_DB[db_vcf_jld2_path][3]
    unlock(CLASNIP_DB_LOAD_LOCK);
    return res
end
function clasnip_get_group_nsample(db_vcf_jld2_path::AbstractString)
    global CLASNIP_DB
    wait_for_lock(CLASNIP_DB_LOAD_LOCK)

    if !haskey(CLASNIP_DB, db_vcf_jld2_path)
        unlock(CLASNIP_DB_LOAD_LOCK);
        return nothing
    end
    CLASNIP_DB[db_vcf_jld2_path][5] = now()
    res = CLASNIP_DB[db_vcf_jld2_path][4]
    unlock(CLASNIP_DB_LOAD_LOCK);
    return res
end
function clasnip_get_all(db_vcf_jld2_path::AbstractString)
    global CLASNIP_DB
    wait_for_lock(CLASNIP_DB_LOAD_LOCK)

    if !haskey(CLASNIP_DB, db_vcf_jld2_path)
        unlock(CLASNIP_DB_LOAD_LOCK);
        return nothing,nothing,nothing,nothing
    end
    items = CLASNIP_DB[db_vcf_jld2_path]
    CLASNIP_DB[db_vcf_jld2_path][5] = now()
    unlock(CLASNIP_DB_LOAD_LOCK);
    return (items[1], items[2], items[3], items[4])
end


### automatically unload occasionally
function db_unload_check!()
    global CLASNIP_DB
    global DB_MEM_LIMIT
    global DB_PROTECT_TIME

    wait_for_lock(CLASNIP_DB_LOAD_LOCK)

    used_mem = 0
    for db_items in values(CLASNIP_DB)
        used_mem += db_items[6]
    end

    if used_mem <= DB_MEM_LIMIT  # do not unload dbs
        unlock(CLASNIP_DB_LOAD_LOCK);
        return
    end

    db_to_unload = String[]
    for (db, items) in CLASNIP_DB
        last_access_time = items[5]
        if last_access_time + DB_PROTECT_TIME < now()
            # ready for unload
            push!(db_to_unload, db)
        end
    end

    unlock(CLASNIP_DB_LOAD_LOCK);

    for db in db_to_unload
        clasnip_unload_database(db)
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
