param(
  [int]$Port = 8001
)

$projectRoot = Split-Path -Parent $PSScriptRoot
$serviceRoot = Join-Path $projectRoot 'services\recommendation-service'
$envPath = Join-Path $projectRoot '.env.local'

if (-not (Test-Path -LiteralPath $envPath)) {
  throw "Không tìm thấy .env.local tại $envPath"
}

foreach ($line in Get-Content -LiteralPath $envPath) {
  if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$') {
    $name = $Matches[1]
    $value = $Matches[2].Trim()
    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or
        ($value.StartsWith("'") -and $value.EndsWith("'"))) {
      $value = $value.Substring(1, $value.Length - 2)
    }
    Set-Item -Path "Env:$name" -Value $value
  }
}

$env:PYTHONPATH = $serviceRoot
Set-Location -LiteralPath $serviceRoot
Write-Host "Lumi Beauty backend: http://127.0.0.1:$Port"
python -m uvicorn recommendation_service.api:app --host 0.0.0.0 --port $Port
