# EcoFoldDB
Database and pipeline for protein structure-guided functional profiling of ecologically relevant microbial traits at the metagenome scale (millions of proteins).

EcoFoldDB is a database of protein structures encoded by microbial genes involved in:  
Trace gas oxidation, carbon cycling (i.e., C fixation and C metabolism and degradation), nitrogen cycling, sulphur cycling, phosphorus cycling, iron cycling, plant-microbe interactions, and osmotic stress tolerance.

`EcoFoldDB-annotate` is an annotation pipeline that leverages the scalability of the [ProstT5](https://doi.org/10.1093/nargab/lqae150) protein language model and [Foldseek](https://doi.org/10.1038/s41587-023-01773-0) to allow structure-based functional annotations against EcoFoldDB at the metagenome-scale without needing to perform protein structure predictions.

# Publication
[Ghaly, T.M., Rajabal, V., Russell, D., Colombi, E. and Tetu, S.G (2025) EcoFoldDB: Protein structure-guided functional profiling of ecologically relevant microbial traits at the metagenome scale. bioRxiv 2025.04.02.646905; doi: https://doi.org/10.1101/2025.04.02.646905](https://www.biorxiv.org/content/10.1101/2025.04.02.646905v1)


# Installation

### Clone EcoFoldDB repository
```
git clone https://github.com/timghaly/EcoFoldDB.git
cd EcoFoldDB
chmod +x EcoFoldDB-annotate.sh
```
### Install Foldseek
`EcoFoldDB-annotate` requires Foldseek for protein annotations. A GPU-compatible Foldseek is highly recommended for metagenome-scale annotations (i.e., for millions of proteins).  
Protein sequences are converted directly to a structural database using the ProstT5 protein language model.  
GPU can accelarate ProstT5 inference by one to two orders of magnitude. 

*Downloading Foldseek's precompiled binary - Linux AVX2 & GPU build*
```
wget https://mmseqs.com/foldseek/foldseek-linux-gpu.tar.gz
tar xvfz foldseek-linux-gpu.tar.gz
```
*Or, compile GPU Foldseek binary from source to be optimised to your specific system*:

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

*Other Foldseek installation options*:  

For CPU-only Foldseek, or conda installation instructions, see the [Foldseek installation page](https://github.com/steineggerlab/foldseek?tab=readme-ov-file#installation).


### Download ProstT5 protein language model

`EcoFoldDB-annotate` also requires the ProstT5 model to be locally installed.  
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
./EcoFoldDB-annotate.sh --EcoFoldDB_dir PATH --ProstT5_dir PATH --gpu (0|1) [--foldseek_bin PATH] [--prefilter-mode (0|1)] [-e EVALUE] [--qcov QCOV] [--tcov TCOV] [--tmp-dir PATH] [--remove-tmp-files (0|1)] [-o OUTDIR] INPUT_FILE

Mandatory parameters:
--EcoFoldDB_dir    Full path to EcoFoldDB_v2.0 directory
--ProstT5_dir      Full path to ProstT5 model directory
--gpu              Use GPU (1) or CPU (0)
INPUT_FILE         Input FASTA file of protein sequences to process

Optional parameters:
--foldseek_bin     Path to directory containing foldseek binary
--prefilter-mode   Prefilter mode. Set to 1 for GPU-accelerated search (default: 0)
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

# Citations
If you have used EcoFoldDB, please cite the following:  
[Ghaly, T.M., Rajabal, V., Russell, D., Colombi, E. and Tetu, S.G (2025) EcoFoldDB: Protein structure-guided functional profiling of ecologically relevant microbial traits at the metagenome scale. bioRxiv 2025.04.02.646905; doi: https://doi.org/10.1101/2025.04.02.646905](https://www.biorxiv.org/content/10.1101/2025.04.02.646905v1)



If you have used `EcoFoldDB-annotate`, in addition to the EcoFoldDB publication, please cite the following dependencies:

Foldseek:  
[van Kempen M, Kim S, Tumescheit C, Mirdita M, Lee J, Gilchrist CLM, Söding J, and Steinegger M. Fast and accurate protein structure search with Foldseek. *Nature Biotechnology*, doi:10.1038/s41587-023-01773-0 (2023)](https://doi.org/10.1038/s41587-023-01773-0)  
ProstT5:  
[Heinzinger, M., Weissenow, K., Sanchez, J.G., Henkel, A., Mirdita, M., Steinegger, M., and Rost, B. Bilingual language model for protein sequence and structure, *NAR Genomics and Bioinformatics*, doi:10.1093/nargab/lqae150 (2024)](https://doi.org/10.1093/nargab/lqae150)  
If you have used `--prefilter-mode 1`, please also cite MMSeqs2 GPU-accelerated search:  
[Kallenborn, F., Chacon, A., Hundt, C., Sirelkhatim, H., Didi, K., Cha, S., Dallago, C., Mirdita, M., Schmidt, B. and Steinegger, M. GPU-accelerated homology search with MMseqs2. *bioRxiv*, doi: 10.1101/2024.11.13.623350 (2024)](https://doi.org/10.1101/2024.11.13.623350)

