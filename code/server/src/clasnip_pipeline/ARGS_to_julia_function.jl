
using Markdown

Base.tryparse(::Type{Nothing}, s::AbstractString) = nothing
Base.tryparse(::Type{Symbol }, s::AbstractString) = Symbol(s)
Base.tryparse(::Type{Regex  }, s::AbstractString) = Regex(s)
Base.tryparse(::Type{T      }, s::AbstractString) where {T<:AbstractString} = T(s)

"""
	tryparse(::Type{T}, s::AbstractString) where {T<:Any}

INJECTION WARNING: This function uses `eval(Meta.parse(s))`. Special characters are banned.
"""
function Base.tryparse(::Type{T}, s::AbstractString) where {T<:Any}
	# prevent injection by searching |> @ ( using import
	occursin(r"\|\>|\@|\(|using\s|import\s", s) && error("Invalid characters.")
	try
		res = eval(Meta.parse(s))
		if typeof(res) <: T
			try
				res2 = convert(T, res)
				return res2
			catch
				return res
			end
		else
			return nothing
		end
	catch
		return nothing
	end
end

function Base.tryparse(ts::Tuple, s::AbstractString)
	for t in ts
		res = tryparse(t, s)
		if res !== nothing
			return res
		end
	end
	nothing
end


"""
	ARGS_parse(
		args;
		positional_types::Tuple  = tuple()                 ,
		npositional_min::Int     = length(positional_types),
		keyword_names::Tuple     = tuple()                 ,
		keyword_types::Tuple     = tuple()                 ,
		keyword_defaults::Tuple  = tuple()                 ,
		args_to_show_docs::Tuple = ("--help", "-h")        ,
		docs_when_error          = ""
	) -> (ARGS_positional::Vector, ARGS_keyword::Dict)

Convert commandline arguments (`args::Vector{AbstractString}`) to Julia function arguments, and return `(ARGS_positional::Vector, ARGS_keyword::Dict)`.

The keyword formats in `args` include:
- `  KEYWORD=VALUE`
- ` -KEYWORD=VALUE`
- `--KEYWORD=VALUE`
- `  KEYWORD::TYPE=VALUE`
- ` -KEYWORD::TYPE=VALUE`
- `--KEYWORD::TYPE=VALUE`

`positional_types`: Tuples. Types of positional arguments. If one argument accepts multiple types, use `(TYPE1, TYPE2)`.

`npositional_min`: Number of minimum positional arguments. Default is the length of `positional_types`.

`keyword_names`: Tuples of String. The name of keyword arguments.

`keyword_types`: Tuples. Types of keyword arguments. If one argument accepts multiple types, use `(TYPE1, TYPE2)`.

`keyword_defaults`: Tuples. The default values of keywords.

`args_to_show_docs`: Tuples. Once an argument matches, show docs and exit with code 0. Default is `("--help", "-h")`.

`docs_when_error`: Show docs when parsing `args` with errors. Recommendation: `@eval(cmd_doc(@doc pcc_search))` because `@eval` prevents undefVar error when building shared library and `cmd_doc` converts function doc to argument doc. Other egs: `(@doc function_name)`, or `md"Markdown documents"`, or `"String documents"`.
"""
function ARGS_parse(args;
		positional_types::Tuple  = tuple(),
		npositional_min::Int     = length(positional_types),
		keyword_names::Tuple     = tuple(),
		keyword_types::Tuple     = tuple(),
		keyword_defaults::Tuple  = tuple(),
		args_to_show_docs::Tuple = ("--help", "-h"),
		docs_when_error          = ""
	)
	if !(length(keyword_names) == length(keyword_types) == length(keyword_defaults))
		error("length of keyword arguments not equal.")
	end

	for help_arg in args_to_show_docs
		if help_arg in args
			show(stderr, "text/plain", docs_when_error)
			exit(0)
		end
	end

	ARGS_positional = []
	ARGS_keyword    = Dict()

	npositional = length(positional_types)
	nkeyword    = length(keyword_names)

	if npositional_min == -1
		npositional_min = npositional
	end

	for i in 1:nkeyword
		ARGS_keyword[keyword_names[i]] = keyword_defaults[i]
	end

	ipositional = 1
	for arg in args
		is_arg_keyword = false
		for i in 1:nkeyword
			keyword_name = keyword_names[i]
			keyword_type = keyword_types[i]
			if occursin(Regex("^-{0,2}" * keyword_name * "="), arg)
				keyword_value_indicate = match(Regex("^-{0,2}" * keyword_name * "=(.*)"), arg).captures[1]

				keyword_value = tryparse(keyword_type, keyword_value_indicate)
				if keyword_value === nothing && keyword_type != Nothing
					@error "parsing error in the argument $arg: designated value $keyword_value_indicate cannot be parsed as $keyword_type."
					show(stderr, "text/plain", docs_when_error)
					exit(1)
				end
				ARGS_keyword[keyword_name] = keyword_value
				is_arg_keyword = true
				break

			elseif occursin(Regex("^-{0,2}" * keyword_name * "::[A-Za-z0-9]*="), arg)
				keyword_type_indicate, keyword_value_indicate = match(Regex("^-{0,2}" * keyword_name * "::([A-Za-z0-9]*)=(.*)"), arg).captures

				try
					eval(Meta.parse(keyword_type_indicate))
				catch
					@error "parsing error in the argument $arg: designated type $keyword_type_indicate is not a valid Julia type."
					show(stderr, "text/plain", docs_when_error)
					exit(1)
				end

				if !(eval(Meta.parse(keyword_type_indicate)) <: keyword_type)
					@error "parsing error in the argument $arg: designated type $keyword_type_indicate is not belongs to $keyword_type."
					show(stderr, "text/plain", docs_when_error)
					exit(1)
				end

				keyword_value = tryparse(keyword_type, keyword_value_indicate)
				if keyword_value === nothing && keyword_type != Nothing
					@error "parsing error in the argument $arg: designated value $keyword_value_indicate cannot be parsed as $keyword_type."
					show(stderr, "text/plain", docs_when_error)
					exit(1)
				end
				ARGS_keyword[keyword_name] = keyword_value
				is_arg_keyword = true
				break
			end
		end

		if !is_arg_keyword
			if ipositional > npositional
				ipositional = npositional  # ... of positional arguments
			end
			positional_type = positional_types[ipositional]

			positional_value = tryparse(positional_type, arg)
			if positional_value === nothing && positional_type != Nothing
				@error "parsing error in the argument $arg: $arg cannot be parsed as $positional_type."
				show(stderr, "text/plain", docs_when_error)
				exit(1)
			end
			push!(ARGS_positional, positional_value)

			ipositional += 1
		end
	end
	if length(ARGS_positional) < npositional_min
		@error "parsing error: number of positional arguments is less than expect."
		show(stderr, "text/plain", docs_when_error)
		exit(1)
	end
	ARGS_positional, ARGS_keyword
end

"""
	cmd_doc(doc::Markdown.MD) -> Markdown.MD

Convert normal Julia function documentation to commandline tool documentation that is compatible with `ARGS_parse`.

# Example:

	cmd_doc(@doc eval)
"""
function cmd_doc(doc::Markdown.MD)
	str = string(doc)

	splitted = split(str, "```")
	nsplitted = length(splitted)

	# modify code blook ```cmd```
	for i in 2:2:nsplitted
		code = splitted[i]
		code = replace(code, r"[\(\)\,\;] ?| *-> *[A-Za-z0-9\{\}]*" => " ")
		splitted[i] = code
	end

	# search small code block `cmd`
	for i in 1:2:nsplitted
		substr = splitted[i]
		splitted_substr = split(substr, "`")
		nsplitted_substr = length(splitted_substr)

		# modify small code block `cmd`
		for j in 2:2:nsplitted_substr
			code = splitted_substr[j]
			code = replace(code, r"[\(\)\,\;] ?| *-> *[A-Za-z0-9\{\}]*" => " ")
			splitted_substr[j] = code
		end
		splitted[i] = join(splitted_substr, '`')
	end
	str_md = Markdown.parse(join(splitted, "```"))
end
