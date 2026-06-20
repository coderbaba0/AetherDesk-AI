# run-health-ai.ps1
# AetherDesk AI - Professional System Health Dashboard
# Fixed version: no unsafe markdown parser, no broken here-string prompt, no null path issue

$BaseDir = $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($BaseDir)) {
    $BaseDir = (Get-Location).Path
}

$ConfigPath = Join-Path $BaseDir "config.json"
$ReportsDir = Join-Path $BaseDir "reports"
$SystemHealthPath = Join-Path $BaseDir "system-health.ps1"
$OllamaPath = Join-Path $BaseDir "ollama.ps1"

if (!(Test-Path $ReportsDir)) {
    New-Item -ItemType Directory -Path $ReportsDir -Force | Out-Null
}

if (Test-Path $SystemHealthPath) {
    . $SystemHealthPath
}

if (Test-Path $OllamaPath) {
    . $OllamaPath
}

function HtmlSafe {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    return [System.Net.WebUtility]::HtmlEncode($Text)
}

function Convert-MarkdownLiteToHtml {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return "<p>No AI summary available.</p>"
    }

    $text = $Text -replace "`r`n", "`n"
    $lines = $text -split "`n"

    $html = ""
    $inUl = $false
    $inOl = $false

    foreach ($rawLine in $lines) {
        $line = $rawLine.Trim()

        if ([string]::IsNullOrWhiteSpace($line)) {
            if ($inUl) {
                $html += "</ul>"
                $inUl = $false
            }

            if ($inOl) {
                $html += "</ol>"
                $inOl = $false
            }

            continue
        }

        $safe = HtmlSafe $line

        # Bold markdown only: **text**
        $safe = [regex]::Replace($safe, '\*\*(.+?)\*\*', '<strong>$1</strong>')

        if ($safe -match '^###\s+(.+)$') {
            if ($inUl) {
                $html += "</ul>"
                $inUl = $false
            }

            if ($inOl) {
                $html += "</ol>"
                $inOl = $false
            }

            $html += "<h4>" + $matches[1] + "</h4>"
        }
        elseif ($safe -match '^##\s+(.+)$') {
            if ($inUl) {
                $html += "</ul>"
                $inUl = $false
            }

            if ($inOl) {
                $html += "</ol>"
                $inOl = $false
            }

            $html += "<h3>" + $matches[1] + "</h3>"
        }
        elseif ($safe -match '^#\s+(.+)$') {
            if ($inUl) {
                $html += "</ul>"
                $inUl = $false
            }

            if ($inOl) {
                $html += "</ol>"
                $inOl = $false
            }

            $html += "<h3>" + $matches[1] + "</h3>"
        }
        elseif ($safe -match '^\d+\.\s+(.+)$') {
            if ($inUl) {
                $html += "</ul>"
                $inUl = $false
            }

            if (-not $inOl) {
                $html += "<ol>"
                $inOl = $true
            }

            $html += "<li>" + $matches[1] + "</li>"
        }
        elseif ($safe -match '^-+\s+(.+)$' -or $safe -match '^\*\s+(.+)$') {
            if ($inOl) {
                $html += "</ol>"
                $inOl = $false
            }

            if (-not $inUl) {
                $html += "<ul>"
                $inUl = $true
            }

            $html += "<li>" + $matches[1] + "</li>"
        }
        else {
            if ($inUl) {
                $html += "</ul>"
                $inUl = $false
            }

            if ($inOl) {
                $html += "</ol>"
                $inOl = $false
            }

            $html += "<p>$safe</p>"
        }
    }

    if ($inUl) {
        $html += "</ul>"
    }

    if ($inOl) {
        $html += "</ol>"
    }

    return $html
}

function Get-BarClass {
    param(
        [double]$Value,
        [double]$Warning,
        [double]$Danger
    )

    if ($Value -ge $Danger) {
        return "danger"
    }

    if ($Value -ge $Warning) {
        return "warning"
    }

    return "good"
}

function Get-BadgeClass {
    param([string]$Status)

    if ([string]::IsNullOrWhiteSpace($Status)) {
        return "warning"
    }

    $s = $Status.ToLower()

    if ($s -match "online|working|ok|healthy|available|connected") {
        return "good"
    }

    if ($s -match "offline|issue|error|fail|not") {
        return "danger"
    }

    return "warning"
}

function Get-SystemMetrics {
    $cpuLoad = 0
    $ramPercent = 0
    $diskCards = ""
    $batteryText = "Not available"
    $uptimeText = "Not available"
    $osText = "Windows"
    $internetStatus = "Unknown"
    $dnsStatus = "Unknown"
    $wifiText = "Unknown"
    $bluetoothText = "Unknown"
    $topProcessesText = ""

    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $osText = "$($os.Caption) $($os.OSArchitecture)"
        $lastBoot = $os.LastBootUpTime
        $uptime = (Get-Date) - $lastBoot
        $uptimeText = "$([math]::Floor($uptime.TotalDays)) days $($uptime.Hours) h $($uptime.Minutes) min"

        $totalMem = [double]$os.TotalVisibleMemorySize
        $freeMem = [double]$os.FreePhysicalMemory

        if ($totalMem -gt 0) {
            $ramPercent = [math]::Round((($totalMem - $freeMem) / $totalMem) * 100, 1)
        }
    }
    catch {}

    try {
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        if ($cpu -and $cpu.LoadPercentage -ne $null) {
            $cpuLoad = [double]$cpu.LoadPercentage
        }
    }
    catch {}

    try {
        $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($battery) {
            $batteryText = "$($battery.EstimatedChargeRemaining)%"
        }
    }
    catch {}

    try {
        $ping = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -ErrorAction SilentlyContinue
        if ($ping) {
            $internetStatus = "Online"
        }
        else {
            $internetStatus = "Offline"
        }
    }
    catch {
        $internetStatus = "Offline"
    }

    try {
        Resolve-DnsName "google.com" -ErrorAction Stop | Out-Null
        $dnsStatus = "Working"
    }
    catch {
        $dnsStatus = "Issue"
    }

    try {
        $wifiRaw = netsh wlan show interfaces 2>$null

        $wifiNameLine = ($wifiRaw | Select-String "SSID" | Select-Object -First 1)
        $wifiSignalLine = ($wifiRaw | Select-String "Signal" | Select-Object -First 1)
        $wifiStateLine = ($wifiRaw | Select-String "State" | Select-Object -First 1)

        $wifiTextParts = @()

        if ($wifiStateLine) {
            $wifiTextParts += $wifiStateLine.ToString().Trim()
        }

        if ($wifiNameLine) {
            $wifiTextParts += $wifiNameLine.ToString().Trim()
        }

        if ($wifiSignalLine) {
            $wifiTextParts += $wifiSignalLine.ToString().Trim()
        }

        if ($wifiTextParts.Count -gt 0) {
            $wifiText = ($wifiTextParts -join " | ")
        }
    }
    catch {}

    try {
        $bt = Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object {
            ($_.FriendlyName -match "Bluetooth") -or
            ($_.Name -match "Bluetooth") -or
            ($_.InstanceId -match "BTH")
        }

        if ($bt) {
            $bluetoothText = "$($bt.Count) Bluetooth device/service entries found"
        }
        else {
            $bluetoothText = "No Bluetooth device found"
        }
    }
    catch {}

    try {
        $processes = Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 5
        foreach ($p in $processes) {
            $memMb = [math]::Round($p.WorkingSet64 / 1MB, 1)
            $topProcessesText += "$($p.ProcessName): $memMb MB`n"
        }
    }
    catch {}

    try {
        $drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"

        foreach ($d in $drives) {
            $size = [double]$d.Size
            $free = [double]$d.FreeSpace

            if ($size -gt 0) {
                $usedPercent = [math]::Round((($size - $free) / $size) * 100, 1)
                $freeGb = [math]::Round($free / 1GB, 1)
                $sizeGb = [math]::Round($size / 1GB, 1)
                $cls = Get-BarClass -Value $usedPercent -Warning 75 -Danger 90
                $driveName = HtmlSafe $d.DeviceID

                $diskCards += @"
                <div class="metric-card">
                    <div class="metric-label">Disk $driveName</div>
                    <div class="metric-value">$usedPercent%</div>
                    <div class="metric-note">$freeGb GB free of $sizeGb GB</div>
                    <div class="bar"><div class="fill $cls" style="width:$usedPercent%"></div></div>
                </div>
"@
            }
        }
    }
    catch {}

    if ([string]::IsNullOrWhiteSpace($diskCards)) {
        $diskCards = "<div class='metric-card'><div class='metric-label'>Disk</div><div class='metric-note'>Disk data not available.</div></div>"
    }

    return [PSCustomObject]@{
        CpuLoad = [math]::Round($cpuLoad, 1)
        RamPercent = [math]::Round($ramPercent, 1)
        DiskCards = $diskCards
        BatteryText = $batteryText
        UptimeText = $uptimeText
        OsText = $osText
        InternetStatus = $internetStatus
        DnsStatus = $dnsStatus
        WifiText = $wifiText
        BluetoothText = $bluetoothText
        TopProcessesText = $topProcessesText
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " AetherDesk AI System Health Dashboard" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Built by: flutterfever.com" -ForegroundColor Green
Write-Host ""

if (!(Test-Path $ConfigPath)) {
    Write-Host "config.json not found." -ForegroundColor Red
    exit
}

$Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

$context = ""

if (Get-Command Get-FullSystemHealthContext -ErrorAction SilentlyContinue) {
    try {
        $context = Get-FullSystemHealthContext
    }
    catch {
        $context = "System health context function failed. Basic metrics were collected directly."
    }
}
else {
    $context = "System health context function not found. Basic metrics were collected directly."
}

$metrics = Get-SystemMetrics

$aiText = ""
$usedModel = "AI unavailable"

$promptLines = @(
    "You are a Windows system health analyst.",
    "",
    "Analyze this local system health data.",
    "",
    "Use clean Markdown only.",
    "",
    "System data:",
    $context,
    "",
    "Important metrics:",
    "CPU Load: $($metrics.CpuLoad)%",
    "RAM Usage: $($metrics.RamPercent)%",
    "Internet: $($metrics.InternetStatus)",
    "DNS: $($metrics.DnsStatus)",
    "WiFi: $($metrics.WifiText)",
    "Bluetooth: $($metrics.BluetoothText)",
    "Battery: $($metrics.BatteryText)",
    "Uptime: $($metrics.UptimeText)",
    "OS: $($metrics.OsText)",
    "Top Processes:",
    $metrics.TopProcessesText,
    "",
    "Create report in this format:",
    "",
    "## Overall Health Summary",
    "Write 2 short lines.",
    "",
    "## Key Issues",
    "- Mention possible issues if any.",
    "- If nothing major, say no major issue found from available data.",
    "",
    "## Network and Connectivity",
    "- Comment on WiFi, internet and DNS.",
    "",
    "## Performance",
    "- Comment on CPU, RAM and disk.",
    "",
    "## Recommended Actions",
    "1. One practical action.",
    "2. Second practical action.",
    "3. Third practical action.",
    "",
    "## Final Verdict",
    "Give one clear verdict.",
    "",
    "Rules:",
    "- Use only given data.",
    "- Do not invent hardware problems.",
    "- Keep concise."
)

$prompt = $promptLines -join "`n"

if (Get-Command Test-Ollama -ErrorAction SilentlyContinue) {
    if (Test-Ollama) {
        Write-Host "Generating AI system health summary..." -ForegroundColor Yellow

        try {
            $aiResponse = Invoke-Ollama -Prompt $prompt -Config $Config

            if ($aiResponse.Success -eq $true) {
                $aiText = $aiResponse.Text
                $usedModel = $aiResponse.Model
            }
            else {
                $aiText = "## AI Summary Unavailable`n- AI system diagnosis could not be generated.`n- Dashboard was created using available system metrics."
            }
        }
        catch {
            $aiText = "## AI Summary Unavailable`n- Ollama request failed.`n- Dashboard was created using available system metrics."
        }
    }
    else {
        $aiText = "## AI Summary Unavailable`n- Ollama is not running.`n- Dashboard was created using available system metrics."
        $usedModel = "Ollama offline"
    }
}
else {
    $aiText = "## AI Summary Unavailable`n- ollama.ps1 was not loaded.`n- Dashboard was created using available system metrics."
    $usedModel = "AI module missing"
}

$aiHtml = Convert-MarkdownLiteToHtml $aiText

$cpuClass = Get-BarClass -Value $metrics.CpuLoad -Warning 65 -Danger 85
$ramClass = Get-BarClass -Value $metrics.RamPercent -Warning 70 -Danger 88
$internetClass = Get-BadgeClass $metrics.InternetStatus
$dnsClass = Get-BadgeClass $metrics.DnsStatus

$contextSafe = HtmlSafe $context
$generatedAt = Get-Date -Format "dd MMM yyyy, hh:mm tt"
$today = Get-Date -Format "yyyy-MM-dd-HH-mm"
$htmlPath = Join-Path $ReportsDir "$today-system-health-pro-dashboard.html"

$html = @"
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>AetherDesk AI System Health Dashboard</title>
<style>
*{box-sizing:border-box}
:root{
  --bg:#eef4f1;
  --card:#fff;
  --text:#13231d;
  --muted:#66756f;
  --green:#0d7354;
  --green2:#34d399;
  --blue:#2563eb;
  --amber:#f59e0b;
  --red:#ef4444;
  --border:#dceae5;
  --shadow:0 18px 45px rgba(13,75,55,.10);
}
body{
  margin:0;
  background:var(--bg);
  color:var(--text);
  font-family:"Segoe UI",Arial,sans-serif;
}
.page{
  padding:32px;
  background:
    radial-gradient(circle at top left,rgba(16,185,129,.24),transparent 32%),
    radial-gradient(circle at top right,rgba(37,99,235,.18),transparent 30%),
    linear-gradient(135deg,#f8fbfa,#edf5f1);
  min-height:100vh;
}
.hero{
  background:linear-gradient(135deg,#061d18,#0b4f3b 55%,#10a37f);
  color:white;
  border-radius:30px;
  padding:36px;
  box-shadow:0 24px 70px rgba(0,0,0,.22);
  position:relative;
  overflow:hidden;
}
.hero:after{
  content:"";
  position:absolute;
  right:-110px;
  top:-120px;
  width:330px;
  height:330px;
  border-radius:50%;
  background:rgba(255,255,255,.13);
}
.topbar{
  display:flex;
  justify-content:space-between;
  gap:16px;
  align-items:center;
  position:relative;
  z-index:1;
}
.tag{
  display:inline-block;
  padding:8px 14px;
  border:1px solid rgba(255,255,255,.25);
  border-radius:999px;
  background:rgba(255,255,255,.12);
  font-size:12px;
  letter-spacing:.8px;
  text-transform:uppercase;
}
.btn{
  border:none;
  border-radius:14px;
  padding:11px 15px;
  font-weight:900;
  cursor:pointer;
  background:white;
  color:#0b4f3b;
}
h1{
  font-size:44px;
  line-height:1.08;
  margin:24px 0 10px;
  position:relative;
  z-index:1;
}
.subtitle{
  opacity:.9;
  font-size:16px;
  line-height:1.6;
  max-width:900px;
  position:relative;
  z-index:1;
}
.hero-grid{
  display:grid;
  grid-template-columns:repeat(5,1fr);
  gap:14px;
  margin-top:28px;
  position:relative;
  z-index:1;
}
.hero-stat{
  padding:15px;
  border-radius:18px;
  background:rgba(255,255,255,.12);
  border:1px solid rgba(255,255,255,.20);
}
.hero-stat .label{
  font-size:12px;
  opacity:.75;
}
.hero-stat .value{
  font-size:18px;
  font-weight:1000;
  margin-top:6px;
  word-break:break-word;
}
.section{
  margin-top:24px;
  background:rgba(255,255,255,.95);
  border:1px solid rgba(13,75,55,.10);
  border-radius:26px;
  padding:24px;
  box-shadow:var(--shadow);
}
.section-title{
  display:flex;
  align-items:center;
  justify-content:space-between;
  gap:12px;
  margin-bottom:18px;
}
.title-left{
  display:flex;
  align-items:center;
  gap:12px;
}
.title-left span{
  width:12px;
  height:32px;
  border-radius:999px;
  background:linear-gradient(180deg,var(--green),var(--green2));
}
.section-title h2{
  margin:0;
  font-size:24px;
}
.metric-grid{
  display:grid;
  grid-template-columns:repeat(4,1fr);
  gap:16px;
}
.metric-card{
  background:#fff;
  border:1px solid var(--border);
  border-radius:22px;
  padding:20px;
  box-shadow:0 8px 24px rgba(13,75,55,.05);
}
.metric-label{
  color:var(--muted);
  font-size:12px;
  font-weight:800;
  text-transform:uppercase;
  letter-spacing:.5px;
}
.metric-value{
  font-size:34px;
  font-weight:1000;
  color:#0b3b2d;
  margin-top:8px;
}
.metric-note{
  color:var(--muted);
  font-size:13px;
  margin-top:6px;
  line-height:1.45;
}
.bar{
  height:13px;
  background:#e8efec;
  border-radius:999px;
  overflow:hidden;
  margin-top:13px;
}
.fill{
  height:100%;
  border-radius:999px;
  background:linear-gradient(90deg,var(--green),var(--green2));
}
.fill.good{
  background:linear-gradient(90deg,#10b981,#34d399);
}
.fill.warning{
  background:linear-gradient(90deg,#f59e0b,#fbbf24);
}
.fill.danger{
  background:linear-gradient(90deg,#ef4444,#fb7185);
}
.badge{
  display:inline-block;
  padding:7px 11px;
  border-radius:999px;
  font-weight:900;
  font-size:13px;
}
.badge.good{
  background:#dcfce7;
  color:#166534;
}
.badge.warning{
  background:#fef3c7;
  color:#92400e;
}
.badge.danger{
  background:#fee2e2;
  color:#991b1b;
}
.ai-box{
  background:linear-gradient(180deg,#ffffff,#f5fbf8);
  border:1px solid #d9eee6;
}
.ai-head{
  display:flex;
  align-items:center;
  gap:14px;
  margin-bottom:14px;
}
.ai-icon{
  width:46px;
  height:46px;
  border-radius:16px;
  background:linear-gradient(135deg,#0d7354,#34d399);
  display:flex;
  align-items:center;
  justify-content:center;
  color:white;
  font-size:22px;
  font-weight:900;
}
.ai-meta{
  color:var(--muted);
  font-size:13px;
}
.ai-content h3{
  color:#0d5c43;
  font-size:19px;
  margin:22px 0 10px;
  border-left:4px solid #10a37f;
  padding-left:10px;
}
.ai-content h4{
  color:#0b3b2d;
  font-size:16px;
  margin:18px 0 8px;
}
.ai-content p{
  color:#32443d;
  line-height:1.72;
  font-size:15px;
  margin:10px 0;
}
.ai-content ul,.ai-content ol{
  background:#f1faf7;
  border:1px solid #dff3eb;
  border-left:4px solid #34c49a;
  border-radius:14px;
  padding:14px 18px 14px 34px;
  margin:14px 0;
}
.ai-content li{
  margin:8px 0;
  line-height:1.55;
}
.raw-box{
  background:#07130f;
  color:#c7f8e4;
  padding:18px;
  border-radius:18px;
  white-space:pre-wrap;
  overflow:auto;
  font-family:Consolas,monospace;
  font-size:12px;
  line-height:1.5;
  max-height:460px;
}
.footer{
  text-align:center;
  color:#687870;
  margin-top:24px;
  font-size:12px;
}
@media print{
  body{background:white}
  .page{padding:16px;background:white}
  .topbar,.raw-section,.footer{display:none!important}
  .section,.metric-card,.hero{box-shadow:none}
}
@media(max-width:1000px){
  .hero-grid,.metric-grid{grid-template-columns:1fr}
  .page{padding:16px}
  h1{font-size:32px}
}
</style>
</head>
<body>
<div class="page">

  <div class="hero">
    <div class="topbar">
      <div class="tag">AetherDesk AI · System Health</div>
      <button class="btn" onclick="window.print()">Save as PDF</button>
    </div>

    <h1>System Health Pro Dashboard</h1>
    <div class="subtitle">
      Professional Windows system diagnostic dashboard with CPU, RAM, disk, Wi-Fi, Bluetooth, internet, DNS and AI-rendered Markdown diagnosis.
    </div>

    <div class="hero-grid">
      <div class="hero-stat"><div class="label">Generated</div><div class="value">$generatedAt</div></div>
      <div class="hero-stat"><div class="label">OS</div><div class="value">$($metrics.OsText)</div></div>
      <div class="hero-stat"><div class="label">Uptime</div><div class="value">$($metrics.UptimeText)</div></div>
      <div class="hero-stat"><div class="label">Battery</div><div class="value">$($metrics.BatteryText)</div></div>
      <div class="hero-stat"><div class="label">AI model</div><div class="value">$usedModel</div></div>
    </div>
  </div>

  <div class="section">
    <div class="section-title">
      <div class="title-left"><span></span><h2>Health Metrics</h2></div>
    </div>

    <div class="metric-grid">
      <div class="metric-card">
        <div class="metric-label">CPU load</div>
        <div class="metric-value">$($metrics.CpuLoad)%</div>
        <div class="metric-note">Current processor load</div>
        <div class="bar"><div class="fill $cpuClass" style="width:$($metrics.CpuLoad)%"></div></div>
      </div>

      <div class="metric-card">
        <div class="metric-label">RAM usage</div>
        <div class="metric-value">$($metrics.RamPercent)%</div>
        <div class="metric-note">Physical memory usage</div>
        <div class="bar"><div class="fill $ramClass" style="width:$($metrics.RamPercent)%"></div></div>
      </div>

      <div class="metric-card">
        <div class="metric-label">Internet</div>
        <div class="metric-value"><span class="badge $internetClass">$($metrics.InternetStatus)</span></div>
        <div class="metric-note">Ping check to public DNS</div>
      </div>

      <div class="metric-card">
        <div class="metric-label">DNS</div>
        <div class="metric-value"><span class="badge $dnsClass">$($metrics.DnsStatus)</span></div>
        <div class="metric-note">Domain resolution status</div>
      </div>
    </div>
  </div>

  <div class="section">
    <div class="section-title">
      <div class="title-left"><span></span><h2>Disk Usage</h2></div>
    </div>

    <div class="metric-grid">
      $($metrics.DiskCards)
    </div>
  </div>

  <div class="section">
    <div class="section-title">
      <div class="title-left"><span></span><h2>Connectivity</h2></div>
    </div>

    <div class="metric-grid">
      <div class="metric-card">
        <div class="metric-label">Wi-Fi</div>
        <div class="metric-note">$($metrics.WifiText)</div>
      </div>

      <div class="metric-card">
        <div class="metric-label">Bluetooth</div>
        <div class="metric-note">$($metrics.BluetoothText)</div>
      </div>

      <div class="metric-card">
        <div class="metric-label">Top processes</div>
        <div class="metric-note" style="white-space:pre-wrap">$($metrics.TopProcessesText)</div>
      </div>

      <div class="metric-card">
        <div class="metric-label">Battery</div>
        <div class="metric-value">$($metrics.BatteryText)</div>
      </div>
    </div>
  </div>

  <div class="section ai-box">
    <div class="ai-head">
      <div class="ai-icon">AI</div>
      <div>
        <div style="font-size:22px;font-weight:1000;color:#0b3b2d;">AI System Health Summary</div>
        <div class="ai-meta">Markdown rendered system diagnosis generated locally when Ollama is available.</div>
      </div>
    </div>

    <div class="ai-content">
      $aiHtml
    </div>
  </div>

  <div class="section raw-section">
    <div class="section-title">
      <div class="title-left"><span></span><h2>Raw Diagnostic Data</h2></div>
    </div>

    <div class="raw-box">$contextSafe</div>
  </div>

  <div class="footer">
    Generated locally by AetherDesk AI · Built by flutterfever.com
  </div>

</div>
</body>
</html>
"@

Set-Content -Path $htmlPath -Value $html -Encoding UTF8

Write-Host ""
Write-Host "Professional system health dashboard created:" -ForegroundColor Green
Write-Host $htmlPath -ForegroundColor Yellow
Write-Host ""

Start-Process $htmlPath
