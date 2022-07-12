
using Pipelines

JULIA_PROJECT_ROOT = pkgdir(@__MODULE__)

julia_project_arg = if isnothing(JULIA_PROJECT_ROOT)
    ``
elseif any(occursin.(r"--project", Base.julia_cmd().exec))  # already contain --project=..., do not need here
    ``
else
    `--project=$JULIA_PROJECT_ROOT`
end

julia = CmdDependency(
    exec = `$(Base.julia_cmd()) $julia_project_arg`,
    test_args = `--version`
)

CJC_DEP_SAMTOOLS = get(ENV, "CJC_DEP_SAMTOOLS", "samtools")
SAMTOOLS = CmdDependency(
    exec = `$CJC_DEP_SAMTOOLS`,
    test_args = `--version`,
    validate_success = true,
    validate_stdout = x -> occursin(r"^samtools \d+", x)
)

CJC_DEP_BOWTIE2 = get(ENV, "CJC_DEP_BOWTIE2", "bowtie2")
BOWTIE2 = CmdDependency(
    exec = `$CJC_DEP_BOWTIE2`,
    test_args = `--version`,
    validate_success = true,
    validate_stdout = x -> occursin(r"bowtie2-align-s version \d+", x)
)

CJC_DEP_FREEBAYES = get(ENV, "CJC_DEP_FREEBAYES", "freebayes")
FREEBAYES = CmdDependency(
    exec = `$CJC_DEP_FREEBAYES`,
    test_args = `--version`,
    validate_success = true,
    validate_stdout = x -> occursin(r"version:", x)
)
