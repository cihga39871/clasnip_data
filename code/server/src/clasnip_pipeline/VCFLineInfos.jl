const FORMAT_to_AD_idx = Dict{String, Union{Nothing,Int64}}()

struct VCFLineInfo
    chr::String
    pos::Int64
    ref::String
    alt::String
    ad::String
end
function VCFLineInfo(line::AbstractString; delim::Char = '\t')
    if length(line) == 0 || line[1] == '#'
        return nothing
    end

    start = 1
    delim_idx = findnext(delim, line, start)
    CHROM = String(@view line.data[start:delim_idx-1])

    start = delim_idx + 1
    delim_idx = findnext(delim, line, start)
    POS = tryparse(Int64, @view line[start:delim_idx-1])
    if isnothing(POS)
        return nothing
    end

    start = delim_idx + 1
    delim_idx = findnext(delim, line, start)
    # ID

    start = delim_idx + 1
    delim_idx = findnext(delim, line, start)
    REF = String(@view line.data[start:delim_idx-1])
    if length(REF) == 0 || REF == "N"
        return nothing
    end

    start = delim_idx + 1
    delim_idx = findnext(delim, line, start)
    ALT = String(@view line.data[start:delim_idx-1])
    if length(ALT) == 0
        return nothing
    end

    start = delim_idx + 1
    delim_idx = findnext(delim, line, start)
    # QUAL

    start = delim_idx + 1
    delim_idx = findnext(delim, line, start)
    # FILTER

    start = delim_idx + 1
    delim_idx = findnext(delim, line, start)
    # INFO

    start = delim_idx + 1
    delim_idx = findnext(delim, line, start)
    FORMAT = String(@view line.data[start:delim_idx-1])
    
    AD_index = get(FORMAT_to_AD_idx, FORMAT, missing)
    if ismissing(AD_index)  # FORMAT not recorded, compute it
        AD_index = findfirst(x -> x == "AD", split(FORMAT, ':'))
        FORMAT_to_AD_idx[FORMAT] = AD_index
    end

    if isnothing(AD_index)  # no AD in FORMAT
        return nothing
    end

    start = delim_idx + 1
    delim_idx = findnext(delim, line, start)
    if isnothing(delim_idx)
        delim_idx = length(line) + 1
    end
    DATA = StringView(@view line.data[start:delim_idx-1])

    if length(DATA) < AD_index
        # Example of AD == "."
        # CP031505.1      76733   .       TTAGCAA .       0       .       DP=0;DPB=0;EPPR=0;GTI=0;MQMR=0;NS=1;NUMALT=0;ODDS=0;PAIREDR=0;PQR=0;PRO=0;QR=0;RO=0;RPPR=0      GT:DP:AD:RO:QR:AO:QA    .
        return nothing
    end

    # find AD in DATA
    start = 1
    n = 1
    while n < AD_index
        delim_idx = findnext(':', DATA, start)
        start = delim_idx + 1
        n += 1
    end
    delim_idx = findnext(':', DATA, start)
    if isnothing(delim_idx)
        delim_idx = length(DATA) + 1
    end
    AD = String(@view DATA.data[start:delim_idx - 1])
    if length(AD) == 0
        return nothing
    end

    VCFLineInfo(CHROM, POS, REF, ALT, AD)
end


