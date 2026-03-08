$ErrorActionPreference = "Stop"

function checkEnv {
    if ($null -ne $env:ARCH ) {
        $script:ARCH = $env:ARCH
    } else {
        $arch=([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture)
        if ($null -ne $arch) {
            $script:ARCH = ($arch.ToString().ToLower()).Replace("x64", "amd64")
        } else {
            write-host "WARNING: old powershell detected, assuming amd64 architecture - set `$env:ARCH to override"
            $script:ARCH="amd64"
        }
    }
    $script:TARGET_ARCH=$script:ARCH
    Write-host "Building for ${script:TARGET_ARCH}"
    write-host "Locating required tools and paths"
    $script:SRC_DIR=$PWD

    $script:DIST_DIR="${script:SRC_DIR}\dist\windows-${script:TARGET_ARCH}"
    $env:CGO_ENABLED="1"
    Write-Output "Checking version"
    if (!$env:VERSION) {
        $data=(git describe --tags --first-parent --abbrev=7 --long --dirty --always)
        $pattern="v(.+)"
        if ($data -match $pattern) {
            $script:VERSION=$matches[1]
        }
    } else {
        $script:VERSION=$env:VERSION
    }
    write-host "Building Ollama $script:VERSION"
    $script:JOBS=([Environment]::ProcessorCount)
}


function sycl {
    write-host "Building SYCL backend libraries"
    & cmake -B build\sycl --preset SYCL_INTEL --install-prefix $script:DIST_DIR
    if ($LASTEXITCODE -ne 0) { exit($LASTEXITCODE)}
    & cmake --build build\sycl --preset SYCL_INTEL --parallel $script:JOBS
    if ($LASTEXITCODE -ne 0) { exit($LASTEXITCODE)}
    & cmake --install build\sycl --component SYCL --strip
    if ($LASTEXITCODE -ne 0) { exit($LASTEXITCODE)}
}


function ollama {
    mkdir -Force -path "${script:DIST_DIR}\" | Out-Null
    write-host "Building ollama CLI"
    & go build -trimpath -ldflags "-s -w -X=github.com/ollama/ollama/version.Version=$script:VERSION -X=github.com/ollama/ollama/server.mode=release" .
    if ($LASTEXITCODE -ne 0) { exit($LASTEXITCODE)}
    cp .\ollama.exe "${script:DIST_DIR}\"
}

function clean {
    Remove-Item -ea 0 -r "${script:SRC_DIR}\dist\"
    Remove-Item -ea 0 -r "${script:SRC_DIR}\build\"
}

checkEnv
try {
    if ($($args.count) -eq 0) {
        sycl
        ollama
    } else {
        for ( $i = 0; $i -lt $args.count; $i++ ) {
            write-host "running build step $($args[$i])"
            & $($args[$i])
        } 
    }
} catch {
    write-host "Build Failed"
    write-host $_
} finally {
    set-location $script:SRC_DIR
}