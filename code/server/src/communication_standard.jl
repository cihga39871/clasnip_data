using Dates

"""
	@show_repl exs...

Prints one or more expressions, and their results, to `Pipelines.stdout_origin`, and returns the last result.
"""
macro show_repl(exs...)
    blk = Expr(:block)
    for ex in exs
        push!(blk.args, :(println(Pipelines.stdout_origin, $(sprint(Base.show_unquoted,ex)*" = "),
                                  repr(begin local value = $(esc(ex)) end))))
    end
    isempty(exs) || push!(blk.args, :value)
    return blk
end

function Base.get(ps::Array{Pair{SubString{String},SubString{String}},1}, k, default)
    for p in ps
        if p.first == k
            return p.second
        end
    end
    default
end

function response_with_header(
	request,
	status::Int = 200;
	data = "",
	content_type = "application/json; charset=utf-8",
	enable_logging = Config.LOGGING_REQUEST,
	logging_body = Config.LOGGING_REQUEDT_BODY
)
	if enable_logging
		logging_body ? print_request(request, status) : print_request_no_body(request, status)
	end
	if Config.SHOW_REQUEST
		@show_repl request
	end

    headers = HttpCommon.headers()
    headers["Content-Type"] = content_type
	headers["Server"] = Config.SERVER_NAME

	request_origin = get(request[:headers], "Origin", "")
    if is_allowed_origin(request_origin)
        headers["Access-Control-Allow-Origin"] = request_origin
    end

    if !isempty(Config.ALLOWED_HEADERS)
        headers["Access-Control-Allow-Headers"] = join(Config.ALLOWED_HEADERS, ", ")
    end

    Dict(
       :headers => headers,
       :body => format_response_body(data),
	   :status => status
    )
end

json_response = response_with_header

format_response_body(data::Dict) = json(data)
format_response_body(data::Vector{UInt8}) = data
format_response_body(data::Vector) = json(data)
format_response_body(data) = data



function is_allowed_origin(request_origin)
	"*" in Config.ALLOWED_ORIGINS && (return true)
	return (request_origin in Config.ALLOWED_ORIGINS)
end

"""
	get_request_data!(request)

Get `request[:data]`.

- If `:data` does not exist, return "".

- If `:data` is `Vector{UInt8}`, convert to `String`, replace `request[:data]` with the string and return.

- If `:data` is other types, return itself.
"""
function get_request_data!(request)
	data = get(request, :data, "")
	if typeof(data) == Vector{UInt8}
		request[:data] = request[:data] |> String
	else
		data
	end
end

# ClasnipMux.print_request(request)

function print_request(request::Dict, status::Int)
	str = string(
		now(), " ",
		string(get(request, :uri, "")),
		" [", get(request, :method, ""), " ", string(status), "] ",
		get(HTTP.Messages.STATUS_MESSAGES, status, status), "\n"
	)
	print(status < 400 ? Pipelines.stdout_origin : Pipelines.stderr_origin, str)

	get_request_data!(request)

	# check whether data is json
	try
		data = JSON.parse(get(request, :data, ""))
		req = copy(request)
		req[:data] = data
		str *= YAML.write(req)
	catch
		str *= YAML.write(request)
	finally
		if status < 400
			with_logger(Config.OUT_LOGGER) do
				@info(str)
			end
			flush(Config.OUT_IO)
		else
			with_logger(Config.ERR_LOGGER) do
				@warn(str)
			end
			flush(Config.ERR_IO)
		end
	end
	nothing
end
function print_request_no_body(request::Dict, status::Int)
	str = string(
		now(), " ",
		string(get(request, :uri, "")),
		" [", get(request, :method, ""), " ", string(status), "] ",
		get(HTTP.Messages.STATUS_MESSAGES, status, status), "\n"
	)
	print(status < 400 ? Pipelines.stdout_origin : Pipelines.stderr_origin, str)

	# check whether data is json
	try
		req = Dict()
		for item in request
			item.first == :data && continue
			req[item.first] = item.second
		end
		str *= YAML.write(req)
	catch
		nothing
	finally
		if status < 400
			with_logger(Config.OUT_LOGGER) do
				@info(str)
			end
			flush(Config.OUT_IO)
		else
			with_logger(Config.ERR_LOGGER) do
				@warn(str)
			end
			flush(Config.ERR_IO)
		end
	end
	nothing
end
