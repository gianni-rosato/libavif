# Declare parameters and set defaults
param (
    [string]$InputPath,  # Can be a file or a folder
    [string]$OutputPath, # Can be a file or a folder
    [int]$Crf = 32,
    [int]$Speed = 4
)

# Function to display usage information
function Show-Usage {
    Write-Host "oavif.ps1 | Optimized AVIF encoding based on your input" -ForegroundColor Yellow
    Write-Host "Usage:" -ForegroundColor Gray
    Write-Host "`toavif.ps1 -i <input> -o <output> [-q <crf>] [-s <speed>]" -ForegroundColor Gray
    Write-Host "Options:" -ForegroundColor Gray
    Write-Host "`t-i <input>`tInput file or folder" -ForegroundColor Yellow
    Write-Host "`t-o <output>`tOutput file or folder" -ForegroundColor Yellow
    Write-Host "`t-q <crf>`tEncoding CRF (0-63; default: 32)" -ForegroundColor Yellow
    Write-Host "`t-s <speed>`tCompression effort (0-8; default: 4)" -ForegroundColor Yellow
    exit 1
}

# SVT-AV1 encode (no alpha channel)
function Encode-SVT {
    param ($InputFile, $OutputFile, $Speed, $Crf)
    gum spin --spinner points --title "Encoding with SVT-AV1..." -- `
    avifenc -s "$Speed" -c svt -y 420 -d 10 -a "crf=$Crf" -a tune=4 "$InputFile" -o "$OutputFile"
}

# AOM encode (with alpha channel)
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

    $Channels = (identify -format "%[channels]" $InputFile).Trim()
    if ($Channels -match "a" -or $Channels -match "rgba") {
        # aomenc for images with alpha channel
        Write-Host "Alpha channel detected, encoding with aomenc..." -ForegroundColor Green
        Encode-AOM -InputFile $InputFile -OutputFile $OutputFile -Speed $Speed -Crf $Crf
    } else {
        # SVT-AV1 for everything else
        Write-Host "No alpha channel detected, encoding with SVT-AV1..." -ForegroundColor Green
        Encode-SVT -InputFile $InputFile -OutputFile $OutputFile -Speed $Speed -Crf $Crf
    }
}

# Function to process multiple images (for folders)
function Process-Images {
    param ($ImageFiles, $OutputFolder, $Speed, $Crf)

    foreach ($image in $ImageFiles) {
        $outputFile = Join-Path $OutputFolder ($image.BaseName + ".avif")
        
        # Measure encoding time
        $encodingTime = Measure-Command {
            Encode-Image -InputFile $image.FullName -OutputFile $outputFile -Speed $Speed -Crf $Crf
        }

        # Output size and time taken
        if ($?) {
            $InputSize = (Get-Item $image.FullName).length / 1MB
            $OutputSize = (Get-Item $outputFile).length / 1MB
            Write-Host "$($image.Name) ($InputSize MB) -> $($outputFile) ($OutputSize MB) | CRF $Crf Speed $Speed" `
                -ForegroundColor Yellow
            Write-Host "Time taken: $($encodingTime.TotalSeconds) seconds" -ForegroundColor Yellow
        } else {
            Write-Host "Error: Encoding failed for $($image.Name)" -ForegroundColor Red
        }
    }
}

# Check for required arguments
if (-not $InputPath -or -not $OutputPath) {
    Show-Usage
}

# Validate input path, doesn't work idk why
if (-not (Test-Path $InputPath)) {
    Write-Host "Error: Input not found" -ForegroundColor Red
    exit 1
}

# Check if input is a file or folder
if (Test-Path $InputPath -PathType Leaf) {
    # Single file encoding
    Process-Images -ImageFiles @(Get-Item $InputPath) -OutputFolder $(Split-Path $OutputPath) -Speed $Speed -Crf $Crf
} elseif (Test-Path $InputPath -PathType Container) {
    # Folder processing (PNG files only)
    $imageFiles = Get-ChildItem -Path $InputPath -Filter *.png
    Process-Images -ImageFiles $imageFiles -OutputFolder $OutputPath -Speed $Speed -Crf $Crf
} else {
    # Yea this doesn't work too
    Write-Host "Error: Invalid input path" -ForegroundColor Red
    exit 1
}
