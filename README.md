# EcoFoldDB
Database and pipeline for protein structure-guided annotations of ecologically relevant functions at the metagenome scale.

EcoFoldDB is a database of protein structures that cover microbial functions of ecological relevance including genes involved in:  
Trace gas oxidation, carbon cycling (i.e., C fixation, C1 metabolism, degradation of complex carbohydrates, polyphenols, aromatic hydrocarbons and fatty acids), nitrogen cycling, sulphur cycling, phosphorus cycling, iron cycling, plant-microbe interactions, and osmotic stress tolerance.

The pipeline ```EcoFoldDB_annotate.sh``` leverages the scalabality of the [ProstT5](https://doi.org/10.1038/s41587-023-01773-0) protein language model and [Foldseek](https://doi.org/10.1038/s41587-023-01773-0) to allow structure-based functional annotations against EcoFoldDB at the metagenome-scale (millions of proteins) without needing to perform protein structure predictions.

# Publication
Manuscript in preparation
# Installation

### Clone EcoFoldDB repository
```
git clone https://github.com/timghaly/EcoFoldDB.git
cd EcoFoldDB
chmod +x EcoFoldDB_annotate.sh
```
### Install Foldseek
Foldseek is used by the ```EcoFoldDB_annotate.sh``` annotation pipelinethe. A GPU-compatible Foldseek is highly recommened for metagenome-scale annotations (i.e., for millions of proteins).  
Protein sequences are converted directly to a structural database using the ProstT5 protein language model (400-4000x faster than predicting structures with ColabFold).  
GPU can accelarate ProstT5 inference by one to two orders of magnitude. 

```
# Linux AVX2 & GPU build (req. glibc >= 2.17 and nvidia driver >=525.60.13)
wget https://mmseqs.com/foldseek/foldseek-linux-gpu.tar.gz
tar xvfz foldseek-linux-gpu.tar.gz
```
Or, compile Foldseek binary from source:

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
The path to the Foldseek binary directory can be set as an evironmental variable before running ```EcoFoldDB_annotate.sh```:
```
export PATH=/full/path/to/foldseek/bin/:$PATH
```
OR

The path to the foldseek binary directory can be provided to ```EcoFoldDB_annotate.sh``` using the flag:  
``` --foldseek_bin ```


### Download ProstT5 protein language model using Foldseek
The ProstT5 model is needed to run the ```EcoFoldDB_annotate.sh``` pipeline. The model can be downloaded using Foldseek:

```
foldseek databases ProstT5 ProstT5_dir tmp --remove-tmp-files 1
```

# Usage
```
./EcoFoldDB_annotate.sh --EcoFoldDB_dir PATH --ProstT5_dir PATH --gpu (0|1) [--foldseek_bin PATH] [--prefilter-mode (0|1)] [-e EVALUE] [--qcov QCOV] [--tcov TCOV] [-o OUTDIR] INPUT_FILE

Mandatory parameters:
--EcoFoldDB_dir    Full path to EcoFoldDB_v1.1 directory
--ProstT5_dir      Full path to ProstT5 model directory
--gpu              Use GPU (1) or CPU (0)
INPUT_FILE         Input FASTA file to process

Optional parameters:
--foldseek_bin     Path to directory containing foldseek binary
--prefilter-mode   Foldseek prefilter mode. Set to 1 for GPU-accelerated search (default: 0)
-e                 E-value threshold (default: 1e-15)
--qcov             Minimum query coverage (default: 0.8)
--tcov             Minimum target coverage (default: 0.8)
-o                 Output directory to be created (default: EcoFoldDB_annotate)
-h, --help         Show this help message


```
# Output
The main annotation results will be in the output directory with the file extension ```.ecofolddb_annotations.txt```

# Citations
If you have used EcoFoldDB, please cite the following:  
*Manuscript in preparation*


If you have used ```EcoFoldDB_annotate.sh```, please cite the following dependencies:

Foldseek:  
[van Kempen M, Kim S, Tumescheit C, Mirdita M, Lee J, Gilchrist CLM, Söding J, and Steinegger M. Fast and accurate protein structure search with Foldseek. *Nature Biotechnology*, doi:10.1038/s41587-023-01773-0 (2023)](https://doi.org/10.1038/s41587-023-01773-0)  
ProstT5:  
[Heinzinger, M., Weissenow, K., Sanchez, J.G., Henkel, A., Mirdita, M., Steinegger, M., and Rost, B. Bilingual language model for protein sequence and structure, *NAR Genomics and Bioinformatics*, doi:10.1093/nargab/lqae150 (2024)](https://doi.org/10.1093/nargab/lqae150)


