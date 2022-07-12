# Linux only

using Tar

"""
    decompress(file; outdir=nothing, unchange=true, force=false, showwarn=true, iteration=true, as_file=true)

- `as_file`: treate as file or dir. Only useful when extracting zip file. tar are treated as dir, others are treated as file.

Return `decompressed_file_name::String`. If failed, return `nothing`.
"""
function decompress(file; outdir=nothing, unchange::Bool=true, force::Bool=false, showwarn::Bool=true, iteration::Bool=true, as_file::Bool=true)
    ###### validation check
    if !isfile(file)
        @error "Decompressing: File not found" FILE=file
        return nothing
    end
    # output dir
    if outdir != nothing
        try
            mkpath(outdir, mode=0o755)
        catch
            @error "Decompress: permission error: cannot create path" DIRECTORY=outdir
            return nothing
        end
    end

    ###### initializing
    # get header
    io = open(file, "r")
    head = UInt8[]
    readbytes!(io, head, 263)
    close(io)
    nhead = length(head)

    ###### judge compress type by file magic and then decompress
    # .gz
    if ismagicmatch(head, 1:3, UInt8[0x1f, 0x8b, 0x08])
        decomp_cmd = try
            run(`pigz --version`)
            `pigz -cd`
        catch
            `gzip -cd`
        end
        new_file = _decompress_specific(file, outdir, ".gz", ".ungz", decomp_cmd, force, as_file=true)
    # .zip
    elseif ismagicmatch(head, 1:4, UInt8[0x50, 0x4b, 0x03, 0x04])
        decomp_cmd = as_file ? `unzip -p` : `unzip -d $outdir`
        new_file = _decompress_specific(file, outdir, ".zip", ".unzip", decomp_cmd, force, as_file=as_file)
        if !as_file  # will not iterate over dir
            return outdir
        end
    # .xz
    elseif ismagicmatch(head, 1:6, UInt8[0xfd, 0x37, 0x7a, 0x58, 0x5a, 0x00])
        new_file = _decompress_specific(file, outdir, ".xz", ".unxz", `xz -cd`, force, as_file=true)
    # .Z
    elseif ismagicmatch(head, 1:2, UInt8[0x1f, 0x9d])
        new_file = _decompress_specific(file, outdir, ".Z", ".unZ", `zcat`, force, as_file=true)
    # bzip2 .bz2
    elseif ismagicmatch(head, 1:3, UInt8[0x42, 0x5a, 0x68])
        new_file = _decompress_specific(file, outdir, ".bz2", ".unbz2", `bzip2 -cd`, force, as_file=true)
    # .tar
    elseif ismagicmatch(head, 258:262, UInt8[0x75, 0x73, 0x74, 0x61, 0x72])
        new_file = _decompress_tar(file, outdir, force)

    # not compressed file, return in the else block.
    else
        showwarn && @warn "Decompress: Uncompressed file or unknown compress type" FILE=file
        if outdir == nothing
            return file
        else
            new_file = joinpath(outdir, basename(file))
            if unchange
                cp(file, new_file, force=force)
            else
                if file != new_file
                    mv(file, new_file, force=force)
                end
            end
            return new_file
        end

    end

    if new_file == nothing
        @error "Decompress: Failed" FILE=file
        return nothing
    end

    unchange || rm(file, force=true)

    if iteration && !isdir(new_file)
        final_file = decompress(new_file; outdir=outdir, unchange=false, force=force, showwarn=false, iteration=true)
        return final_file
    else
        return new_file
    end
end

"""
    compress_info(file)

Return (compress_type::Symbol, decompress_command::Cmd)

Caution: if tar, return `(:tar, \`\`)`; if unknown, return `(:unknown, \`\`)`
"""
function compress_info(file)
    ###### validation check
    if !isfile(file)
        @error "compress_info: File not found" FILE=file
        return nothing
    end

    ###### initializing
    # get header
    io = open(file, "r")
    head = UInt8[]
    readbytes!(io, head, 263)
    close(io)
    nhead = length(head)

    ###### judge compress type by file magic and then decompress
    # .gz
    if ismagicmatch(head, 1:3, UInt8[0x1f, 0x8b, 0x08])
        try
            run(`pigz --version`)
            return (:gz, `pigz -cd`)
        catch
            return (:gz, `gzip -cd`)
        end
    # .zip
    elseif ismagicmatch(head, 1:4, UInt8[0x50, 0x4b, 0x03, 0x04])
        return (:zip, `unzip -p`)
    # .xz
    elseif ismagicmatch(head, 1:6, UInt8[0xfd, 0x37, 0x7a, 0x58, 0x5a, 0x00])
        return (:xz, `xz -cd`)
    # .Z
    elseif ismagicmatch(head, 1:2, UInt8[0x1f, 0x9d])
        return (:Z, `zcat`)
    # bzip2 .bz2
    elseif ismagicmatch(head, 1:3, UInt8[0x42, 0x5a, 0x68])
        return (:bz2, `bzip2 -cd`)
    # .tar
    elseif ismagicmatch(head, 258:262, UInt8[0x75, 0x73, 0x74, 0x61, 0x72])
        return (:tar, ``)

    # not compressed file, return in the else block.
    else
        return (:unknown, ``)
    end
end

function ismagicmatch(file_head::Vector{UInt8}, magic_range, expect_magic::Vector{UInt8})
    if length(file_head) >= maximum(magic_range)
        if file_head[magic_range] == expect_magic
            return true
        else
            return false
        end
    else
        @warn "Ismagicmatch: not match for `file_head` not long enough."
        return false
    end
end

"""
return filename or `nothing`. `nothing` mean failed.
"""
function _decompress_specific(file, outdir, possible_extension, new_extension, command, force::Bool; as_file=true)
    # format extensions
    if possible_extension[1] != '.'
        possible_extension = "." * possible_extension
    end
    if new_extension[1] != '.'
        new_extension = "." * new_extension
    end

    # get new file
    if occursin(Regex("$(possible_extension)\$"), file)  # possible_extension detected
        new_file = file[1:end-length(possible_extension)]
    else
        new_file = file * new_extension
    end

    # change directory to outdir
    if outdir != nothing
        new_file = joinpath(outdir, basename(new_file))
    end

    # check if file exist
    if isfile(new_file) && !force
        @warn "Decompress: Uncompressed file exists. Use it, or run `decompress(force=true)` to overwrite it." FILE=new_file
        return new_file
    end

    # try to run command to decompress file
    try
        if as_file
            run(pipeline(`$command $file`, stdout=new_file))
        else
            run(`$command $file`)
        end
        return new_file
    catch
        false
        @error "Decompress: command exit with error" DETECTED_TYPE=uppercase(possible_extension) COMMAND=`$command $file` REDIRECT_TO=new_file
        return nothing
    end
end

"""
return filename or `nothing`. `nothing` mean failed.
"""
function _decompress_tar(file, outdir, force::Bool)
    new_file = try
        # only way to get the file name in tar.
        # tar filename is not relevant to the file inside.
        # readchomp(pipeline(`tar -tf $file`, `awk 'NR==1{print}'`))
        file_listing = Tar.list(file)
        if length(file_listing) == 0
            @error "Decompress: cannot list filenames." DETECTED_TYPE="TAR"
            return nothing
        else
            file_listing[1].path
        end
    catch
        @error "Decompress: cannot list filenames." DETECTED_TYPE="TAR"
        return nothing
    end


    if outdir != nothing
        new_file = joinpath(outdir, basename(new_file))
    end

    cmd = outdir == nothing ? `tar -xf $file` : `tar -xf $file -C $outdir`
    cmd = force ? cmd : `$cmd --keep-old-files`
    try
        run(cmd)
        return new_file
    catch
        @error "Decompress: command exit with error" DETECTED_TYPE="TAR" COMMAND=cmd
        new_file = nothing
        return nothing
    end
end
