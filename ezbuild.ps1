# Exit on error
$ErrorActionPreference = "Stop"

# Check if a given command exists
function CommandExists {
    Get-Command $args[0] -ErrorAction SilentlyContinue
}

function BuildProcess {
    # Remove build dirs if they already exist
    $dirs = "SVT-AV1", "aom", "libjpeg-turbo", "libwebp", "libxml2", "libyuv", "zlib", "libpng"
    foreach ($dir in $dirs) {
        if (Test-Path "ext/$dir") {
            Write-Host "Cleanup existing $dir ..." -ForegroundColor Yellow
            Remove-Item -Recurse -Force "ext/$dir"
        }
    }

    Write-Host "Configuring libavif & dependencies..." -ForegroundColor Yellow
    Set-Location ext
    # gum spin --spinner points --title "Configuring libxml2..." -- bash libxml2.cmd
    gum spin --spinner points --title "Configuring libyuv..." -- cmd /c libyuv.cmd
    gum spin --spinner points --title "Configuring libsharpyuv..." -- cmd /c libsharpyuv.cmd
    gum spin --spinner points --title "Configuring libjpeg..." -- cmd /c libjpeg_win.cmd
    gum spin --spinner points --title "Configuring zlib and libpng..." -- cmd /c zlibpng.cmd
    gum spin --spinner points --title "Configuring SVT-AV1-PSY..." -- cmd /c svt.cmd
    gum spin --spinner points --title "Configuring aom-psy101..." -- cmd /c aom.cmd
    Set-Location ..

    Write-Host "Configuration process complete" -ForegroundColor Blue
    gum spin --spinner points --title "Configuring libavif..." -- cmake -S . -B build `
    -DBUILD_SHARED_LIBS=OFF -DAVIF_CODEC_AOM=LOCAL -DAVIF_LIBYUV=LOCAL `
    -DAVIF_LIBSHARPYUV=LOCAL -DAVIF_JPEG=LOCAL -DAVIF_ZLIBPNG=LOCAL `
    -DAVIF_BUILD_APPS=ON

    gum spin --spinner points --title "Compiling libavif..." -- cmake --build build --config Release --parallel
    Write-Host "Compilation process complete" -ForegroundColor Green

    # Cleanup build dirs
    foreach ($dir in $dirs) {
        if (Test-Path "ext/$dir") {
            Remove-Item -Recurse -Force "ext/$dir"
        }
    }
}

function Main {
    # Check for dependencies
    $cmds = "clang", "cmake", "git", "gum", "ninja", "perl"
    foreach ($cmd in $cmds) {
        Write-Host -NoNewline "$cmd`t"
        if (-not (CommandExists $cmd)) {
            Write-Host "X`nError: $cmd is not installed. Please install it & try again." -ForegroundColor Red
            exit 1
        } else {
            Write-Host "✔" -ForegroundColor Green
        }
    }

    # Begin build process
    BuildProcess
}

Main
