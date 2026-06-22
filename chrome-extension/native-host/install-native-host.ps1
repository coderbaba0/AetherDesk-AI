# install-native-host.ps1

param(
    [Parameter(Mandatory = $true)]
    [string]$ExtensionId,

    [switch]$Edge
)

$ErrorActionPreference = "Stop"

$HostName = "com.aetherdesk.ai"
$HostDir = $PSScriptRoot
$SourcePath = Join-Path $HostDir "AetherDeskNativeHost.cs"
$ExePath = Join-Path $HostDir "AetherDeskNativeHost.exe"
$ManifestPath = Join-Path $HostDir "$HostName.json"

$cscCandidates = @(
    "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
    "$env:SystemRoot\Microsoft.NET\Framework\v4.0.30319\csc.exe"
)

$csc = $cscCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if ([string]::IsNullOrWhiteSpace($csc)) {
    throw "C# compiler was not found."
}

& $csc `
    /nologo `
    /target:exe `
    /platform:anycpu `
    /optimize+ `
    /reference:System.Web.Extensions.dll `
    /out:"$ExePath" `
    "$SourcePath"

if (!(Test-Path $ExePath)) {
    throw "Native host executable was not created."
}

$manifest = [ordered]@{
    name = $HostName
    description = "AetherDesk AI Native Messaging Host"
    path = $ExePath
    type = "stdio"
    allowed_origins = @("chrome-extension://$ExtensionId/")
}

$manifest | ConvertTo-Json -Depth 6 | Set-Content -Path $ManifestPath -Encoding ASCII

$chromeKey = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\$HostName"
New-Item -Path $chromeKey -Force | Out-Null
Set-Item -Path $chromeKey -Value $ManifestPath

if ($Edge) {
    $edgeKey = "HKCU:\Software\Microsoft\Edge\NativeMessagingHosts\$HostName"
    New-Item -Path $edgeKey -Force | Out-Null
    Set-Item -Path $edgeKey -Value $ManifestPath
}

Write-Host "Native host installed:" -ForegroundColor Green
Write-Host $HostName -ForegroundColor Yellow
Write-Host "Manifest:" -ForegroundColor Green
Write-Host $ManifestPath -ForegroundColor Yellow
Write-Host "Allowed extension:" -ForegroundColor Green
Write-Host $ExtensionId -ForegroundColor Yellow
