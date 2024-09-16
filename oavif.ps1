# Declare parameters and set defaults
param (
    [string]$InputFile,
    [string]$OutputFile,
    [int]$Crf = 32,
    [int]$Speed = 4
)

# Function to display usage information
function Show-Usage {
    Write-Host "oavif.ps1 | Optimized AVIF encoding based on your input" -ForegroundColor Yellow
    Write-Host "Usage:" -ForegroundColor Gray
    Write-Host "`toavif.ps1 -i <inputFile> -o <outputFile> [-q <crf>] [-s <speed>]" -ForegroundColor Gray
    Write-Host "Options:" -ForegroundColor Gray
    Write-Host "`t-i <inputFile>`tInput video file" -ForegroundColor Yellow
    Write-Host "`t-o <outputFile>`tOutput video file" -ForegroundColor Yellow
    Write-Host "`t-q <crf>`tEncoding CRF (0-63; default: 32)" -ForegroundColor Yellow
    Write-Host "`t-s <speed>`tCompression effort (0-8; default: 4)" -ForegroundColor Yellow
    exit 1
}

# SVT-AV1 encode (for even width & height)
function Encode-SVT {
    param ($InputFile, $OutputFile, $Speed, $Crf)
    gum spin --spinner points --title "Encoding with SVT-AV1..." -- `
    avifenc -s "$Speed" -c svt -y 420 -d 10 -a "crf=$Crf" -a tune=4 "$InputFile" -o "$OutputFile"
}

# AOM encode (for odd width & height)
function Encode-AOM {
    param ($InputFile, $OutputFile, $Speed, $Crf)
    gum spin --spinner points --title "Encoding with aomenc..." -- `
    avifenc -j all -d 10 -y 444 -s "$Speed" `
    --min 0 --max 63 `
    --minalpha 0 --maxalpha 63 `
    -a end-usage=q `
    -a "cq-level=$Crf" `
    -a tune=ssim -a tune-content=default `
    -a deltaq-mode=3 -a enable-qm=1 `
    -a sb-size=dynamic -a aq-mode=0 `
    "$InputFile" -o "$OutputFile"
}

# Function to encode image
function Encode-Image {
    param ($InputFile, $OutputFile, $Speed, $Crf)
    
    $ImageInfo = (identify -format "%w %h %[channels]" $InputFile).Trim()
    $Width, $Height, $Channels = $ImageInfo -split ' '

    if ($Channels -match "a" -or $Channels -match "rgba") {
        # aomenc for images with alpha channel
        Write-Host "Alpha channel detected, encoding with aomenc..." -ForegroundColor Green
        Encode-AOM -InputFile $InputFile -OutputFile $OutputFile -Speed $Speed -Crf $Crf
    } elseif (($Width % 2) -eq 0 -and ($Height % 2) -eq 0) {
        # SVT-AV1 for even width & height
        Write-Host "Encoding with SVT-AV1..." -ForegroundColor Green
        Encode-SVT -InputFile $InputFile -OutputFile $OutputFile -Speed $Speed -Crf $Crf
    } else {
        # aomenc for odd width & height
        Write-Host "Odd width or height detected, encoding with aomenc..." -ForegroundColor Green
        Encode-AOM -InputFile $InputFile -OutputFile $OutputFile -Speed $Speed -Crf $Crf
    }
}

# Check for required arguments
if (-not $InputFile -or -not $OutputFile) {
    Show-Usage
}

# Validate input file
if (-not (Test-Path $InputFile)) {
    Write-Host "Error: Input file not found" -ForegroundColor Red
    exit 1
}

# Measure encoding time
$encodingTime = Measure-Command {
    Encode-Image -InputFile $InputFile -OutputFile $OutputFile -Speed $Speed -Crf $Crf
}

# Output size and time taken
if ($?) {
    $InputSize = (Get-Item $InputFile).length / 1MB
    $OutputSize = (Get-Item $OutputFile).length / 1MB
    Write-Host "$InputFile ($InputSize MB) -> $OutputFile ($OutputSize MB) | CRF $Crf Speed $Speed" -ForegroundColor Yellow
    Write-Host "Time taken: $($encodingTime.TotalSeconds) seconds" -ForegroundColor Yellow
} else {
    Write-Host "Error: Encoding failed" -ForegroundColor Red
    exit 1
}
