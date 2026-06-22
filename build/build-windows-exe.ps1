# build-windows-exe.ps1
# Builds AetherDeskAI.exe with a generated icon.

$ErrorActionPreference = "Stop"

$BaseDir = Split-Path -Parent $PSScriptRoot
$BuildDir = Join-Path $BaseDir "build"
$AssetsDir = Join-Path $BaseDir "assets"
$IconPath = Join-Path $AssetsDir "aetherdesk.ico"
$SourcePath = Join-Path $BuildDir "AetherDeskAI-Launcher.cs"
$ExePath = Join-Path $BaseDir "AetherDeskAI.exe"

if (!(Test-Path $AssetsDir)) {
    New-Item -ItemType Directory -Path $AssetsDir -Force | Out-Null
}

Add-Type -AssemblyName System.Drawing

$bitmap = New-Object System.Drawing.Bitmap 256, 256
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.Clear([System.Drawing.Color]::FromArgb(16, 24, 39))

$rect = New-Object System.Drawing.Rectangle 18, 18, 220, 220
$brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $rect,
    [System.Drawing.Color]::FromArgb(18, 107, 92),
    [System.Drawing.Color]::FromArgb(41, 179, 145),
    45
)
$graphics.FillEllipse($brush, $rect)

$innerBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(245, 255, 252))
$font = New-Object System.Drawing.Font("Segoe UI", 82, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$format = New-Object System.Drawing.StringFormat
$format.Alignment = [System.Drawing.StringAlignment]::Center
$format.LineAlignment = [System.Drawing.StringAlignment]::Center
$graphics.DrawString("AI", $font, $innerBrush, (New-Object System.Drawing.RectangleF 18, 24, 220, 190), $format)

$sparkBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 245, 158, 11))
$graphics.FillEllipse($sparkBrush, 178, 42, 34, 34)
$graphics.FillEllipse($sparkBrush, 52, 182, 22, 22)

$iconHandle = $bitmap.GetHicon()
$icon = [System.Drawing.Icon]::FromHandle($iconHandle)
$stream = [System.IO.File]::Create($IconPath)
$icon.Save($stream)
$stream.Close()

$graphics.Dispose()
$brush.Dispose()
$innerBrush.Dispose()
$sparkBrush.Dispose()
$font.Dispose()
$bitmap.Dispose()

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
    /target:winexe `
    /platform:anycpu `
    /optimize+ `
    /win32icon:"$IconPath" `
    /reference:System.Windows.Forms.dll `
    /out:"$ExePath" `
    "$SourcePath"

if (!(Test-Path $ExePath)) {
    throw "AetherDeskAI.exe was not created."
}

Write-Host "Built:" -ForegroundColor Green
Write-Host $ExePath -ForegroundColor Yellow
Write-Host "Icon:" -ForegroundColor Green
Write-Host $IconPath -ForegroundColor Yellow
