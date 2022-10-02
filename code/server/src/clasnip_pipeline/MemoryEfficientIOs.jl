module MemoryEfficientIOs

using Reexport
@reexport using StringViews

export MemoryEfficientIO

"""
    INIT_N_BYTE = 32768

Length of StringVectors allocated when creating MemoryEfficientIO
"""
const INIT_N_BYTE = 32768
function set_INIT_N_BYTE(value::Int64 = 32768)
    global INIT_N_BYTE = value
end

mutable struct MemoryEfficientIO{T<: IO} <: IO
    io::T
    a::StringView{Vector{UInt8}}
    b::StringView{Vector{UInt8}}
    first::Int64
    last::Int64
end
function MemoryEfficientIO{T}(io::T) where T <: IO
    Base.@_lock_ios io begin
        a = StringView(Vector{UInt8}(undef, INIT_N_BYTE))
        b = StringView(Vector{UInt8}(undef, INIT_N_BYTE))
        last = readbytes!(io, a.data, max(length(a.data), INIT_N_BYTE))
    end
    MemoryEfficientIO(io, a, b, 1, last)
end
function MemoryEfficientIO(io::T) where T <: IO
    MemoryEfficientIO{typeof(io)}(io::T)
end
function MemoryEfficientIO(file_path::AbstractString)
    MemoryEfficientIO(open(file_path, "r"))
end

function Base.close(meio::MemoryEfficientIO)
    meio.first = 1
    meio.last = 0
    close(meio.io)
end
Base.isopen(meio::MemoryEfficientIO) = isopen(meio.io)

function Base.seekstart(meio::MemoryEfficientIO)
    try
        seekstart(meio.io)
        meio.first = 1
        meio.last = 0
    catch e
        rethrow(e)
    end
end
function Base.seekend(meio::MemoryEfficientIO)
    try
        seekend(meio.io)
        meio.first = 1
        meio.last = 0
    catch e
        rethrow(e)
    end
end
function Base.seek(meio::MemoryEfficientIO, pos)
    try
        seek(meio.io, pos)
        meio.first = 1
        meio.last = 0
    catch e
        rethrow(e)
    end
end

function Base.show(io::IO, ::MIME"text/plain", meio::MemoryEfficientIO)
    println(io, string("MemoryEfficientIO{", meio.io, "}"))
end
function Base.show(io::IO, meio::MemoryEfficientIO)
    println(io, string("MemoryEfficientIO{", meio.io, "}"))
end

function endofbuffer(meio::MemoryEfficientIO)
    meio.first > meio.last
end

function Base.eof(meio::MemoryEfficientIO)
    eof(meio.io) && endofbuffer(meio)
end

const empty_line = StringView("")
function Base.readline(meio::MemoryEfficientIO; keep::Bool = false)
    if endofbuffer(meio)  # meio.first > meio.last
        if eof(meio.io)
            return empty_line
        else
            nbyte = unsafe_readbytes_and_refresh!(meio)
            if nbyte == 0  # end of meio.io, nothing to read
                return empty_line
            end

            _readline_when_has_buffer(meio; keep = keep)
        end
    else  # has buffer, meio.first > meio.last
        _readline_when_has_buffer(meio; keep = keep)
    end
end


function unsafe_readbytes_and_refresh!(meio::MemoryEfficientIO)
    meio.first = 1
    meio.last = readbytes!(meio.io, meio.a.data, max(length(meio.a.data), INIT_N_BYTE))
end

function findinrange(char::UInt8, vec::Vector{UInt8}, first::Int64, last::Int64 = length(vec))
    last = min(last, length(vec))
    while first <= last
        if vec[first] == char
            return first
        end
        first += 1
    end
    nothing
end

function _readline_when_has_buffer(meio::MemoryEfficientIO; keep::Bool = false)
    # 0x0a \n
    idx_eol = findinrange(0x0a, meio.a.data, meio.first, meio.last)
    if isnothing(idx_eol) # line not complete
        nbyte = meio.last - meio.first + 1
        # the line stores at meio.b
        resize!(meio.b.data, nbyte)
        copyto!(meio.b.data, 1, meio.a.data, meio.first, nbyte)
        # repeat read bytes until \n or end of meio.io (nbyte==0)
        while true
            nbyte = unsafe_readbytes_and_refresh!(meio)
            if nbyte == 0
                break
            end
            idx_eol = findinrange(0x0a, meio.a.data, meio.first, meio.last)  # meio.last == nbyte
            len_b = length(meio.b.data)
            if isnothing(idx_eol)
                resize!(meio.b.data, len_b + nbyte)
                # the line stores at meio.b
                copyto!(meio.b.data, len_b + 1, meio.a.data, meio.first, nbyte)
                meio.first = nbyte + 1
            else  # find \n
                resize!(meio.b.data, len_b + idx_eol)
                copyto!(meio.b.data, len_b + 1, meio.a.data, meio.first, idx_eol)
                meio.first = idx_eol + 1
                break
            end
        end
        if keep
            return meio.b
        else
            idx = idx_before_eol(meio.b.data)
            return StringView(@view meio.b.data[1:idx])
        end
    else # line complete at idx_eol
        if keep
            line = StringView(@view meio.a.data[meio.first:idx_eol])
        else
            idx = idx_before_eol(meio.a.data, idx_eol)
            line = StringView(@view meio.a.data[meio.first:idx])
        end
        meio.first = idx_eol + 1
        return line
    end
end

function idx_before_eol(vec::Vector{UInt8}, idx_eol::Int64 = length(vec))
    if idx_eol <= 1 || length(vec) <= 1
        return 0
    elseif vec[idx_eol - 1] == 0x0d
        return idx_eol - 2
    else
        return idx_eol - 1
    end
end

end  # module


