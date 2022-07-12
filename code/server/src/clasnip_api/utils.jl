
"""
    file_locate(basename, dir, files=readdir(dir)) = 

    basename in files ? joinpath(dir, basename) : nothing
"""
function file_locate(basename, dir, files=readdir(dir))
    basename in files ? joinpath(dir, basename) : nothing
end
