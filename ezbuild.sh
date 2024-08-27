#!/bin/bash

# Exit on error
set -e

# ANSI Escape Codes
GREEN='\033[0;32m'
YELLW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Check if a given command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

installation_prompt() {
    str=$(gum confirm "Install avifenc to /usr/local/bin?" --selected.background="161" --selected.foreground="15" --unselected.foreground="248" && echo "Yes" || echo "No")
    echo "$str"
}

build_process() {
    # Remove build dirs if they already exist
    for dir in SVT-AV1 aom libjpeg-turbo libwebp libxml2 libyuv zlib libpng; do
        if [ -d "ext/$dir" ]; then
            echo -e "${YELLW}Cleanup existing $dir ...${RESET}"
            rm -rf ext/$dir
        fi
    done

    # Mark the scripts as executable
    chmod +x ext/svt.sh
    chmod +x ext/aom.cmd
    chmod +x ext/libyuv.cmd
    chmod +x ext/libsharpyuv.cmd
    chmod +x ext/libjpeg.cmd

    echo -e "${YELLW}Configuring libavif & dependencies...${RESET}"
    cd ext || exit 1
    # gum spin --spinner points --title "Configuring libxml2..." -- bash libxml2.cmd
    gum spin --spinner points --title "Configuring libyuv..." -- bash libyuv.cmd
    gum spin --spinner points --title "Configuring libsharpyuv..." -- bash libsharpyuv.cmd
    gum spin --spinner points --title "Configuring libjpeg..." -- bash libjpeg.cmd
    gum spin --spinner points --title "Configuring SVT-AV1-PSY..." -- bash svt.sh
    gum spin --spinner points --title "Configuring aom-psy101..." -- bash aom.cmd
    cd ..
    echo -e "${BLUE}Configuration process complete${RESET}"
    gum spin --spinner points --title "Configuring libavif..." -- cmake -S . -B build \
    -DAVIF_CODEC_AOM=LOCAL -DAVIF_CODEC_SVT=LOCAL \
    -DAVIF_LIBYUV=LOCAL -DAVIF_LIBSHARPYUV=LOCAL -DAVIF_JPEG=LOCAL \
    -DAVIF_BUILD_APPS=ON
    gum spin --spinner points --title "Compiling libavif..." -- cmake --build build --parallel
    echo -e "${GREEN}Compilation process complete${RESET}"

    # Cleanup build dirs
    for dir in SVT-AV1 aom libjpeg-turbo libwebp libxml2 libyuv zlib libpng; do
        if [ -d "ext/$dir" ]; then
            rm -rf ext/$dir
        fi
    done
}

main() {
    # Check for dependencies
    for cmd in git cmake clang gum; do
        echo -ne "$cmd\t"
        if ! command_exists $cmd; then
            echo -e "${RED}X\nError: $cmd is not installed. Please install it & try again.${RESET}"
            exit 1
        else
            echo -e "${GREEN}✔${RESET}"
        fi
    done

    # Begin build process
    build_process

    # Prompt user to install the binary
    case $(installation_prompt) in
        "Yes")
            sudo cp build/avifenc /usr/local/bin/
            echo -e "${GREEN}avifenc has been installed to /usr/local/bin/${RESET}"
            exit 0
            ;;
        "No")
            echo -e "${YELLW}Installation skipped. The binary is located at $(pwd)/build/avifenc${RESET}"
            echo -e "${YELLW}Please consider installing before general usage.${RESET}"
            exit 0
            ;;
    esac
}

main
