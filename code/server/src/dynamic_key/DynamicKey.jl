module DynamicKey

using Random
using ..Config

DYNAMIC_KEY = randstring(40)

function update_key()
    global DYNAMIC_KEY
    DYNAMIC_KEY = randstring(40)
end

function validate(k::AbstractString)
    global DYNAMIC_KEY
    Config.ENABLE_DYNAMIC_KEY && k == DYNAMIC_KEY
end
function validate(kv::Vector)
    if isempty(kv)
        return false
    end
    validate(kv[1])
end

rm(Config.DYNAMIC_KEY_PATH, force=true)
touch(Config.DYNAMIC_KEY_PATH)
chmod(Config.DYNAMIC_KEY_PATH, 0o600)

open(Config.DYNAMIC_KEY_PATH, "w+") do io
    write(io, DYNAMIC_KEY)
end

if Config.ENABLE_DYNAMIC_KEY
    @async while true
        sleep(Config.DYNAMIC_KEY_UPDATE_SECOND)
        update_key()
        open(Config.DYNAMIC_KEY_PATH, "w+") do io
            write(io, DYNAMIC_KEY)
        end
    end
end

end
