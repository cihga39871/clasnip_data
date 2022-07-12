"""
    api_file_viewer(request;
        max_file_size = Config.FILE_VIEWER_MAX_SIZE
    )

# Request

- `request[:data]["filePath"]`: full file path on the server

# Response

- `463`: file not found, no permission.

- `464`: file too large.

- `200`: data is the file content.

"""
function api_file_viewer(request;
    max_file_size = Config.FILE_VIEWER_MAX_SIZE,
    file_regex_limit = Config.FILE_VIEWER_LIMIT_GENERAL,
    to_quasar_table::Bool = false,
    float_digits = 3, # only usable if to_quasar_table,
    dirs_without_permission_check::Vector = [Config.DB_DIR]
)
    data = try
        get_request_data!(request) |> JSON.parse
    catch
        return json_response(request, 400)
    end

    # owner check
    owner = "<public>"
    token_str = get(data, "token", nothing)
    username = get(data, "username", nothing)
    if !isnothing(token_str) && !isnothing(username)
        if is_token_valid(token_str, username)
            owner = username
        else
            return json_response(request, 440)
        end
    end

    # file path check
    file_path = get(data, "filePath", nothing)
    isnothing(file_path) &&  (return json_response(request, 400))

    occursin(file_regex_limit, file_path) || (return json_response(request, 463))
    isfile(file_path) || (return json_response(request, 463))
    filesize(file_path) > max_file_size && (return json_response(request, 464))

    # permission check
    analysis_dir = dirname(file_path)
    no_check_permission = map(dirs_without_permission_check) do d
        occursin(Regex("^" * d), analysis_dir)
    end |> any
    if no_check_permission
        nothing
    else
        public_owner_file = joinpath(analysis_dir, "owner.<public>")
        if !isfile(public_owner_file)
            # not public analysis
            owner_file = joinpath(analysis_dir, "owner.$owner")
            # user has no permission
            isfile(owner_file) || (return json_response(request, 463))
        end
    end

    if to_quasar_table
        df = try
            CSV.read(file_path, DataFrame; ntasks=1)
        catch
            return json_response(request, 463)
        end

        columns = [Dict(
            "name" => "col0",
            "field" => "col0",
            "label" => "#",
            "sortable" => true,
            "align" => "right"
        )]
        append!(columns, [
            Dict(
                "name" => "col$i",
                "field" => "col$i",
                "label" => name,
                "sortable" => true,
                "align" => (eltype(df[!,name]) <: Number ? "right" : "left")
            )
            for (i,name) in enumerate(names(df))
        ])

        row_data = [
            Dict(
                "col0" => n_row,
                [
                "col$i" => (val isa Float64 ? round(val, digits=float_digits) : val)
                for (i,val) in enumerate(r)
            ]...)
            for (n_row,r) in enumerate(eachrow(df))
        ]

        data = Dict(
            "columns" => columns,
            "row_data" => row_data
        )
        response_with_header(request, data=data)
    elseif occursin(r"log\.txt$", file_path)
        # For log files:
        #  do not print details of @info/@warn/@error
        file_data = readlog(file_path)
        response_with_header(request, data=file_data, content_type="text/html")
    else
        file_data = read(file_path)
        response_with_header(request, data=file_data, content_type="text/html")
    end
end

"""
    readlog(file_path)

Do not print details of @info/@warn/@error, and Mux unnamed stack traces.

It is faster and robuster than `grep -vE`. `grep` sometimes cause an error.
"""
function readlog(file_path)
    file_data = Vector{UInt8}()
    open(file_path, "r") do io
        for line in eachline(io, keep=true)
            if !occursin(r"^│ |^└ @|Mux.var\"#|^ +@ Mux", line)
                append!(file_data, Vector{UInt8}(line))
            end
        end
    end
    file_data
end
