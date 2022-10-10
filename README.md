# The code and data repository for Clasnip manuscript

This repository contains the source code, data and results of Clasnip Classification Program.

You can copy the whole repository by clicking the green "Code" button, and clicking "Download ZIP".

## Contents

### 'code' folder

It contains the source code of Clasnip back-end (`code/server`) and front-end (`code/user-interface`)

To set up Clasnip, please refer to [the README file under code](code/README.md).

### 'data' folder

This folder contains analysis results mentioned in the Clasnip manuscript.

- [database_input_CLso.tar.xz](https://github.com/cihga39871/clasnip_data/blob/master/data/database_input_CLso.tar.xz) is the compressed sequence file for building CLso database. 
  - Building genomic database: please set reference to **GCA_000183665.1_ASM18366v1_genomic.fasta**.
  - Building 16S rRNA database: please set reference to **MH259699.1.16S.CLso-HF.fasta**.
  - Building 16-23S rRNA database: please set reference to **JX624236.1.23S.CLso-HA.fasta**.
  - Building 50S rRNA database: please set reference to **MH259700.1.50S.CLso-HF.fasta**.
- [database_input_Potato_virus_Y.tar.xz](https://github.com/cihga39871/clasnip_data/blob/master/data/database_input_Potato_virus_Y.tar.xz) is the compressed sequence file for building Potato virus Y database. The reference file is **HQ912865.fasta**.
- [database](https://github.com/cihga39871/clasnip_data/tree/master/data/database) contains Clasnip database folders. All files are xz-compressed. After decompressing, the Clasnip database folders can be placed under `DB_DIR` defined in the `code/server/config/Config.jl`, so that Clasnip can recognize the databases (after restarting Clasnip).
- [real_CLso_sequences_in_tomato](https://github.com/cihga39871/clasnip_data/tree/master/data/real_CLso_sequences_in_tomato) contains FASTA sequences mentioned in the `Results / Real sample classification` section.
- [BLCA_CLso_16S_performance_comparison](https://github.com/cihga39871/clasnip_data/tree/master/data/BLCA_CLso_16S_performance_comparison) contains [BLCA_16S_analysis_script.jl](https://github.com/cihga39871/clasnip_data/blob/master/data/BLCA_CLso_16S_performance_comparison/BLCA_16S_analysis_script.jl), and performance benchmark tables.