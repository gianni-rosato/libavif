#!/bin/bash

# Escape codes
AV1RED="\033[38;5;161m"
GREY="\033[38;5;248m"
BOLD="\033[1m"
YELW="\033[33m"
RESET="\033[0m"

# Function to display usage information
show_usage() {
    echo -e "${BOLD}oavif.sh${RESET} | Optimized AVIF encoding based on your input\n"
    echo -e "${GREY}Usage${RESET}:\n\t$0 -i <${YELW}input${RESET}> -o <${YELW}output${RESET}> [${GREY}-q <crf>${RESET}] [${GREY}-s <speed>${RESET}] [${GREY}-p <effort>${RESET}]\n"
    echo -e "${GREY}Options${RESET}:"
    echo -e "\t-i <input>\tInput video file"
    echo -e "\t-o <output>\tOutput video file"
    echo -e "\t-q <crf>\tEncoding CRF (0-63; default: 32)"
    echo -e "\t-s <speed>\tCompression effort (0-8; default: 4)"
    echo -e "\t-p <effort>\toxipng preprocessing effort (0-7; default: 0 [off])"
    exit 1
}

# SVT-AV1 encode (for even width & height)
encode_avifenc_svt() {
    local input=$1
    local output=$2
    local speed=$3
    local crf=$4
    gum spin --spinner points --title "Encoding with SVT-AV1..." -- \
    avifenc -s "$speed" -c svt -y 420 -d 10 -a "crf=$crf" -a tune=4 "$input" -o "$output"
}

# AOM encode (for odd width & height)
encode_avifenc_aom() {
    local input=$1
    local output=$2
    local speed=$3
    local crf=$4
    gum spin --spinner points --title "Encoding with aomenc..." -- \
    avifenc -j all -d 10 -y 444 -s "$speed" \
    --min 0 --max 63 \
    --minalpha 0 --maxalpha 63 \
    -a end-usage=q \
    -a "cq-level=$crf" \
    -a tune=ssim -a tune-content=default \
    -a deltaq-mode=3 -a enable-qm=1 \
    -a sb-size=dynamic -a aq-mode=0 \
    "$input" -o "$output"
}

# Preprocess the image with oxipng
preprocess_image() {
    local input=$1
    local effort=$2
    echo "Preprocessing image with oxipng..."
    gum spin --spinner points --title "Preprocessing image with oxipng..." -- \
    oxipng -qso "$effort" "$input" || echo -e "${GREY}Error: Preprocessing failed${RESET}"
}

# Function to encode video
encode_image() {
    local input=$1
    local output=$2
    local speed=$3
    local crf=$4

    image_info=$(identify -format "%w %h %[channels]" "$input")
    channels=$(echo "$image_info" | cut -d' ' -f3)

    if [[ $channels == *"a"* ]] || [[ $channels == *"rgba"* ]]; then
        # aomenc for images with alpha channel
        echo "Alpha channel detected, encoding with aomenc..."
        encode_avifenc_aom "$input" "$output" "$speed" "$crf"
    else
        # SVT-AV1 for everything else
        echo "Encoding with SVT-AV1..."
        encode_avifenc_svt "$input" "$output" "$speed" "$crf"
    fi
}

# Set defaults
crf=32
speed=4
preprocess=0

# Parse command line arguments
while getopts ":i:o:q:s:p:h" opt; do
    case ${opt} in
        i ) input=$OPTARG ;;
        o ) output=$OPTARG ;;
        q ) crf=$OPTARG ;;
        s ) speed=$OPTARG ;;
        p ) preprocess=$OPTARG ;;
        h ) show_usage ;;
        \? ) show_usage ;;
    esac
done

# Check for required arguments
if [ -z "$input" ] || [ -z "$output" ]; then
    show_usage
fi

# Validate input file
if [ ! -f "$input" ]; then
    echo -e "${GREY}Error: Input file not found${RESET}"
    exit 1
fi

# Preprocess image if specified
if [ $preprocess -ne 0 ]; then
    if ! command -v oxipng &> /dev/null; then
        echo -e "${GREY}Error: oxipng not found${RESET}"
        exit 1
    fi
    if [ $preprocess -gt 6 ]; then
        preprocess="max"
    fi
    preprocess_image "$input" "$preprocess"
fi

# Encode image
if encode_image "$input" "$output" "$speed" "$crf"; then
    input_size=$(du -h "$input" | awk '{print $1}')
    outpt_size=$(du -h "$output" | awk '{print $1}')
    echo -e "${YELW}$input${RESET} (${GREY}$input_size${RESET}) -> ${YELW}$output${RESET} (${GREY}$outpt_size${RESET}) | ${AV1RED}CRF ${crf} Speed ${speed}${RESET}"
else
    echo -e "${GREY}Error: Encoding failed${RESET}"
    exit 1
fi
