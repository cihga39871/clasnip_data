#! julia -i
using Pkg

if "-h" in ARGS || "--help" in ARGS
	println("""
	Clasnip Server.

	Options:

	-h, --help      Show this help page.
	--keep          Keep the server run in backend (add a sleep loop at the end).
	--host HOST     Up server to HOST:PORT.
	--port PORT     Up server to HOST:PORT.
	--dev           Up server to HOST:PORT_DEV.
	--no-precompile Do not run the precompile (and test) task.
	""")
	exit()
end

Pkg.activate(@__DIR__)
Pkg.instantiate()

push!(LOAD_PATH, joinpath(@__DIR__, "src"))

using Revise
using Reexport
@reexport using ClasnipMux

# get host and port from ARGS
host = if "--host" in ARGS
	try
		ARGS[findfirst(x -> x == "--host", ARGS) + 1]
	catch
		ClasnipMux.Config.HOST
	end
else
	ClasnipMux.Config.HOST
end

port = if "--port" in ARGS
	try
		x = ARGS[findfirst(x -> x == "--port", ARGS) + 1]
		parse(Int64, x)
	catch
		ClasnipMux.Config.PORT
	end
else
	ClasnipMux.Config.PORT
end

# run server
ClasnipMux.run_server(host = host, port = port)

# test and precompile
if !("--no-precompile" in ARGS)
	@info "Precompilation task can be accessed by variable :precompile_task"
	precompile_task = Threads.@spawn include("$(@__DIR__)/src/precompile.jl")
end

if "--keep" in ARGS
	while true
		sleep(5)
	end
end
