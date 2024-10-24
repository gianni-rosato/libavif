# Parameter declaration
param(
    [Parameter(Mandatory=$false)]
    [string]$InputFile,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFile,
    
    [Parameter(Mandatory=$false)]
    [int]$CRF = 32,
    
    [Parameter(Mandatory=$false)]
    [int]$Speed = 4,
    
    [Parameter(Mandatory=$false)]
    [int]$Preprocess = 0
)

# ANSI escape codes for colors
$script:AV1RED = "`e[38;5;161m"
$script:GREY = "`e[38;5;248m"
$script:BOLD = "`e[1m"
$script:YELW = "`e[33m"
$script:RESET = "`e[0m"

# Function to display usage information
function Show-Usage {
    Write-Host "${BOLD}oavif.ps1${RESET} | Optimized AVIF encoding based on your input`n"
    Write-Host "${GREY}Usage${RESET}:`n`toavif.ps1 -InputFile <${YELW}input${RESET}> -OutputFile <${YELW}output${RESET}> [${GREY}-CRF <crf>${RESET}] [${GREY}-Speed <speed>${RESET}] [${GREY}-Preprocess <effort>${RESET}]`n"
    Write-Host "${GREY}Options${RESET}:"
    Write-Host "`t-InputFile <input>`tInput video file"
    Write-Host "`t-OutputFile <output>`tOutput video file"
    Write-Host "`t-CRF <crf>`tEncoding CRF (0-63; default: 32)"
    Write-Host "`t-Speed <speed>`tCompression effort (0-8; default: 4)"
    Write-Host "`t-Preprocess <effort>`toxipng preprocessing effort (0-7; default: 0 [off])"
    exit 1
}

# SVT-AV1 encode (for even width & height)
function Invoke-AvifencSvt {
    param(
        [string]$InputFile,
        [string]$OutputFile,
        [int]$Speed,
        [int]$CRF
    )
    
    Write-Host "Encoding with SVT-AV1..."
    avifenc -s $Speed -c svt -y 420 -d 10 -a "crf=$CRF" -a tune=4 $InputFile -o $OutputFile
    return $LASTEXITCODE -eq 0
}

# AOM encode (for odd width & height and alpha channel)
function Invoke-AvifencAom {
    param(
        [string]$InputFile,
        [string]$OutputFile,
        [int]$Speed,
        [int]$CRF
    )

    Write-Host "Encoding with aomenc..."
    avifenc -j all -d 10 -y 444 -s $Speed `
        --min 0 --max 63 `
        --minalpha 0 --maxalpha 63 `
        -a end-usage=q `
        -a "cq-level=$CRF" `
        -a tune=ssim -a tune-content=default `
        -a deltaq-mode=3 -a enable-qm=1 `
        -a sb-size=dynamic -a aq-mode=0 `
        $InputFile -o $OutputFile
    return $LASTEXITCODE -eq 0
}

# Preprocess the image with oxipng
function Invoke-ImagePreprocess {
    param(
        [string]$InputFile,
        [string]$Effort
    )
    
    Write-Host "Preprocessing image with oxipng..."
    try {
        oxipng -qso $Effort $InputFile
    }
    catch {
        Write-Host "${GREY}Error: Preprocessing failed${RESET}"
        return $false
    }
    return $true
}

# Function to encode image
function Invoke-ImageEncode {
    param(
        [string]$InputFile,
        [string]$OutputFile,
        [int]$Speed,
        [int]$CRF
    )

    # Use magick identify to check for alpha channel
    $imageInfo = magick identify -format "%[channels]" $InputFile
    
    if ($imageInfo -match "a" -or $imageInfo -match "rgba") {
        # aomenc for images with alpha channel
        Write-Host "Alpha channel detected, encoding with aomenc..."
        return Invoke-AvifencAom -InputFile $InputFile -OutputFile $OutputFile -Speed $Speed -CRF $CRF
    }
    else {
        # SVT-AV1 for everything else
        return Invoke-AvifencSvt -InputFile $InputFile -OutputFile $OutputFile -Speed $Speed -CRF $CRF
    }
}

# Show usage if required parameters are missing
if (-not $InputFile -or -not $OutputFile) {
    Show-Usage
}

# Validate input file
if (-not (Test-Path $InputFile)) {
    Write-Host "${GREY}Error: Input file not found${RESET}"
    exit 1
}

# Preprocess image if specified
if ($Preprocess -ne 0) {
    if (-not (Get-Command "oxipng" -ErrorAction SilentlyContinue)) {
        Write-Host "${GREY}Error: oxipng not found${RESET}"
        exit 1
    }
    
    if ($Preprocess -gt 6) {
        $Preprocess = "max"
    }
    
    Invoke-ImagePreprocess -InputFile $InputFile -Effort $Preprocess
}

# Encode image
if (Invoke-ImageEncode -InputFile $InputFile -OutputFile $OutputFile -Speed $Speed -CRF $CRF) {
    $inputSize = (Get-Item $InputFile).Length / 1KB
    $outputSize = (Get-Item $OutputFile).Length / 1KB
    
    $inputSizeFormatted = "{0:N2} KB" -f $inputSize
    $outputSizeFormatted = "{0:N2} KB" -f $outputSize
    
    Write-Host "${YELW}$InputFile${RESET} (${GREY}$inputSizeFormatted${RESET}) -> ${YELW}$OutputFile${RESET} (${GREY}$outputSizeFormatted${RESET}) | ${AV1RED}CRF ${CRF} Speed ${Speed}${RESET}"
}
else {
    Write-Host "${GREY}Error: Encoding failed${RESET}"
    exit 1
}