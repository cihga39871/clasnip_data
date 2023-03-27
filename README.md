# The code and data repository for Clasnip manuscript

If you use Clasnip web service, please cite:

> Chuan J, Xu H, Hammill DL, Hale L, Chen W, Li X. 2023. Clasnip: a web-based intraspecies classifier and multi-locus sequence typing for pathogenic microorganisms using fragmented sequences. PeerJ 11:e14490 https://doi.org/10.7717/peerj.14490

This repository contains the source code, data and results of Clasnip Classification Program.

You can copy the whole repository by clicking the green "Code" button, and clicking "Download ZIP".

## Contents

### 'code' folder

It contains the source code of Clasnip back-end (`code/server`) and front-end (`code/user-interface`)

To set up Clasnip, please refer to [the README file under code](code/README.md).

### 'data' folder

This folder contains analysis results mentioned in the Clasnip manuscript. All sequence files in the folder are fetched from the public NCBI database.

- [database_input_CLso.tar.xz](https://github.com/cihga39871/clasnip_data/blob/master/data/database_input_CLso.tar.xz) is the compressed sequence file for building CLso database. 
  - Building genomic database: please set reference to **GCA_000183665.1_ASM18366v1_genomic.fasta**.
  - Building 16S rRNA database: please set reference to **MH259699.1.16S.CLso-HF.fasta**.
  - Building 16-23S rRNA database: please set reference to **JX624236.1.23S.CLso-HA.fasta**.
  - Building 50S rRNA database: please set reference to **MH259700.1.50S.CLso-HF.fasta**.
- [database_input_Potato_virus_Y.tar.xz](https://github.com/cihga39871/clasnip_data/blob/master/data/database_input_Potato_virus_Y.tar.xz) is the compressed sequence file for building Potato virus Y database. The reference file is **HQ912865.fasta**.
- [database](https://github.com/cihga39871/clasnip_data/tree/master/data/database) contains Clasnip database folders. All files are xz-compressed. To make your local Clasnip recognizes the databases, you need to
  - Decompress all `xz` files;
  - Move the database folders under `DB_DIR` defined in the `code/server/config/Config.jl`;
  - Update the absolute paths of keys `dbVcfReduced` and `dbVcfReduced` in `db_info.json`;
  - Start or restart the Clasnip server.
- [BLCA_CLso_16S_performance_comparison](https://github.com/cihga39871/clasnip_data/tree/master/data/BLCA_CLso_16S_performance_comparison) contains [BLCA_16S_analysis_script.jl](https://github.com/cihga39871/clasnip_data/blob/master/data/BLCA_CLso_16S_performance_comparison/BLCA_16S_analysis_script.jl), and performance benchmark tables.
