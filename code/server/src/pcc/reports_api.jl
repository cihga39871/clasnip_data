"""
    api_reports(request; search_limit::Regex = Config.FILE_SEARCH_LIMIT_GENERAL)

Return the report file lists of a given project directory.

## Request
- `request[:data]["projectDir"]`: the PolyChome analysis folder.

## Response

- `400`: invalid request.

- `458`: `request[:data]["projectDir"]` is out of `search_limit` or not a valid PolyChome analysis folder.

- `200`: successful, and return a JSON format data as below. Caution: some files and fields might be missing according to varied analysis methods.

```json
{
    "job_info": {
        "Dickeya_depth1": {
            "log": [
                "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-logs-Dickeya_depth1.2020-11-16T08:50:21.857.out.txt"
            ],
            "arg": [
                "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-args-Dickeya_depth1.json"
            ],
            "error_log": [
                "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-logs-Dickeya_depth1.2020-11-16T08:50:21.857.err.txt"
            ]
        },
        "Dickey_0jy_depth1": {
            "log": [
                "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-logs-Dickey_0jy_depth1.2020-11-16T09:55:25.198.out.txt",
                "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-logs-Dickey_0jy_depth1.2020-11-17T10:20:42.466.out.txt"
            ],
            "arg": [
                "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-args-Dickey_0jy_depth1.json"
            ],
            "error_log": [
                "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-logs-Dickey_0jy_depth1.2020-11-16T09:55:25.198.err.txt",
                "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-logs-Dickey_0jy_depth1.2020-11-17T10:20:42.466.err.txt"
            ]
        }
    },
    "pcc-0-raw": {
        "multiQC": [
            "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-0-raw/multiqc_report.raw_fastqs.html",
            "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-0-raw/multiqc_report.raw_fastqs_1.html"
        ],
        "fastQC": [
            "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-0-raw/908C_S6_L001_R1_001_fastqc.html",
            "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-0-raw/908C_S6_L001_R2_001_fastqc.html",
            "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-0-raw/CMM3_S1_L001_R1_001_fastqc.html",
            "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-0-raw/CMM3_S1_L001_R2_001_fastqc.html"
        ]
    },
    "pcc-1-trimming": {
        "multiQC": [
            "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-1-trimming/multiqc_report.trimmed_fastqs.html"
        ],
        "fastQC": [
            "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-1-trimming/908C_S6_L001_R1_001.atria_fastqc.html",
            "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-1-trimming/908C_S6_L001_R2_001.atria_fastqc.html",
            "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-1-trimming/CMM3_S1_L001_R1_001.atria_fastqc.html",
            "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-1-trimming/CMM3_S1_L001_R2_001.atria_fastqc.html"
        ]
    },
    "pcc-2-mapping": {
        "samples": {
            "908C_S6_L001_R1_001.atria.fastq.gz.BWA.bam": [
                "acgt-cycles.png",
                "coverage.png",
                "gc-content.png",
                "gc-depth.png",
                "indel-cycles.png",
                "indel-dist.png",
                "insert-size.png",
                "mism-per-cycle.png",
                "quals-hm.png",
                "quals.png",
                "quals2.png",
                "quals3.png"
            ]
        },
        "filtered_fastqs": {
            "multiQC": [
                "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-2-mapping/multiqc_report.filtered_fastqs.html"
            ],
            "fastQC": [
                "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-2-mapping/908C_S6_L001_R1_001.atria.fastq.gz.BWA.bam.flag-f2_fastqc.html",
                "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-2-mapping/908C_S6_L001_R2_001.atria.fastq.gz.BWA.bam.flag-f2_fastqc.html"
            ]
        },
        "summary_tables": [
            "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-2-mapping/bam-stats/stat.samtools-stats.tsv"
        ]
    },
    "pcc-3-assembly": {
        "ani": {
            "sample_heatmaps": [
                "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-3-assembly/908C_S6_L001_R1_001.atria.fastq.gz.BWA.bam.flag-f2.velvet-contigs.ani-Dickey_0jy_depth1.plot.html",
                "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-3-assembly/908C_S6_L001_R1_001.atria.velvet-contigs.ani-Dickey_0jy_depth1.plot.html",
                "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-3-assembly/908C_S6_L001_R1_001.atria.velvet-contigs.ani-Dickeya_depth1.plot.html",
                "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-3-assembly/CMM3_S1_L001_R1_001.atria.velvet-contigs.ani-Dickey_0jy_depth1.plot.html"
            ],
            "summary_matrices": [
                "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-3-assembly/stat.ani-Dickey_0jy_depth1-2samples_1sp.plot.html.matrix.txt",
                "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-3-assembly/stat.ani-Dickey_0jy_depth1-2samples_1tS.plot.html.matrix.txt"
            ],
            "sample_top_lists": [
                "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-3-assembly/908C_S6_L001_R1_001.atria.fastq.gz.BWA.bam.flag-f2.velvet-contigs.ani-Dickey_0jy_depth1.plot.html.top-list.txt"
            ],
            "sample_matrices": [
                "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-3-assembly/908C_S6_L001_R1_001.atria.fastq.gz.BWA.bam.flag-f2.velvet-contigs.ani-Dickey_0jy_depth1.plot.html.matrix.txt",
                "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-3-assembly/908C_S6_L001_R1_001.atria.velvet-contigs.ani-Dickey_0jy_depth1.plot.html.matrix.txt",
                "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-3-assembly/908C_S6_L001_R1_001.atria.velvet-contigs.ani-Dickeya_depth1.plot.html.matrix.txt",
                "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-3-assembly/CMM3_S1_L001_R1_001.atria.velvet-contigs.ani-Dickey_0jy_depth1.plot.html.matrix.txt"
            ],
            "summary_heatmaps": [
                "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-3-assembly/stat.ani-Dickey_0jy_depth1-2samples_1sp.plot.html",
                "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-3-assembly/stat.ani-Dickey_0jy_depth1-2samples_1tS.plot.html"
            ]
        },
        "fastas": [
            "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-3-assembly/908C_S6_L001_R1_001.atria.fastq.gz.BWA.bam.flag-f2.velvet-contigs.fa",
            "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-3-assembly/908C_S6_L001_R1_001.atria.velvet-contigs.fa",
            "/home/jiacheng/PolyChromeWebData/projects/root/web_analysis/pcc-3-assembly/CMM3_S1_L001_R1_001.atria.velvet-contigs.fa"
        ]
    }
}
```
"""
function api_reports(request;
    search_limit::Regex=Config.FILE_SEARCH_LIMIT_GENERAL,
    log_request::Bool = true)
    
	log_request && @info(request, TimeRequest = now())
    
    data = get_request_data!(request) |> JSON.parse

    ### validate dirs and files
    project_dir = data["projectDir"] = get(data, "projectDir", "") |> replace_project_root_folder
    project_dir == "" && (return json_response(request, 400))
    occursin(search_limit, project_dir) || (return json_response(request, 458))
    is_pcc_project_dir(project_dir) || (return json_response(request, 458))

    # TODO: check: user permission of the folder

    report_files = unsafe_get_report_files(project_dir)

    return json_response(request, 200, data=report_files)
end
