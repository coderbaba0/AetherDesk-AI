# activity-tracker.ps1
# Reliable active app tracker - writes CSV immediately and then every 5 seconds

$BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DataDir = Join-Path $BaseDir "activity-data"

if (!(Test-Path $DataDir)) {
    New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
}

Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;

public class ActiveWindowTracker {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
}
"@

function Get-ActiveWindowInfo {
    try {
        $handle = [ActiveWindowTracker]::GetForegroundWindow()

        if ($handle -eq [IntPtr]::Zero) {
            return $null
        }

        $titleBuilder = New-Object System.Text.StringBuilder 1024
        [void][ActiveWindowTracker]::GetWindowText($handle, $titleBuilder, $titleBuilder.Capacity)

        $processId = 0
        [void][ActiveWindowTracker]::GetWindowThreadProcessId($handle, [ref]$processId)

        $process = Get-Process -Id $processId -ErrorAction SilentlyContinue

        if ($null -eq $process) {
            return $null
        }

        $title = $titleBuilder.ToString()

        if ([string]::IsNullOrWhiteSpace($title)) {
            $title = "No title"
        }

        return [PSCustomObject]@{
            Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Date = Get-Date -Format "yyyy-MM-dd"
            ProcessName = $process.ProcessName
            AppTitle = $title
            ProcessId = $processId
        }
    }
    catch {
        return $null
    }
}

function Ensure-CsvHeader {
    param([string]$CsvPath)

    if (!(Test-Path $CsvPath)) {
        "Time,Date,ProcessName,AppTitle,ProcessId,DurationSeconds" | Set-Content -Path $CsvPath -Encoding UTF8
    }
}

function Write-ActivityRow {
    param(
        [object]$Info,
        [int]$DurationSeconds
    )

    $csvPath = Join-Path $DataDir "$($Info.Date)-activity.csv"
    Ensure-CsvHeader -CsvPath $csvPath

    $safeTitle = ($Info.AppTitle -replace '"', "'")
    $safeProcess = ($Info.ProcessName -replace '"', "'")

    $line = '"' + $Info.Time + '","' + $Info.Date + '","' + $safeProcess + '","' + $safeTitle + '","' + $Info.ProcessId + '","' + $DurationSeconds + '"'

    Add-Content -Path $csvPath -Value $line -Encoding UTF8

    return $csvPath
}

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host " TrendAI Activity Tracker Started" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Data folder:" -ForegroundColor Yellow
Write-Host $DataDir -ForegroundColor Green
Write-Host ""

Write-Host "Tracking active app usage locally every 5 seconds..." -ForegroundColor Yellow
Write-Host "Is window ko open rehne do. Close karoge to tracking stop ho jayegi." -ForegroundColor DarkGray
Write-Host ""

$intervalSeconds = 5
$lastShown = ""

# Immediate first write
$firstInfo = Get-ActiveWindowInfo

if ($firstInfo -ne $null) {
    $csv = Write-ActivityRow -Info $firstInfo -DurationSeconds $intervalSeconds
    Write-Host "CSV created/written:" -ForegroundColor Green
    Write-Host $csv -ForegroundColor Yellow
    Write-Host ""
}
else {
    Write-Host "Active window read nahi ho paya, lekin tracker running hai." -ForegroundColor Yellow
}

while ($true) {
    $info = Get-ActiveWindowInfo

    if ($info -ne $null) {
        $csvPath = Write-ActivityRow -Info $info -DurationSeconds $intervalSeconds

        $current = "$($info.ProcessName) - $($info.AppTitle)"

        if ($current -ne $lastShown) {
            Write-Host ""
            Write-Host "$(Get-Date -Format 'HH:mm:ss')  $current" -ForegroundColor Green
            $lastShown = $current
        }
        else {
            Write-Host -NoNewline "." -ForegroundColor DarkGray
        }
    }
    else {
        Write-Host -NoNewline "x" -ForegroundColor Red
    }

    Start-Sleep -Seconds $intervalSeconds
}
