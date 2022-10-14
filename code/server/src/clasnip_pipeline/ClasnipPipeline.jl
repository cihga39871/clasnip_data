__precompile__(false)
module ClasnipPipeline

using ..Config
using ..ClasnipApi

include("hot-fix.jl")

using Pipelines, JobSchedulers
scheduler_start()

using Base.Threads  # SpinLock
using Dates
using DataFrames, DataFramesMeta, DelimitedFiles
using Statistics  # median of SNP diff matrix
using StatsPlots, Plots # plots
# using ROCAnalysis
using Distances, Clustering # heatmap
using CSV
using JLD2
using StatsBase, AverageShiftedHistograms, Random # statistics, density and p values
# using GFF3
using FASTX # fa2fq

# plotlyjs()
gr()
#
include("ReplicateStats.jl")
using .ReplicateStats

include("config.jl")

include("api.vcf_stats.jl")

using StringViews
include("MemoryEfficientIOs.jl")
using .MemoryEfficientIOs
include("VCFLineInfos.jl")
include("api.vcf_db_generation3.jl")

include("dependencies.jl")
include("ARGS_to_julia_function.jl")

include("pipeline_programs.jl")

include("db_build.jl")
export clasnip_db_build, has_bowtie2_index, build_bowtie2_index

include("db_load.jl")

include("db_cross_validation_load.jl")
include("db_cross_validation.jl")
export stratifed_split, group_dict_to_labels, clasnip_db_cross_validation


export clasnip_load_database,
    clasnip_unload_database,
    clasnip_get_db,
    clasnip_get_groups,
    clasnip_get_group_dict,
    clasnip_get_group_nsample,
    clasnip_get_all

include("sample_classify.jl")
export clasnip_classify

include("cmdline.jl")

end
