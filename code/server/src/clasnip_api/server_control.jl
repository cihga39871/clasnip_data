"""
    api_dynamic_key(f::Function, request)
    api_dynamic_key(request)

Check whether the first item of request["path"] is the same as the dynamic key.

DynamicKey.validate will return false when `Config.ENABLE_DYNAMIC_KEY==false`
"""
function api_dynamic_key(f::Function, request)
    # validate using dynamic key
    if DynamicKey.validate(request[:path])
        f(request)
    else
        return json_response(request, 404)
    end
end
function api_dynamic_key(request)
    # validate using dynamic key
    if DynamicKey.validate(request[:path])
        return json_response(request, 200)
    else
        return json_response(request, 404)
    end
end

"""
    update_database()

After removing database files on server, maintainer have to call it to sync in-memory database.
"""
function update_database()
    # add new database to Config, do not remove old
    init_clasnip_db_info()

    # remove invalid database from Config
    name_to_delete = String[]
    vcf_to_unload = String[]
    for (name, info) in CLASNIP_DB_INFO
        if !is_valid_clasnip_db_info(info)
            push!(name_to_delete, name)
            push!(vcf_to_unload, get(info, "dbVcfReduced", ""))
        end
    end
    for name in name_to_delete
        init_clasnip_db_info(name)
    end

    # clean sensitive data for new_analysis_api
    db_desensitization()

    # free memory if the database vcf is loaded
    for db_vcf in vcf_to_unload
        ClasnipPipeline.clasnip_unload_database(db_vcf)
    end
end

function api_update_database(request)
    update_database()
    json_response(request, 200, data="OK.")
end

function api_revise_retry(request)
    Revise.retry()
    json_response(request, 200, data="OK.")
end
