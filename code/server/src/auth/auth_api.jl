"""
    api_get_token(request)

Get token and salt for `api_login`.

## Request

- `request[:data]`: <u>plain text</u> `"\$username"`.

## Response

- `200`: login successful: return data in JSON format: `value::String = token * salt`. Salt is 8 chars.

- `455`: (1) invalid special characters in username (2) username not found or (3) wrong password.
"""
function api_get_token(request)
    global sql_db

    username = trim_blank(get_request_data!(request))
    validate(username, rule=Config.VALIDATION_RULE_NO_SPECIAL) || (return json_response(request, 455))
    validate_null(username) || (return json_response(request, 455))

    db_result = DBInterface.execute(sql_db, """
        SELECT * FROM user WHERE username = "$username" LIMIT 1;
    """)
    isempty(db_result) && (return json_response(request, 455))
    df = DataFrame(db_result)

    name = df[1, :name]
    salt = df[1, :salt]

    token = generate_token(username, name)
    value = token.token * salt

    return json_response(request, data = Dict(
        "value" => value
    ))
end


"""
    api_login(request)

User log in.

## Request

- `request[:data]`: <u>plain text</u> `"\$username\\n\$passcode\\n\$token"`. Passcode is `sha3_384(token * sha3_384(salt * password))`.

## Response

- `200`: login successful: return data in JSON format: `token::String`, `username::String`, and `name::String`.

- `400`: invalid request.

- `455`: (1) invalid special characters in username (2) username not found or (3) wrong password.

- `500`: internal error.
"""
function api_login(request)
    global sql_db

    data = get_request_data!(request)
    splitted = split(data, r"\r\n|\n|\r")

    if length(splitted) == 3
        try
            username = trim_blank(splitted[1])
            pass_code = splitted[2]
            token_str = splitted[3]

            if !has_token(token_str, username)
                return json_response(request, 400)
            end

            # for logging in json_response: do not print pass_code to logs
            # request[:data] = replace(data, pass_code => "<pass_code>", count = 1)

            validate(username, rule=Config.VALIDATION_RULE_NO_SPECIAL) || (return json_response(request, 455))
            validate_null(username) || (return json_response(request, 455))

            db_result = DBInterface.execute(sql_db, """
                SELECT * FROM user WHERE username = "$username" LIMIT 1;
            """)

            isempty(db_result) && (destory_token(token_str, username); return json_response(request, 455))

            df = DataFrame(db_result)

            # if try many times today, no check and return fail
            time_last_try = convert(DateTime, Millisecond(df.time_last_try[1]))
            n_try_fail = df.n_try_fail[1]
            time_now = now()
            is_same_day = yearmonthday(time_last_try) == yearmonthday(time_now)
            if is_same_day && n_try_fail >= Config.MAX_N_FAILED_LOGIN
                # try many times today, no check and return fail
                destory_token(token_str, username)
                return json_response(request, 472)
            end

            # check pass_code
            if pass_code == encrypt(df[1, :password], token_str)
                # login success
                name = df[1, :name]
                email = df[1, :email]
                authorize_token(token_str, username)

                # update time_last_try, n_try_fail
                DBInterface.execute(sql_db, """
                    UPDATE user SET time_last_try = $(time_now.instant.periods.value), n_try_fail = 0 WHERE username = '$username'
                """)

                return json_response(request, data = Dict(
                    "token" => token_str,
                    "username" => username,
                    "name"  => name,
                    "email" => email
                ))
            else
                # login failed
                if is_same_day
                    n_try_fail += 1
                else
                    n_try_fail = 1
                end
                # update time_last_try, n_try_fail
                DBInterface.execute(sql_db, """
                    UPDATE user SET time_last_try = $(time_now.instant.periods.value), n_try_fail = $n_try_fail WHERE username = '$username'
                """)
                destory_token(token_str, username)
                return json_response(request, 455)
            end

        catch e
            rethrow(e)
            destory_token(token_str, username)
            return json_response(request, 500)
        end
    else
        return json_response(request, 400)
    end
end


"""
    api_register(request)

New user registration.

## Request

- `request[:data]::StringVector`: `"\$username\\n\$password"\\n{'name': '\$name', 'email': '\$email'}`.

## Response

- `200`: registration successful: return `token::String`, `username::String`, and `name::String`.

- `400`: invalid request.

- `456`: invalid form input.

- `457`: username exists.

- `500`: internal error.

- `473`: Password Requirement Not Met: At least 6 characters.

- `474`: Password And Username Cannot Be Same.
"""
function api_register(request)
    global sql_db

    data = get_request_data!(request)
    splitted = split(data, r"\r\n|\n|\r")

    length(splitted) != 3 && (return json_response(request, 400))

    # get form values
    username = trim_blank(splitted[1])
    password = splitted[2]
    others = trim_blank(splitted[3])

    # for logging in json_response: do not print password to logs
    request[:data] = replace(data, password => "<password>", count = 1)

    others_dict = try
        JSON.parse(others)
    catch
        return json_response(request, 400)
    end
    name = trim_blank(get(others_dict, "name", "User"))
    email = trim_blank(get(others_dict, "email", ""))

    # validate and encrypt
    validate(username, rule=Config.VALIDATION_RULE_NO_SPECIAL) || (return json_response(request, 456))
    validate(name)     || (return json_response(request, 456))
    validate(email)    || (return json_response(request, 456))

    validate_null(username) || (return json_response(request, 456))
    validate_null(name) || (return json_response(request, 456))
    validate_null(email) || (return json_response(request, 456))

    # password complecity check
    password_code = password_complecity_code(username, password)
    if password_code != 200
        return json_response(request, password_code)
    end

    salt = randstring()
    password = encrypt(password, salt)
    time_last_try = now().instant.periods.value

    sql = """
        INSERT INTO user (username, password, name, email, salt, time_last_try, n_try_fail)
        VALUES ("$username", "$password", "$name", "$email", "$salt", $time_last_try, 0);
    """
    try
        SQLite.execute(sql_db, sql)
        mkpath(joinpath(Config.USER_DIR, username), mode=0o755)
    catch e
        if typeof(e) == SQLite.SQLiteException && e.msg == "UNIQUE constraint failed: user.username"
            return json_response(request, 457)
        else
            @error e
            return json_response(request, 500)
        end
    end
    json_response(request, 200)
end

"""
    password_complecity_code(username, password)

Check passoword complecity. If ok, return 200, else return error code.
"""
function password_complecity_code(username::AbstractString, password::AbstractString)
    if length(password) < 6
        return 473  # Password Requirement Not Met: At least 8 characters
    elseif username == password
        return 474  # Password And Username Cannot Be Same
    else
        return 200
    end
end

"""
    api_validate_token([f::Function,] request)

Validate whether an authentication token is valid or not.

## Arguments and Request

- `f::Function`: the function should have exact one parameter: `request`. If the token is validated, return `f(request)` or 202 response if `f` is missing.

- `request[:data]::StringVector`: in JSON format, root contains `token` and `username`.

## Response

- `202`: token accepted (if `f` is missing).

- `400`: invalid request.

- `440`: login timeout.

- `459`: need login to access (no token info).

- `other response`: when token is accepted, return the response of `f`.
"""
function api_validate_token(f::Function, request)
    data = try
        get_request_data!(request) |> JSON.parse
    catch
        return json_response(request, 400)
    end

    token_str = get(data, "token", nothing)
    isnothing(token_str) && (return json_response(request, 459))

    username = get(data, "username", nothing)
    isnothing(username) && (return json_response(request, 459))

    token_validity = is_token_valid(token_str, username)
    if token_validity
        return f(request)
    else
        return json_response(request, 440)
    end
end

function api_validate_token(request)
    api_validate_token(request -> json_response(request, 202), request)
end

function api_validate_token_header(f::Function, request; logging_body::Bool=false)
    token_str = get(request[:headers], "token", "null")
    token_str == "null" && (return json_response(request, 459, logging_body=logging_body))

    username = get(request[:headers], "username", "null")
    username == "null" && (return json_response(request, 459, logging_body=logging_body))

    token_validity = is_token_valid(token_str, username)
    if token_validity
        return f(request)
    else
        return json_response(request, 440, logging_body=logging_body)
    end
end

function api_validate_token_header(request; logging_body::Bool=false)
    api_validate_token(request -> json_response(request, 202, logging_body=logging_body), request)
end

"""
    api_logout(request)

User log out.

## Request

- `request[:data]::StringVector`: in JSON format, root contains `token` and `username`.

## Response

- `202`: log out successfully or token not found.

- `400`: invalid request.

- `460`: failed to log out and token not destroyed.
"""
function api_logout(request)
    data = try
        get_request_data!(request) |> JSON.parse
    catch
        return json_response(request, 400)
    end

    token_str = get(data, "token", "")
    isnothing(token_str) && (return json_response(request, 460))
    isempty(token_str) && (return json_response(request, 460))

    username = get(data, "username", "")

    if destory_token(token_str, username)
        return json_response(request, 202)
    else
        return json_response(request, 460)
    end
end
