# EcoFoldDB
Database and pipeline for protein structure-guided functional profiling of ecologically relevant microbial traits at the metagenome scale (millions of proteins).

EcoFoldDB is a database of protein structures encoded by microbial genes involved in:  
Trace gas oxidation, carbon cycling (i.e., C fixation, metabolism and degradation), nitrogen cycling, sulphur cycling, phosphorus cycling, iron cycling, plant-microbe interactions, and osmotic stress tolerance.

`EcoFoldDB-annotate` is an annotation pipeline using [Foldseek](https://doi.org/10.1038/s41587-023-01773-0) to allow structure-based functional annotations against EcoFoldDB at the metagenome-scale. It can accept as input, either protein sequences, in which case it leverages the [ProstT5](https://doi.org/10.1093/nargab/lqae150) protein language model to prevent the need to perform protein structure predictions, or can accept a database of protein structures as input.

# Publication
[Ghaly, T.M., Rajabal, V., Russell, D., Colombi, E. and Tetu, S.G (2025) EcoFoldDB: Protein structure-guided functional profiling of ecologically relevant microbial traits at the metagenome scale. *Environmental Microbiology*, 27: e70178; doi: https://doi.org/10.1111/1462-2920.70178](https://doi.org/10.1111/1462-2920.70178)


# Installation

### Clone EcoFoldDB repository
```
git clone https://github.com/timghaly/EcoFoldDB.git
cd EcoFoldDB
chmod +x EcoFoldDB-annotate.sh
```
### Install Foldseek
`EcoFoldDB-annotate` requires Foldseek for protein annotations. If using ProstT5 inference (protein sequences as input), then a GPU-compatible Foldseek is highly recommended for metagenome-scale annotations (i.e., for millions of proteins).  
Protein sequences are converted directly to a structural database using the ProstT5 protein language model.  
GPU can accelarate ProstT5 inference by one to two orders of magnitude.  
If using protein structures as input (must be a Foldseek database), then either a CPU-only or GPU-Foldseek will work equally.

There are different options to install Foldseek:  

*Option 1 (GPU Foldseek): Download Foldseek's precompiled binary - Linux AVX2 & GPU build*
```
wget https://mmseqs.com/foldseek/foldseek-linux-gpu.tar.gz
tar xvfz foldseek-linux-gpu.tar.gz
```
*Option 2 (GPU Foldseek): Instead, compile GPU Foldseek binary from source to be optimised to your specific system*:

```
conda create -n nvcc -c conda-forge cuda-nvcc cuda-cudart-dev libcublas-dev libcublas-static cuda-version=12.6 cmake
conda activate nvcc
git clone https://github.com/steineggerlab/foldseek.git
cd foldseek
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=RELEASE -DCMAKE_INSTALL_PREFIX=. -DENABLE_CUDA=1 -DCMAKE_CUDA_ARCHITECTURES="native" ..
make -j8
make install
```

*Option 3 (CPU-only Foldseek): Other Foldseek installation options*:  

For precompiled CPU-only Foldseek binary, or conda installation instructions, see the [Foldseek installation page](https://github.com/steineggerlab/foldseek?tab=readme-ov-file#installation).


### Download ProstT5 protein language model (If input are protein sequences)

If using protein sequences as input, `EcoFoldDB-annotate` requires the ProstT5 model to be locally installed.  
The model can be downloaded using Foldseek:

```
foldseek databases ProstT5 ProstT5_dir tmp --remove-tmp-files 1
```

# Usage
If Foldseek is not in your `$PATH`, then you can add its binary directory to the `PATH` environment variable before running `EcoFoldDB-annotate.sh`:
```
export PATH=/full/path/to/foldseek/bin/:$PATH
```
Or instead, the foldseek binary directory can be provided to `EcoFoldDB-annotate.sh` using the flag:  
``` --foldseek_bin ```


```
./EcoFoldDB-annotate.sh --EcoFoldDB_dir PATH [--gpu (0|1)] [--ProstT5_dir PATH] [--foldseek_bin PATH] [-e EVALUE] [--qcov QCOV] [--tcov TCOV] [--tmp-dir PATH] [--remove-tmp-files (0|1)] [-o OUTDIR] INPUT_FILE_OR_DB
EcoFoldDB-annotate v2.1.0

Input types:
  FASTA file:        File with .fasta, .fa, or .faa extension
  Foldseek database: Path to and including database name

Mandatory parameters:
  --EcoFoldDB_dir    Full path to EcoFoldDB_v2.0 directory
  INPUT_FILE_OR_DB   Input FASTA file of protein sequences OR Foldseek structural database

Mandatory parameters required for FASTA input:
  --ProstT5_dir      Full path to ProstT5 model directory (required for FASTA input)
  --gpu              Use GPU (1) or CPU (0) (required for FASTA input)

Optional parameters:
  --foldseek_bin     Path to directory containing foldseek binary
  -e                 E-value threshold (default: 1e-10)
  --qcov             Minimum query coverage (default: 0.8)
  --tcov             Minimum target coverage (default: 0.8)
  --tmp-dir          Temporary directory for Foldseek (default: OUTDIR/results_db/NAME_tmp)
  --remove-tmp-files Remove temporary files (0=no, 1=yes) (default: 0)
  -o                 Output directory to be created (default: EcoFoldDB_annotate)
  -h, --help         Show this help message
  --version          Show version information


```
# Output
The main annotation results will be in the output directory with the file extension `.ecofolddb_annotations.txt`

### Output directory structure
```
OUTDIR/
├── ${name}.ecofolddb_annotations.txt                       # Main annotation result
├── Filtered_seqs/
│   ├── ${name}.length_filtered.fasta                       # Input protein sequences included after filtering
│   └── ${name}.excluded_long_seqs.fasta                    # Input protein sequences excluded after filtering
├── ProstT5_db/
│   └── ${name}_db*                                         # ProstT5 Foldseek database files (binary database files)
└── results_db/                                             
    ├── ${name}_results.*                                   # Foldseek result DB files produced by foldseek `search` command
    ├── ${name}_foldseek_results.txt                        # All Foldseek hits to target EFDB and non-target Swiss-Prot structures
    ├── ${name}_foldseek_results.top_hits.txt               # Top hit for each query protein
    ├── ${name}_foldseek_results.top_EFDB_hits.txt          # Queries whose top hit is with a target EFDB structure
    ├── ${name}_foldseek_results.top_EFDB_hits.Filtered.txt # Top EFDB hits filtered by alignment coverage e-value thresholds
    └── valid_targets.txt                                   # Target EFDB structures from EcoFoldDB
```

# Citations
If you have used EcoFoldDB, please cite the following:  
[Ghaly, T.M., Rajabal, V., Russell, D., Colombi, E. and Tetu, S.G (2025) EcoFoldDB: Protein structure-guided functional profiling of ecologically relevant microbial traits at the metagenome scale. *Environmental Microbiology*, 27: e70178; doi: https://doi.org/10.1111/1462-2920.70178](https://doi.org/10.1111/1462-2920.70178)



Please also cite the following dependencies:

Foldseek:  
[van Kempen M, Kim S, Tumescheit C, Mirdita M, Lee J, Gilchrist CLM, Söding J, and Steinegger M. (2023) Fast and accurate protein structure search with Foldseek. *Nature Biotechnology*, doi:10.1038/s41587-023-01773-0](https://doi.org/10.1038/s41587-023-01773-0)  
If you have used ProstT5:  
[Heinzinger, M., Weissenow, K., Sanchez, J.G., Henkel, A., Mirdita, M., Steinegger, M., and Rost, B. (2024) Bilingual language model for protein sequence and structure, *NAR Genomics and Bioinformatics*, doi:10.1093/nargab/lqae150](https://doi.org/10.1093/nargab/lqae150)  

