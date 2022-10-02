#!julia

@info "Please run the code in interactive mode! It is necessary to download external files and change directories in the script."

using DataFrames
using CSV
using JobSchedulers
using DataFrames: mean

# directory (clso_v5_16s) can be downloaded from https://github.com/cihga39871/clasnip_data/tree/master/data/database/clso_v5_16s
# after downloading, decompress all .xz files (using unxz if your system is Linux)
cd("/home/jc/ClasnipWebData/database/clso_v5_16s")

identity_res = CSV.read("data.identity_scores.txt", DataFrame)

# low coverage samples are not 16S data, so will be removed.
low_cvg_res = CSV.read("stat.low_coverages.txt", DataFrame)

all_samples = unique(identity_res.LABEL)
low_cvg_samples = Set(low_cvg_res.LABEL)

# remove GCA_xxx because they are whole-genomic sequences, and BLCA cannot handle them.
samples_16s = filter(x -> !(x in low_cvg_samples || occursin("GCA", x)), all_samples)

### BLCA db creation

# directory (CLso_12haplotypes_corrected5) can be downloaded and extracted from https://github.com/cihga39871/clasnip_data/blob/master/data/database_input.tar.xz
BLCA_analysis_dir = "/usr/software/BLCA/clso/CLso_12haplotypes_corrected5"
cd(BLCA_analysis_dir)
# 16s sample list
samples_16s_list = open("$BLCA_analysis_dir/16S_lists.txt", "w+")
for i in samples_16s
    println(samples_16s_list, i)
end
close(samples_16s_list)

# db taxonomy label for 16s samples

# play a trick here: change species to haplotype since BLCA was originally built for species classification. Here we want it to classify CLso haplotypes.
db_tax_io = open("$BLCA_analysis_dir/16S_db_tax.txt", "w+")
for i in samples_16s
    group = dirname(i)
    rank = "species:CLso $group;genus:Liberibacter;family:Rhizobiaceae;order:Hyphomicrobiales;class:Alphaproteobacteria;phylum:Proteobacteria;superkingdom:Bacteria;"
    accession_numbers = readlines(`grep -oE ">[A-Za-z0-9\.]*" $i`)
    accession_numbers = replace.(accession_numbers, ">" => "")
    for acc in accession_numbers
        println(db_tax_io, "$acc\t$rank")
    end
end
close(db_tax_io)

# make blast db for BLCA
run(pipeline(`cat $samples_16s`, "16S_db.fasta"))

run(`makeblastdb -in 16S_db.fasta -parse_seqids -blastdb_version 5 -title "custom_clso_16S_db" -dbtype nucl`)

# BLCA program can be downloaded from https://github.com/qunfengdong/BLCA
# python 2.blca_main.py -i FASTA -r 16S_db_tax.txt -q 16S_db.fasta # -o *.blca.out
BLCA_main_script = "/usr/software/BLCA/2.blca_main.py"
scheduler_start()

for sample in samples_16s
    j = Job(`python $BLCA_main_script -i $sample -r 16S_db_tax.txt -q 16S_db.fasta`; name=sample, ncpu=2)
    submit!(j)
end

wait_queue()

blca_outs = samples_16s .* ".blca.out"

blca_classification_res = readlines(`grep -oE "CLso [^;]*|Unclassified" $blca_outs`)

blca_classification_res_df = DataFrame()
blca_classification_res_df.LABELED_GROUP = dirname.(blca_classification_res)
blca_classification_res_df.SAMPLE = [split(i, ":")[1][1:end-15] for i in basename.(blca_classification_res)]
blca_classification_res_df.BLCA_RESULT = [replace(split(i, ":")[2], "CLso " => "") for i in basename.(blca_classification_res)]

blca_classification_res_df

# copy the result of Clasnip database ID 'clso v5 16s': only C/MG701017 is misclassified
blca_classification_res_df.CLASNIP_RESULT = deepcopy(blca_classification_res_df.LABELED_GROUP)

wrong_idx = findfirst(blca_classification_res_df.SAMPLE .== "MG701017")
wrong_sample_clasnip_res = filter(r -> r.LABEL == "C/MG701017.fasta", identity_res)
# Row│ GROUP    PERCENT_MATCHED  MATCHED_SNP_SCORE  COVERED_SNP_SCORE  RANK   TIED_RANK  LABELED_GROUP  SAME   LABEL             CDF        PROBABILITY 
#  1 │ U               1.0                 34.0               34.0         1        1.0  C              false  C/MG701017.fasta  1.0          0.45322
#  2 │ C               0.981032            31.0322            31.6322      2        2.0  C               true  C/MG701017.fasta  0.820515     0.371874
#  3 │ D               0.931034            29.7               31.9         3        3.0  C              false  C/MG701017.fasta  0.0868586    0.0393661
#  4 │ A               0.926609            29.4598            31.7931      4        4.0  C              false  C/MG701017.fasta  0.180407     0.0817642
#  5 │ B               0.8887              29.5731            33.2769      5        5.0  C              false  C/MG701017.fasta  0.118654     0.0537762
#  6 │ H               0.852941            29.0               34.0         6        6.5  C              false  C/MG701017.fasta  0.0          0.0
#  7 │ F               0.852941            29.0               34.0         6        6.5  C              false  C/MG701017.fasta  0.0          0.0
#  8 │ E               0.777778            14.0               18.0         7        8.0  C              false  C/MG701017.fasta  0.0          0.0
#  9 │ H-Con           0.772727            17.0               22.0         8        9.0  C              false  C/MG701017.fasta  0.0          0.0
# 10 │ Cras2           0.736842            14.0               19.0         9       10.5  C              false  C/MG701017.fasta  0.0          0.0
# 11 │ Cras1b          0.736842            14.0               19.0         9       10.5  C              false  C/MG701017.fasta  0.0          0.0
# 12 │ G               0.707692            15.3333            21.6667     10       12.0  C              false  C/MG701017.fasta  0.0          0.0
# 13 │ Cras1a          0.7                 14.0               20.0        11       13.0  C              false  C/MG701017.fasta  0.0          0.0

blca_classification_res_df.CLASNIP_RESULT[wrong_idx] = "U"

CSV.write("16S_BLCA_and_Clasnip_classification_res.tsv", blca_classification_res_df, delim="\t")


# performance evaluation
struct ClassifierMetrics
    TP::Int
    FP::Int
    TN::Int
    FN::Int
    TPR::Float64
    TNR::Float64
    PPV::Float64
    NPV::Float64
    FNR::Float64
    FPR::Float64
    FDR::Float64
    FOR::Float64
    ACC::Float64
    F1::Float64
end
function ClassifierMetrics(TP::Int, FP::Int, TN::Int, FN::Int)
    # https://en.wikipedia.org/wiki/Sensitivity_and_specificity
    # sensitivity, recall, hit rate, or true positive rate (TPR)
    TPR = TP / (TP + FN)
    #specificity, selectivity or true negative rate (TNR)
    TNR = TN / (TN + FP)
    # precision or positive predictive value (PPV)
    PPV = TP / (TP + FP)
    # negative predictive value (NPV)
    NPV = TN / (TN + FN)
    # miss rate or false negative rate (FNR)
    FNR = 1 - TPR
    # fall-out or false positive rate (FPR)
    FPR = 1 - TNR
    # false discovery rate (FDR)
    FDR = 1 - PPV
    # false omission rate (FOR)
    FOR = 1 - NPV
    # accuracy (ACC)
    ACC = (TP + TN) / (TP + TN + FP + FN)
    # F1 score is the harmonic mean of precision and sensitivity:
    F1 = 2TP / (2TP + FP + FN)
    ClassifierMetrics(TP, FP, TN, FN, TPR, TNR, PPV, NPV, FNR, FPR, FDR, FOR, ACC, F1)
end


function ClassifierMetrics(labeled_group::Vector, classified_group::Vector, group::AbstractString)
    TP = sum((labeled_group .== group) .& (group .== classified_group))
    FN = sum((labeled_group .== group) .& (group .!= classified_group))
    TN = sum((labeled_group .!= group) .& (group .!= classified_group))
    FP = sum((labeled_group .!= group) .& (group .== classified_group))
    ClassifierMetrics(TP, FP, TN, FN)
end

function ClassifierMetrics(labeled_group::Vector, classified_group::Vector)
    # labeled_group = blca_classification_res_df.LABELED_GROUP
    # classified_group = blca_classification_res_df.BLCA_RESULT
    groups = unique(labeled_group)
    
    metrics_groups = [ClassifierMetrics(labeled_group, classified_group, group) for group in groups]
    hcat(DataFrame(GROUP = groups), DataFrame(metrics_groups))
end

BLCA_performance = ClassifierMetrics(blca_classification_res_df.LABELED_GROUP, blca_classification_res_df.BLCA_RESULT)
Clasnip_performance = ClassifierMetrics(blca_classification_res_df.LABELED_GROUP, blca_classification_res_df.CLASNIP_RESULT)

CSV.write("16S_BLCA_performance.tsv", BLCA_performance, delim="\t")
CSV.write("16S_Clasnip_performance.tsv", Clasnip_performance, delim="\t")

program_performance = vcat(
    hcat(DataFrame(PROGRAM = ["BLCA" for _ in 1:nrow(BLCA_performance)]), BLCA_performance),
    hcat(DataFrame(PROGRAM = ["Clasnip" for _ in 1:nrow(Clasnip_performance)]), Clasnip_performance)
)

CSV.write("16S_BLCA_and_Clasnip_performance.tsv", program_performance, delim="\t")


gdf = groupby(program_performance, :PROGRAM)
mean_performance = combine(gdf, 
    :TPR => mean => :TPR,
    :TNR => mean => :TNR,
    :PPV => (x -> mean(replace(x, NaN => 0))) => :PPV,
    :NPV => mean => :NPV,
    :ACC => mean => :ACC,
    :F1 => mean => :F1,
)
CSV.write("16S_BLCA_and_Clasnip_mean_performance.tsv", mean_performance, delim="\t")
