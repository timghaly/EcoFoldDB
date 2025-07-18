#!/bin/bash
set -euo pipefail

version="EcoFoldDB-annotate v2.0.0"

usage() {
    echo "Usage: $0 --EcoFoldDB_dir PATH --ProstT5_dir PATH --gpu (0|1) [--foldseek_bin PATH] [--prefilter-mode (0|1)] [-e EVALUE] [--qcov QCOV] [--tcov TCOV] [--tmp-dir PATH] [--remove-tmp-files (0|1)] [-o OUTDIR] INPUT_FILE"
    echo "$version"
    echo
    echo "Mandatory parameters:"
    echo "  --EcoFoldDB_dir    Full path to EcoFoldDB_v2.0 directory"
    echo "  --ProstT5_dir      Full path to ProstT5 model directory"
    echo "  --gpu              Use GPU (1) or CPU (0)"
    echo "  INPUT_FILE         Input FASTA file of protein sequences to process"
    echo
    echo "Optional parameters:"
    echo "  --foldseek_bin     Path to directory containing foldseek binary"
    echo "  --prefilter-mode   Prefilter mode. Set to 1 for GPU-accelerated search (default: 0)"
    echo "  -e                 E-value threshold (default: 1e-10)"
    echo "  --qcov             Minimum query coverage (default: 0.8)"
    echo "  --tcov             Minimum target coverage (default: 0.8)"
    echo "  --tmp-dir          Temporary directory for Foldseek (default: OUTDIR/results_db/NAME_tmp)"
    echo "  --remove-tmp-files Remove temporary files (0=no, 1=yes) (default: 0)"
    echo "  -o                 Output directory to be created (default: EcoFoldDB_annotate)"
    echo "  -h, --help         Show this help message"
    echo "  --version          Show version information"
    exit 1
}

# Initialise variables with defaults
EcoFoldDB_dir=""
ProstT5_dir=""
gpu=""
prefilter=0
input_file=""
foldseek_bin=""
evalue="1e-10"
qcov="0.8"
tcov="0.8"
output_dir="EcoFoldDB_annotate"
remove_tmp_files=0
tmp_dir=""

# Parse command-line arguments
TEMP=$(getopt -o h,e:,o: --long EcoFoldDB_dir:,ProstT5_dir:,gpu:,prefilter-mode:,foldseek_bin:,qcov:,tcov:,tmp-dir:,remove-tmp-files:,help,version -n "$0" -- "$@") || usage
eval set -- "$TEMP"

while true; do
    case "$1" in
        --EcoFoldDB_dir)
            EcoFoldDB_dir="$2"
            shift 2
            ;;
        --ProstT5_dir)
            ProstT5_dir="$2"
            shift 2
            ;;
        --gpu)
            gpu="$2"
            shift 2
            ;;
        --prefilter-mode)
            prefilter="$2"
            shift 2
            ;;
        --foldseek_bin)
            foldseek_bin="$2"
            shift 2
            ;;
        -e)
            evalue="$2"
            shift 2
            ;;
        --qcov)
            qcov="$2"
            shift 2
            ;;
        --tcov)
            tcov="$2"
            shift 2
            ;;
        --tmp-dir)
            tmp_dir="$2"
            shift 2
            ;;
        --remove-tmp-files)
            remove_tmp_files="$2"
            shift 2
            ;;
        -o)
            output_dir="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        --version)
            echo "$version"
            exit 0
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Invalid option: $1" >&2
            usage
            ;;
    esac
done

# Add foldseek_bin to PATH if specified
if [ -n "$foldseek_bin" ]; then
    export PATH="${foldseek_bin}:$PATH"
fi

# Check for foldseek in PATH
if ! command -v foldseek &> /dev/null; then
    echo "Error: foldseek not found in PATH. Use --foldseek_bin to specify its directory." >&2
    exit 1
fi

# Validate remaining arguments
if [ $# -ne 1 ]; then
    echo "Error: Missing input file" >&2
    usage
fi
input_file="$1"

# Validate input file
if [ ! -f "$input_file" ]; then
    echo "Error: Input file '$input_file' not found" >&2
    exit 1
fi

# Validate mandatory parameters
if [ -z "$EcoFoldDB_dir" ]; then
    echo "Error: --EcoFoldDB_dir is required" >&2
    usage
fi

if [ -z "$ProstT5_dir" ]; then
    echo "Error: --ProstT5_dir is required" >&2
    usage
fi

if [ -z "$gpu" ]; then
    echo "Error: --gpu is required" >&2
    usage
fi

# Validate parameter values
if [[ "$gpu" != 0 && "$gpu" != 1 ]]; then
    echo "Error: --gpu must be 0 or 1" >&2
    exit 1
fi

if [[ "$prefilter" != 0 && "$prefilter" != 1 ]]; then
    echo "Error: --prefilter-mode must be 0 or 1" >&2
    exit 1
fi

if [[ "$remove_tmp_files" != 0 && "$remove_tmp_files" != 1 ]]; then
    echo "Error: --remove-tmp-files must be 0 or 1" >&2
    exit 1
fi

# Validate directories and required files
if [ ! -d "$EcoFoldDB_dir" ]; then
    echo "Error: EcoFoldDB directory '$EcoFoldDB_dir' not found" >&2
    exit 1
fi

if [ ! -f "$EcoFoldDB_dir/EcoFoldDB" ]; then
    echo "Error: EcoFoldDB database not found in '$EcoFoldDB_dir'" >&2
    exit 1
fi

if [ ! -d "$ProstT5_dir" ]; then
    echo "Error: ProstT5 directory '$ProstT5_dir' not found" >&2
    exit 1
fi

if ! ls "${ProstT5_dir}"/*.gguf &> /dev/null; then
    echo "Error: No .gguf model file found in ProstT5 directory '${ProstT5_dir}'" >&2
    exit 1
fi

# Validate coverage values are between 0 and 1
if (( $(echo "$qcov < 0 || $qcov > 1" | bc -l) )); then
    echo "Error: --qcov must be between 0 and 1" >&2
    exit 1
fi

if (( $(echo "$tcov < 0 || $tcov > 1" | bc -l) )); then
    echo "Error: --tcov must be between 0 and 1" >&2
    exit 1
fi

# Validate e-value is a valid number
if ! [[ "$evalue" =~ ^[0-9.eE-]+$ ]]; then
    echo "Error: Invalid e-value format '$evalue'" >&2
    exit 1
fi

# Main processing

# Extract the file name (without extension) from the input file.
name=$(basename "$input_file" | rev | cut -d"." -f2- | rev)

echo "Starting processing for $name"

# Create output directory structure
mkdir "${output_dir}" || { echo "Error: Output directory '${output_dir}' already exists" >&2; exit 1; }
mkdir "${output_dir}/Filtered_seqs" "${output_dir}/ProstT5_db" "${output_dir}/results_db" || { 
    echo "Error: Failed to create subdirectories in '${output_dir}'" >&2
    exit 1
}

# Set default tmp_dir if not provided
if [ -z "$tmp_dir" ]; then
    tmp_dir="${output_dir}/results_db/${name}_tmp"
fi

# Filter input sequences
echo "Filtering long sequences..."
filtered_file="${output_dir}/Filtered_seqs/${name}.length_filtered.fasta"
excluded_file="${output_dir}/Filtered_seqs/${name}.excluded_long_seqs.fasta"

if ! awk -v filtered="$filtered_file" -v excluded="$excluded_file" '
    BEGIN { header=""; seq=""; total=0 }
    /^>/ {
        if (header != "") {
            if (total <= 4000) {
                print header > filtered
                printf "%s", seq > filtered
            } else {
                print header > excluded
                printf "%s", seq > excluded
            }
        }
        header = $0
        seq = ""
        total = 0
        next
    }
    {
        seq = seq $0 "\n"
        total += length($0)
    }
    END {
        if (total <= 4000) {
            print header > filtered
            printf "%s", seq > filtered
        } else {
            print header > excluded
            printf "%s", seq > excluded
        }
    }' "$input_file"; then
    echo "Error: Failed to filter sequences with awk" >&2
    exit 1
fi

# Check if filtered file contains data
if [ ! -s "$filtered_file" ]; then
    echo "Error: Filtered file is empty" >&2
    exit 1
fi

# Configure GPU visibility
if [ "$gpu" -eq 1 ]; then
    export CUDA_VISIBLE_DEVICES=$(nvidia-smi --query-gpu=index --format=csv,noheader | paste -sd, -)
    echo "Using GPU devices: $CUDA_VISIBLE_DEVICES"
fi

# Create ProstT5 database
echo "Creating ProstT5 database..."
if ! foldseek createdb \
    "${output_dir}/Filtered_seqs/${name}.length_filtered.fasta" \
    "${output_dir}/ProstT5_db/${name}_db" \
    --prostt5-model "$ProstT5_dir" \
    --gpu "$gpu"; then
    echo "Error: Failed to create ProstT5 database" >&2
    exit 1
fi

# Search against EcoFoldDB
echo "Running Foldseek search..."
if ! foldseek search \
    "${output_dir}/ProstT5_db/${name}_db" \
    "$EcoFoldDB_dir/EcoFoldDB" \
    "${output_dir}/results_db/${name}_results" \
    "$tmp_dir" \
    --gpu "$gpu" \
    --prefilter-mode "$prefilter" \
    -s 8 \
    --remove-tmp-files "$remove_tmp_files"; then
    echo "Error: Foldseek search failed" >&2
    exit 1
fi

# Convert results to text format
echo "Converting results..."
if ! foldseek convertalis \
    "${output_dir}/ProstT5_db/${name}_db" \
    "$EcoFoldDB_dir/EcoFoldDB" \
    "${output_dir}/results_db/${name}_results" \
    "${output_dir}/results_db/${name}_foldseek_results.txt" \
    --format-output query,target,evalue,qcov,tcov; then
    echo "Error: Failed to convert results to text format" >&2
    exit 1
fi

# Process results
echo "Processing results..."

# Create list of valid EFDB targets
valid_targets_file="${output_dir}/results_db/valid_targets.txt"
if ! tail -n +2 "$EcoFoldDB_dir/EcoFoldDB_descriptions.txt" | cut -f1 > "$valid_targets_file"; then
    echo "Error: Failed to create valid targets list" >&2
    exit 1
fi

# Step 1: Select top hit per query
if ! awk -F'\t' '!seen[$1]++' \
    "${output_dir}/results_db/${name}_foldseek_results.txt" \
    > "${output_dir}/results_db/${name}_foldseek_results.top_hits.txt"; then
    echo "Error: Failed to select top hits" >&2
    exit 1
fi

# Step 2: Filter top hits to only those with valid EFDB targets
if ! awk -F'\t' 'NR==FNR {valid[$1]; next} $2 in valid' \
    "$valid_targets_file" \
    "${output_dir}/results_db/${name}_foldseek_results.top_hits.txt" \
    > "${output_dir}/results_db/${name}_foldseek_results.top_EFDB_hits.txt"; then
    echo "Error: Failed to filter top hits by valid targets" >&2
    exit 1
fi

# Step 3: Filter top hits with e-value, qcov and tcov thresholds
if ! awk -F'\t' -v evalue="$evalue" -v qcov="$qcov" -v tcov="$tcov" \
    '$3 < evalue && $4 > qcov && $5 > tcov' \
    "${output_dir}/results_db/${name}_foldseek_results.top_EFDB_hits.txt" \
    > "${output_dir}/results_db/${name}_foldseek_results.top_EFDB_hits.Filtered.txt"; then
    echo "Error: Failed to filter top hits by thresholds" >&2
    exit 1
fi

# Attach annotations
echo "Assigning functional ontology..."
if ! printf "query\ttarget\tevalue\tqcov\ttcov\tGene\tProtein\tCategory\tSub-category\tPathway/Activity\tEC\tKO\n" \
    > "${output_dir}/${name}.ecofolddb_annotations.txt"; then
    echo "Error: Failed to create annotations header" >&2
    exit 1
fi

if ! awk -F'\t' 'NR==FNR {lookup[$1] = $2"\t"$3"\t"$4"\t"$5"\t"$6"\t"$7"\t"$8; next} 
    $2 in lookup {print $1"\t"$2"\t"$3"\t"$4"\t"$5"\t"lookup[$2]}' \
    "$EcoFoldDB_dir/EcoFoldDB_descriptions.txt" \
    "${output_dir}/results_db/${name}_foldseek_results.top_EFDB_hits.Filtered.txt" \
    >> "${output_dir}/${name}.ecofolddb_annotations.txt"; then
    echo "Error: Failed to attach annotations" >&2
    exit 1
fi

echo "Processing complete. Results saved in ${output_dir}/"

