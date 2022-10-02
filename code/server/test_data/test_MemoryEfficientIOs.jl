
using MemoryEfficientIOs
using Test

vcf_path = "/home/jc/ClasnipWebData/failed_database/Dickeya_typical/extracted/Dickeya_202208/Dickeya_zeae/GCA_021614795.1_ASM2161479v1_genomic.fasta.fq.bam.all.vcf"

io = open(vcf_path, "r")
meio = MemoryEfficientIO(open(vcf_path, "r"))
seekstart(io)
seekstart(meio)

while !eof(io) && !eof(meio)
    @test readline(io) == readline(meio)
end
@test eof(io)
@test eof(meio)

## speed test
seekstart(io)
seekstart(meio)

@info "Time and Memory of IOStream: readline"
@time while !eof(io)
    readline(io)
end
@info "Time and Memory of MemoryEfficientIO: readline"
@time while !eof(io)
    readline(io)
end

## close io
close(meio)
close(io)

set_INIT_N_BYTE()
