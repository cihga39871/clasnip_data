
# hot fix when Base.stdout is changed
function Base.readchomp(x::Base.AbstractCmd)
    io = IOBuffer()
    run(pipeline(x, stdout=io))
    res = chomp(String(take!(io)))
    close(io)
    res
end
function Base.readchomp(io::IO, x::Base.AbstractCmd)
    run(pipeline(x, stdout=io))
    chomp(String(take!(io)))
end
