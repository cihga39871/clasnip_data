
mutable struct Token
    token::String
    username::String
    name::String
    created::DateTime
    lastused::DateTime
    authorized::Bool
end

# Those variables are needed to be accessed from other module
# but cannot be exported so have to use with token_dict
token_dict = Dict{String, Token}()
TIME_LAST_TOKEN_CLEAR = now()

function update_time_last_token_clear(t)
    global TIME_LAST_TOKEN_CLEAR = t
end

"""
    generate_token(username, name)::Token

Generate a new token. It is generated when someone try to login with `username` before validating password. The token will be valid via `authorize_token(...)` after password is good.
"""
function generate_token(username, name)::Token

    token_str = randstring(rand(50:60))
    n_generate = 1
    while haskey(token_dict, token_str)
        if n_generate > 10
            @error "Failed to generate token. Token pool might be full. n_generate = $n_generate"
        end
        token_str = randstring(rand(50:60))
        n_generate += 1
    end
    time_now = now()
    token = Token(token_str, username, name, time_now, time_now, false)

    # register
    clean_old_tokens()
    token_dict[token_str] = token
    return token
end


"""
    authorize_token(token_str::AbstractString, username::AbstractString)::Bool

Authorize a new generated token.

A token is generated when someone try to login with `username` before validating password. The token will be valid via `authorize_token(...)` after password is good.
"""
function authorize_token(token_str::AbstractString, username::AbstractString)::Bool
    if isempty(username)
        @warn "SECURITY ALERT: CAUTION: Attempt to authorize a token but no username!" when=now() username token_str
        return false
    end
    if haskey(token_dict, token_str)
        token = token_dict[token_str]
        if token.username == username
            token.authorized = true
            return true
        else
            @warn "SECURITY ALERT: CAUTION: Attempt to authorize a token but username not paired!" when=now() username token_str token
            return false
        end
    else
        @warn "SECURITY ALERT: CAUTION: Attempt to authorize a token but token not found!" when=now() username token_str
        return false
    end
end

function has_token(token_str::AbstractString, username::AbstractString)
    if haskey(token_dict, token_str)
        token = token_dict[token_str]
        return token.username == username
    else
        return false
    end
end

function is_token_valid(token_str::AbstractString, username::AbstractString;
    milliseconds_after_created::Int64   = Config.TOKEN_CLEAR_MILLISECONDS_AFTER_CREATED,
    milliseconds_after_last_used::Int64 = Config.TOKEN_CLEAR_MILLISECONDS_AFTER_LAST_USED
)

    if isempty(username)
        @warn "SECURITY ALERT: CAUTION: Attempt to access with token but no username!" when=now() username token_str
        return false
    end

    if haskey(token_dict, token_str)
        token = token_dict[token_str]
        if token.username == username
            time_now = now()
            if (time_now - token.created).value < milliseconds_after_created &&
                    (time_now - token.lastused).value < milliseconds_after_last_used
                if token.authorized
                    token.lastused = time_now
                    return true
                else
                    @warn "SECURITY ALERT: CAUTION: Attempt to access an unauthorized token!" when=now() username token_str token
                end
            else
                pop!(token_dict, token_str)
                return false
            end
        else
            @warn "SECURITY ALERT: CAUTION: Attempt to access but token and username not paired!" when=now() username token_str token
            return false
        end
    else
        return false
    end
end

function destory_token(token_str::AbstractString, username::AbstractString)
    if haskey(token_dict, token_str)
        token = token_dict[token_str]
        if token.username == username
            try
                pop!(token_dict, token_str)
            catch
            end
            return true
        end
    end
    false
end

function clean_old_tokens(;
    milliseconds_frequency::Int64   = Config.TOKEN_CLEAR_MILLISECONDS_FREQUENCY,
    milliseconds_after_created::Int64   = Config.TOKEN_CLEAR_MILLISECONDS_AFTER_CREATED,
    milliseconds_after_last_used::Int64 = Config.TOKEN_CLEAR_MILLISECONDS_AFTER_LAST_USED
)::Bool

    time_now = now()
    update_time_last_token_clear(time_now)

    if (time_now - TIME_LAST_TOKEN_CLEAR).value < milliseconds_frequency
        # skip clean because it is too close from last clean
        return false
    end

    keys_to_clean = String[]
    for (key, token) in token_dict
        if (time_now - token.created).value > milliseconds_after_created ||
                (time_now - token.lastused).value > milliseconds_after_last_used
            push!(keys_to_clean, key)
        end
    end
    for key in keys_to_clean
        pop!(token_dict, key)
    end
    true
end

"""
    encrypt(password::AbstractString, salt::AbstractString = "")

Password encrypt.

`bytes2hex(sha3_384(salt * s))`
"""
function encrypt(s::AbstractString, salt::AbstractString = "")
    bytes2hex(sha3_384(salt * s))
end

function validate_null(s::AbstractString)
    s != "null"
end
validate_null(n::Nothing) = false
