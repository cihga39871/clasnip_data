module Config

using Dates, SQLite, Logging

## Server and Security Settings
SERVER_NAME = "Clasnip"
HOST = "0.0.0.0"
PORT = 9889
HOST_DEV = "0.0.0.0"
PORT_DEV = 9599

"The path of SQLite"
SQL_PATH = joinpath(@__DIR__, "..", "db", "Clasnip.sqlite")
SQL_PATH_DEV = joinpath(@__DIR__, "..", "db", "Clasnip.dev.sqlite")

# Prevention of database injection
"General Regex rule to validate user inputs"
const VALIDATION_RULE_GENERAL = r"^[^\^\&\|\"\'\`\$\#\\\/\;\=\(\)\[\]\{\}\<\>\*\+\;\?\~]+$"

"The Regex rule that does not allow special characters"
const VALIDATION_RULE_NO_SPECIAL = r"^[A-Za-z0-9\-\_]+$"

# Token clear time
TOKEN_CLEAR_MILLISECONDS_FREQUENCY       = 1000 * 60 * 20  # 20 min
TOKEN_CLEAR_MILLISECONDS_AFTER_CREATED   = 1000 * 60 * 60 * 18  # 18 h
TOKEN_CLEAR_MILLISECONDS_AFTER_LAST_USED = 1000 * 60 * 90  # 30 min

# Access-Control-Allow-Origin headers to XMLHttpRequest
ALLOWED_ORIGINS = ["*"]
ALLOWED_HEADERS = ["*"]

## Server control (only valid when enabling dynamic key)
"Dynamic key is not needed in Clasnip."
ENABLE_DYNAMIC_KEY = false
DYNAMIC_KEY_PATH = joinpath(@__DIR__, "dynamic_key.txt")
DYNAMIC_KEY_UPDATE_SECOND = 300

## User account
"Maximum attempts of failed login every day."
MAX_N_FAILED_LOGIN = 5

## Clasnip Analysis
"Location of the root directory of Clasnip web data"
PROJECT_ROOT_FOLDER = joinpath(homedir(), "ClasnipWebData")
USER_DIR = joinpath(PROJECT_ROOT_FOLDER, "user")
ANALYSIS_DIR = joinpath(PROJECT_ROOT_FOLDER, "analysis")  # start with / but not end with /
DB_DIR = joinpath(PROJECT_ROOT_FOLDER, "database")  # start with / but not end with /

PROJECT_ROOT_FOLDER_DEV = joinpath(homedir(), "ClasnipWebData-Dev")
USER_DIR_DEV = joinpath(PROJECT_ROOT_FOLDER_DEV, "user")
ANALYSIS_DIR_DEV = joinpath(PROJECT_ROOT_FOLDER_DEV, "analysis")  # start with / but not end with /
DB_DIR_DEV = joinpath(PROJECT_ROOT_FOLDER_DEV, "database")  # start with / but not end with /

# File downloader/viewer limitation
"The maximum file size that can be transferred from server to user."
FILE_VIEWER_MAX_SIZE = 1024 * 1024 * 20

"The file paths that allowed in file viewer API"
FILE_VIEWER_LIMIT_GENERAL = Regex("^$ANALYSIS_DIR|^$DB_DIR/[A-Za-z0-9_-]+/(data.|plot.|stat.)")

# checking new database names
"The character distance between new database name and all existing database names"
DATABASE_NAME_DISTANCE = 2

# FASTQ length limitation
"The maximum fastq size that can be saved to server from the new analysis page."
FASTQ_MAX_SIZE = 5000

# computational resources
RESUME_ANALYSIS = true
CLEAN_TMP_FILES = true

# schedular
"""
    SCHEDULER_MAX_CPU = 8
The maximum CPU the scheduler can use. Caution: by default, the Julia uses  SCHEDULER_MAX_CPU + 2 threads. The remaining two threads are for Job allocating and response to HTML requests. It won't work right now since job will not switch between threads (JULIA v1.6.1).
"""
SCHEDULER_MAX_CPU = 8  # max cpu for all polychrome jobs
SCHEDULER_UPDATE_SECOND = 0.3

## Logging
LOG_FOLDER = joinpath(PROJECT_ROOT_FOLDER, "logs")
OUT_FILE = joinpath(LOG_FOLDER, "log.$(today()).out")
ERR_FILE = joinpath(LOG_FOLDER, "log.$(today()).err")

LOG_FOLDER_DEV = joinpath(PROJECT_ROOT_FOLDER_DEV, "logs")
OUT_FILE_DEV = joinpath(LOG_FOLDER_DEV, "log.$(today()).out")
ERR_FILE_DEV = joinpath(LOG_FOLDER_DEV, "log.$(today()).err")

"Log each request header"
LOGGING_REQUEST = true

"Log each request body (some API will disable it)"
LOGGING_REQUEDT_BODY = true

"Log in Julia plain format (for development)"
SHOW_REQUEST = false

"Jobs will not use log files, but use stdout and stderr instead."
JOB_LOGS_TO_STD = false

## Do not change:
include("config_utils.jl")
export isdev,
show_request, logging_request, logging_request_body,
sql_db

end  # module
