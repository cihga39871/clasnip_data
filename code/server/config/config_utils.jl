
# Create Config.secret.jl if not exists.
# Configs in Config.secret.jl will override the file's configuration.
config_secret_path = joinpath(@__DIR__, "config.secret.jl")
isfile(config_secret_path) || touch(config_secret_path)
include(config_secret_path)

function show_request(b::Bool)
    global SHOW_REQUEST = b
end
function logging_request(b::Bool)
    global LOGGING_REQUEST = b
end
function logging_request_body(b::Bool)
    global LOGGING_REQUEDT_BODY = b
end
function job_logs_to_std(b::Bool)
    global JOB_LOGS_TO_STD = b
end
function clean_tmp_files(b::Bool)
    global CLEAN_TMP_FILES = b
end

"""
    isdev()

Is current Clasip in development mode? Check whether --dev, -dev, or dev in ARGS.
"""
function isdev()
    any(["--dev" in ARGS, "-dev" in ARGS, "dev" in ARGS])
end

function activate_dev_mode()
    @info "Activating development mode."
    global HOST = HOST_DEV
    global PORT = PORT_DEV
    global SQL_PATH = SQL_PATH_DEV
    global PROJECT_ROOT_FOLDER = PROJECT_ROOT_FOLDER_DEV
    global USER_DIR = USER_DIR_DEV
    global ANALYSIS_DIR = ANALYSIS_DIR_DEV
    global DB_DIR = DB_DIR_DEV
    global LOG_FOLDER = LOG_FOLDER_DEV
    global OUT_FILE = OUT_FILE_DEV
    global ERR_FILE = ERR_FILE_DEV
    nothing
end



# check development mode; update variables
isdev() && activate_dev_mode()

# creating directories and files
isdir(dirname(Config.SQL_PATH)) || mkpath(dirname(Config.SQL_PATH))

mkpath(Config.PROJECT_ROOT_FOLDER, mode=0o750)
chmod(Config.PROJECT_ROOT_FOLDER, 0o750, recursive = true)

mkpath(Config.USER_DIR, mode=0o750)
chmod(Config.USER_DIR, 0o750, recursive = true)

mkpath(Config.ANALYSIS_DIR, mode=0o750)
chmod(Config.ANALYSIS_DIR, 0o750, recursive = true)

mkpath(Config.DB_DIR, mode=0o750)
chmod(Config.DB_DIR, 0o750, recursive = true)

mkpath(Config.LOG_FOLDER, mode=0o700)
chmod(Config.LOG_FOLDER, 0o700, recursive = true)

"""
    sql_db = SQLite.DB(Config.SQL_PATH)
"""
sql_db = SQLite.DB(Config.SQL_PATH)

# the following will be defined in __init__()
OUT_IO = nothing
ERR_IO = nothing
OUT_LOGGER = nothing
ERR_LOGGER = nothing
ORIGINAL_LOGGER = nothing # global logger

function __init__()

    cd(Config.LOG_FOLDER)

    # connect to loggers
    if isnothing(OUT_IO) || OUT_IO.name != "<file $(Config.OUT_FILE)>"
        global OUT_IO = open(Config.OUT_FILE, "a+")
        global OUT_LOGGER = SimpleLogger(OUT_IO)
        @info "Logging normal requests to $(Config.OUT_FILE)"
        atexit(() -> close(OUT_IO))
    end
    if isnothing(ERR_IO) || ERR_IO.name != "<file $(Config.ERR_FILE)>"
        global ERR_IO = open(Config.ERR_FILE, "a+")
        global ERR_LOGGER = SimpleLogger(ERR_IO)
        @info "Logging failed requests to $(Config.ERR_FILE)"
        atexit(() -> close(ERR_IO))
    end
    if isnothing(ORIGINAL_LOGGER)
        global ORIGINAL_LOGGER = current_logger()
    end
    nothing
end
