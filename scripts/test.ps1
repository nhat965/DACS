$ErrorActionPreference = "Stop"

$pythonCommand = $env:PYTHON_BIN
if (-not $pythonCommand) {
    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($python) {
        $pythonCommand = $python.Source
    }
}
if (-not $pythonCommand) {
    $candidate = Get-ChildItem -Path "$env:LOCALAPPDATA\Programs\Python" -Filter python.exe -Recurse -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending |
        Select-Object -First 1
    if ($candidate) {
        $pythonCommand = $candidate.FullName
    }
}
if (-not $pythonCommand) {
    $bundledPython = Join-Path $env:USERPROFILE ".cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
    if (Test-Path -LiteralPath $bundledPython) {
        $pythonCommand = $bundledPython
    }
}
if (-not $pythonCommand) {
    throw "Python was not found. Set PYTHON_BIN to a Python 3.12+ executable."
}

& $pythonCommand -m unittest discover -s data_pipeline/tests -v
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Push-Location services/recommendation-service
try {
    & $pythonCommand -m unittest discover -s tests -v
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
finally {
    Pop-Location
}

$flutterCommand = $env:FLUTTER_BIN
if (-not $flutterCommand) {
    $flutter = Get-Command flutter -ErrorAction SilentlyContinue
    if ($flutter) {
        $flutterCommand = $flutter.Source
    }
}
if (-not $flutterCommand -and (Test-Path -LiteralPath "C:\src\flutter\bin\flutter.bat")) {
    $flutterCommand = "C:\src\flutter\bin\flutter.bat"
}
if (-not $flutterCommand) {
    throw "Flutter was not found. Set FLUTTER_BIN to flutter or flutter.bat."
}

$webPath = (Resolve-Path (Join-Path $PSScriptRoot "..\apps\web")).Path
$flutterWorkPath = $webPath
$junctionPath = $null

# Dart Analysis Server on Windows can fail to encode non-ASCII workspace paths.
# A process-specific ASCII junction keeps the single root test command reliable.
if ($webPath -match "[^\x00-\x7F]") {
    $junctionPath = Join-Path $env:TEMP "lumi_beauty_web_test_$PID"
    New-Item -ItemType Junction -Path $junctionPath -Target $webPath | Out-Null
    $flutterWorkPath = $junctionPath
}

Push-Location $flutterWorkPath
try {
    & $flutterCommand analyze
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    & $flutterCommand test
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
finally {
    Pop-Location
    if ($junctionPath -and (Test-Path -LiteralPath $junctionPath)) {
        Remove-Item -LiteralPath $junctionPath
    }
}
