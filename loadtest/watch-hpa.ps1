<#
.SYNOPSIS
  Registra el comportamiento del autoscaling durante una prueba de carga.

.DESCRIPTION
  Cada N segundos consulta los HPA del namespace usn y guarda en un CSV:
  réplicas actuales/deseadas, % de CPU respecto a lo solicitado (requests),
  pods en ejecución y nodos del cluster. El CSV se puede graficar en Excel
  para el informe (réplicas y CPU en el tiempo). Detener con Ctrl+C.

.EXAMPLE
  .\loadtest\watch-hpa.ps1
  .\loadtest\watch-hpa.ps1 -Interval 5
#>
param(
    [int]$Interval = 10,
    [string]$Namespace = "usn",
    [string]$OutFile = ""
)

$ErrorActionPreference = "Stop"
$resultsDir = Join-Path $PSScriptRoot "results"
New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null
if (-not $OutFile) {
    $OutFile = Join-Path $resultsDir ("hpa-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".csv")
}

$hpas = @("backend", "frontend", "ai-service")
$header = @("timestamp")
foreach ($h in $hpas) { $header += "${h}_replicas", "${h}_desired", "${h}_cpu_pct" }
$header += "pods_running", "nodes_ready"
($header -join ",") | Set-Content -Path $OutFile -Encoding utf8

Write-Host "Registrando en $OutFile (cada $Interval s). Ctrl+C para terminar." -ForegroundColor Cyan

while ($true) {
    $now = Get-Date -Format "HH:mm:ss"
    $row = @($now)
    $line = "$now "

    foreach ($h in $hpas) {
        $raw = kubectl -n $Namespace get hpa $h -o "jsonpath={.status.currentReplicas},{.status.desiredReplicas},{.status.currentMetrics[0].resource.current.averageUtilization}" 2>$null
        $parts = "$raw".Split(",")
        $cur = if ($parts.Count -gt 0 -and $parts[0]) { $parts[0] } else { "" }
        $des = if ($parts.Count -gt 1 -and $parts[1]) { $parts[1] } else { "" }
        $cpu = if ($parts.Count -gt 2 -and $parts[2]) { $parts[2] } else { "" }
        $row += $cur, $des, $cpu
        $line += "| {0,-10} {1}/{2} pods CPU {3,3}% " -f $h, $cur, $des, $cpu
    }

    $pods = (kubectl -n $Namespace get pods --field-selector=status.phase=Running --no-headers 2>$null | Measure-Object -Line).Lines
    $nodes = (kubectl get nodes --no-headers 2>$null | Select-String " Ready " | Measure-Object).Count
    $row += $pods, $nodes
    $line += "| pods $pods | nodos $nodes"

    ($row -join ",") | Add-Content -Path $OutFile -Encoding utf8
    Write-Host $line
    Start-Sleep -Seconds $Interval
}
