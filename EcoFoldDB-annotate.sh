#!/bin/bash
set -euo pipefail

version="EcoFoldDB-annotate v2.1.0"

usage() {
    echo "Usage: $0 --EcoFoldDB_dir PATH [--gpu (0|1)] [--ProstT5_dir PATH] [--foldseek_bin PATH] [-e EVALUE] [--qcov QCOV] [--tcov TCOV] [--tmp-dir PATH] [--remove-tmp-files (0|1)] [-o OUTDIR] INPUT_FILE_OR_DB"
    echo "$version"
    echo
    echo "Input types:"
    echo "  FASTA file:        File with .fasta, .fa, or .faa extension"
    echo "  Foldseek database: Path to and including database name"
    echo
    echo "Mandatory parameters:"
    echo "  --EcoFoldDB_dir    Full path to EcoFoldDB_v2.0 directory"
    echo "  INPUT_FILE_OR_DB   Input FASTA file of protein sequences OR Foldseek structural database"
    echo
    echo "Mandatory parameters required for FASTA input:"
    echo "  --ProstT5_dir      Full path to ProstT5 model directory (required for FASTA input)"
    echo "  --gpu              Use GPU (1) or CPU (0) (required for FASTA input)"
    echo
    echo "Optional parameters:"
    echo "  --foldseek_bin     Path to directory containing foldseek binary"
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
input_file_or_db=""
foldseek_bin=""
evalue="1e-10"
qcov="0.8"
tcov="0.8"
output_dir="EcoFoldDB_annotate"
remove_tmp_files=0
tmp_dir=""
input_type=""

# Parse command-line arguments
TEMP=$(getopt -o h,e:,o: --long EcoFoldDB_dir:,ProstT5_dir:,gpu:,foldseek_bin:,qcov:,tcov:,tmp-dir:,remove-tmp-files:,help,version -n "$0" -- "$@") || usage
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
    echo "Error: Missing input file or database" >&2
    usage
fi
input_file_or_db="$1"

# Determine input type
if [[ "$input_file_or_db" =~ \.(fasta|fa|faa)$ ]] && [ -f "$input_file_or_db" ]; then
    input_type="fasta"
    echo "Input type detected: FASTA file"
elif [ -f "${input_file_or_db}.dbtype" ]; then
    input_type="foldseek_db"
    echo "Input type detected: Foldseek database"
else
    echo "Error: Input must be either:" >&2
    echo "  - A FASTA file (.fasta, .fa, .faa) that exists" >&2
    echo "  - A Foldseek database path (without extension) where ${input_file_or_db}.dbtype exists" >&2
    exit 1
fi

# Validate mandatory parameters
if [ -z "$EcoFoldDB_dir" ]; then
    echo "Error: --EcoFoldDB_dir is required" >&2
    usage
fi

# Validate ProstT5_dir and gpu are provided for FASTA input
if [ "$input_type" = "fasta" ]; then
    if [ -z "$ProstT5_dir" ]; then
        echo "Error: --ProstT5_dir is required when input is a FASTA file" >&2
        usage
    fi
    if [ -z "$gpu" ]; then
        echo "Error: --gpu is required when input is a FASTA file" >&2
        usage
    fi
fi

# Validate parameter values (only validate gpu if it was provided)
if [ -n "$gpu" ] && [[ "$gpu" != 0 && "$gpu" != 1 ]]; then
    echo "Error: --gpu must be 0 or 1" >&2
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

# Validate ProstT5 directory for FASTA input
if [ "$input_type" = "fasta" ]; then
    if [ ! -d "$ProstT5_dir" ]; then
        echo "Error: ProstT5 directory '$ProstT5_dir' not found" >&2
        exit 1
    fi

    if ! ls "${ProstT5_dir}"/*.gguf &> /dev/null; then
        echo "Error: No .gguf model file found in ProstT5 directory '${ProstT5_dir}'" >&2
        exit 1
    fi
fi

# Validate coverage values are between 0 and 1
if command -v bc >/dev/null 2>&1; then
    if (( $(echo "$qcov < 0 || $qcov > 1" | bc -l) )); then
        echo "Error: --qcov must be between 0 and 1" >&2
        exit 1
    fi

    if (( $(echo "$tcov < 0 || $tcov > 1" | bc -l) )); then
        echo "Error: --tcov must be between 0 and 1" >&2
        exit 1
    fi
else
    # Fallback if bc is not available
    if (( $(echo "$qcov < 0 || $qcov > 1" | awk '{print ($1 < 0 || $1 > 1)}') )); then
        echo "Error: --qcov must be between 0 and 1" >&2
        exit 1
    fi

    if (( $(echo "$tcov < 0 || $tcov > 1" | awk '{print ($1 < 0 || $1 > 1)}') )); then
        echo "Error: --tcov must be between 0 and 1" >&2
        exit 1
    fi
fi

# Validate e-value is a valid number
if ! [[ "$evalue" =~ ^[0-9.eE-]+$ ]]; then
    echo "Error: Invalid e-value format '$evalue'" >&2
    exit 1
fi

# Main processing

# Extract the base name from the input
if [ "$input_type" = "fasta" ]; then
    name=$(basename "$input_file_or_db" | rev | cut -d"." -f2- | rev)
else
    name=$(basename "$input_file_or_db")
fi

echo "Starting processing for $name"

# Check if output directory already exists
if [ -d "${output_dir}" ]; then
    echo "Error: Output directory '${output_dir}' already exists. Please choose a different output directory." >&2
    exit 1
fi

# Create output directory structure
mkdir -p "${output_dir}" || { echo "Error: Failed to create output directory '${output_dir}'" >&2; exit 1; }

if [ "$input_type" = "fasta" ]; then
    mkdir -p "${output_dir}/Filtered_seqs" "${output_dir}/ProstT5_db" "${output_dir}/results_db" || { 
        echo "Error: Failed to create subdirectories in '${output_dir}'" >&2
        exit 1
    }
else
    mkdir -p "${output_dir}/results_db" || { 
        echo "Error: Failed to create results directory in '${output_dir}'" >&2
        exit 1
    }
fi

# Set default tmp_dir if not provided
if [ -z "$tmp_dir" ]; then
    tmp_dir="${output_dir}/results_db/${name}_tmp"
fi

# Process based on input type
if [ "$input_type" = "fasta" ]; then
    # FASTA input processing
    echo "Processing FASTA input..."
    
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
        }' "$input_file_or_db"; then
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
        export CUDA_VISIBLE_DEVICES=$(nvidia-smi --query-gpu=index --format=csv,noheader | paste -sd, - 2>/dev/null || echo "0")
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

    query_db="${output_dir}/ProstT5_db/${name}_db"

else
    # Foldseek database input processing
    echo "Processing Foldseek database input..."
    query_db="$input_file_or_db"
fi

# Search against EcoFoldDB
echo "Running Foldseek search..."
if ! foldseek search \
    "$query_db" \
    "$EcoFoldDB_dir/EcoFoldDB" \
    "${output_dir}/results_db/${name}_results" \
    "$tmp_dir" \
    -s 8 \
    --remove-tmp-files "$remove_tmp_files"; then
    echo "Error: Foldseek search failed" >&2
    exit 1
fi

# Convert results to text format
echo "Converting results..."
if ! foldseek convertalis \
    "$query_db" \
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

# Step 1: Select top hit per query (lowest e-value)
if ! awk -F'\t' '{
    # Store the line for each query, keeping only the one with the lowest e-value
    query = $1
    current_evalue = $3 + 0  # Convert to number for comparison
    
    # If we have not seen this query, or if this e-value is lower than the stored one
    if (!(query in best_evalue) || current_evalue < best_evalue[query]) {
        best_evalue[query] = current_evalue
        best_line[query] = $0
    }
}
END {
    # Print the best line for each query
    for (query in best_line) {
        print best_line[query]
    }
}' "${output_dir}/results_db/${name}_foldseek_results.txt" \
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
if command -v bc >/dev/null 2>&1; then
    # Use bc for floating point comparison if available
    if ! awk -F'\t' -v evalue="$evalue" -v qcov="$qcov" -v tcov="$tcov" '
        BEGIN {threshold_evalue = evalue + 0}
        $3 + 0 < threshold_evalue && $4 + 0 > qcov && $5 + 0 > tcov' \
        "${output_dir}/results_db/${name}_foldseek_results.top_EFDB_hits.txt" \
        > "${output_dir}/results_db/${name}_foldseek_results.top_EFDB_hits.Filtered.txt"; then
        echo "Error: Failed to filter top hits by thresholds" >&2
        exit 1
    fi
else
    # Fallback using string comparison (less precise but works for most cases)
    if ! awk -F'\t' -v evalue="$evalue" -v qcov="$qcov" -v tcov="$tcov" '
        function compare_evalue(e1, e2) {
            # Simple string comparison for scientific notation
            if (e1 ~ /^[0-9]/ && e2 ~ /^[0-9]/) {
                return (e1 + 0) < (e2 + 0)
            }
            # For scientific notation, this is simplified
            return e1 < e2
        }
        compare_evalue($3, evalue) && $4 + 0 > qcov && $5 + 0 > tcov' \
        "${output_dir}/results_db/${name}_foldseek_results.top_EFDB_hits.txt" \
        > "${output_dir}/results_db/${name}_foldseek_results.top_EFDB_hits.Filtered.txt"; then
        echo "Error: Failed to filter top hits by thresholds" >&2
        exit 1
    fi
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
