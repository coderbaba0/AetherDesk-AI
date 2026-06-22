# activity-report.ps1
# TrendAI Productivity Pro Dashboard
# Dynamic graph + filters + AI markdown summary + Save as PDF button
# Data is safely injected into HTML using Base64 JSON

$BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $BaseDir "config.json"
$DataDir = Join-Path $BaseDir "activity-data"
$ReportsDir = Join-Path $BaseDir "reports"

if (!(Test-Path $ReportsDir)) {
    New-Item -ItemType Directory -Path $ReportsDir -Force | Out-Null
}

if (Test-Path (Join-Path $BaseDir "ollama.ps1")) {
    . (Join-Path $BaseDir "ollama.ps1")
}

function HtmlSafe {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    return [System.Net.WebUtility]::HtmlEncode($Text)
}

function ConvertTo-Base64Json {
    param([object]$Obj)

    $json = @($Obj) | ConvertTo-Json -Depth 40 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    return [Convert]::ToBase64String($bytes)
}

function Format-Duration {
    param([double]$Minutes)

    $totalSeconds = [math]::Round($Minutes * 60)

    if ($totalSeconds -lt 60) {
        return "$totalSeconds sec"
    }

    $hours = [math]::Floor($totalSeconds / 3600)
    $mins = [math]::Floor(($totalSeconds % 3600) / 60)
    $secs = $totalSeconds % 60

    if ($hours -gt 0) {
        return "$hours h $mins min"
    }

    if ($mins -gt 0 -and $secs -gt 0) {
        return "$mins min $secs sec"
    }

    return "$mins min"
}

function Get-AppCategory {
    param(
        [string]$ProcessName,
        [string]$Title
    )

    $p = ""
    $t = ""

    if ($ProcessName) { $p = $ProcessName.ToLower() }
    if ($Title) { $t = $Title.ToLower() }

    if ($p -match "code|devenv|pycharm|webstorm|phpstorm|idea|studio|androidstudio|terminal|powershell|cmd|git|node|python|npm|java|gradle|cursor|windsurf") {
        return "Development"
    }

    if ($p -match "chrome|edge|firefox|brave|opera") {
        if ($t -match "youtube|facebook|instagram|twitter|x.com|netflix|prime video|hotstar|reels|shorts|movie|songs") {
            return "Entertainment"
        }

        if ($t -match "github|stackoverflow|docs|documentation|learn|tutorial|openai|ollama|hugging face|microsoft|developer|api|course|research|paper") {
            return "Learning/Research"
        }

        return "Browser"
    }

    if ($p -match "winword|excel|powerpnt|onenote|notepad|notepad\+\+|wps|acrobat|pdf|wordpad") {
        return "Documents"
    }

    if ($p -match "teams|zoom|slack|whatsapp|telegram|discord|outlook|mail|gmail") {
        return "Communication"
    }

    if ($p -match "vlc|spotify|music|video|photos|media") {
        return "Media"
    }

    if ($p -match "explorer") {
        return "File Management"
    }

    return "Other"
}

function Get-ProductivityScore {
    param([hashtable]$CategorySeconds)

    $productive = 0
    $neutral = 0
    $distracting = 0

    foreach ($key in $CategorySeconds.Keys) {
        $s = [double]$CategorySeconds[$key]

        if ($key -in @("Development", "Learning/Research", "Documents", "File Management")) {
            $productive += $s
        }
        elseif ($key -in @("Entertainment", "Media")) {
            $distracting += $s
        }
        else {
            $neutral += $s
        }
    }

    $total = $productive + $neutral + $distracting

    if ($total -le 0) {
        return 0
    }

    $score = (($productive * 1.0) + ($neutral * 0.45) - ($distracting * 0.35)) / $total * 100

    if ($score -lt 0) { $score = 0 }
    if ($score -gt 100) { $score = 100 }

    return [math]::Round($score)
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
            if ($inUl) { $html += "</ul>"; $inUl = $false }
            if ($inOl) { $html += "</ol>"; $inOl = $false }
            continue
        }

        $safe = HtmlSafe $line
        $safe = [regex]::Replace($safe, "\*\*(.+?)\*\*", "<strong>`$1</strong>")
        $safe = [regex]::Replace($safe, "\*(.+?)\*", "<em>`$1</em>")

        if ($safe -match "^###\s+(.+)$") {
            if ($inUl) { $html += "</ul>"; $inUl = $false }
            if ($inOl) { $html += "</ol>"; $inOl = $false }
            $html += "<h4>$($matches[1])</h4>"
        }
        elseif ($safe -match "^##\s+(.+)$") {
            if ($inUl) { $html += "</ul>"; $inUl = $false }
            if ($inOl) { $html += "</ol>"; $inOl = $false }
            $html += "<h3>$($matches[1])</h3>"
        }
        elseif ($safe -match "^#\s+(.+)$") {
            if ($inUl) { $html += "</ul>"; $inUl = $false }
            if ($inOl) { $html += "</ol>"; $inOl = $false }
            $html += "<h3>$($matches[1])</h3>"
        }
        elseif ($safe -match "^\d+\.\s+(.+)$") {
            if ($inUl) { $html += "</ul>"; $inUl = $false }
            if (-not $inOl) { $html += "<ol>"; $inOl = $true }
            $html += "<li>$($matches[1])</li>"
        }
        elseif ($safe -match "^-+\s+(.+)$" -or $safe -match "^\*\s+(.+)$") {
            if ($inOl) { $html += "</ol>"; $inOl = $false }
            if (-not $inUl) { $html += "<ul>"; $inUl = $true }
            $html += "<li>$($matches[1])</li>"
        }
        else {
            if ($inUl) { $html += "</ul>"; $inUl = $false }
            if ($inOl) { $html += "</ol>"; $inOl = $false }
            $html += "<p>$safe</p>"
        }
    }

    if ($inUl) { $html += "</ul>" }
    if ($inOl) { $html += "</ol>" }

    return $html
}

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host " TrendAI Productivity Pro Dashboard" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

if (!(Test-Path $ConfigPath)) {
    Write-Host "config.json not found." -ForegroundColor Red
    exit
}

if (!(Test-Path $DataDir)) {
    Write-Host "activity-data folder not found." -ForegroundColor Red
    Write-Host "Pehle tracker run karo:" -ForegroundColor Yellow
    Write-Host "powershell -ExecutionPolicy Bypass -File H:\python_project\TrendAI-Agent\activity-tracker.ps1" -ForegroundColor Green
    exit
}

$Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

$csvFiles = Get-ChildItem -Path $DataDir -Filter "*-activity.csv" -File | Sort-Object LastWriteTime -Descending

if ($csvFiles.Count -eq 0) {
    Write-Host "Koi activity CSV file nahi mili." -ForegroundColor Yellow
    Write-Host "Tracker ko 1 minute run hone do, phir report banao." -ForegroundColor Yellow
    exit
}

$allRows = @()

foreach ($file in $csvFiles) {
    try {
        $rows = Import-Csv $file.FullName
        if ($rows) {
            $allRows += $rows
        }
    }
    catch {
        Write-Host "CSV read failed: $($file.Name)" -ForegroundColor Yellow
    }
}

if ($allRows.Count -eq 0) {
    Write-Host "CSV file mili, lekin rows read nahi hui." -ForegroundColor Red
    exit
}

$rowObjects = @()
$appSeconds = @{}
$categorySeconds = @{}
$titleSeconds = @{}

foreach ($row in $allRows) {
    $durationSeconds = 5

    try {
        $durationSeconds = [double]$row.DurationSeconds
    }
    catch {}

    if ($durationSeconds -le 0) {
        $durationSeconds = 5
    }

    $timeValue = $row.Time
    $date = $row.Date
    $app = $row.ProcessName
    $title = $row.AppTitle

    if ([string]::IsNullOrWhiteSpace($app)) { $app = "Unknown" }
    if ([string]::IsNullOrWhiteSpace($title)) { $title = "No title" }

    if ([string]::IsNullOrWhiteSpace($date)) {
        try {
            $date = ([datetime]$timeValue).ToString("yyyy-MM-dd")
        }
        catch {
            $date = Get-Date -Format "yyyy-MM-dd"
        }
    }

    $hour = "Unknown"

    try {
        $dt = [datetime]$timeValue
        $hour = $dt.ToString("HH:00")
    }
    catch {}

    $category = Get-AppCategory -ProcessName $app -Title $title

    if (!$appSeconds.ContainsKey($app)) { $appSeconds[$app] = 0 }
    $appSeconds[$app] += $durationSeconds

    if (!$categorySeconds.ContainsKey($category)) { $categorySeconds[$category] = 0 }
    $categorySeconds[$category] += $durationSeconds

    $titleKey = "$app - $title"
    if (!$titleSeconds.ContainsKey($titleKey)) { $titleSeconds[$titleKey] = 0 }
    $titleSeconds[$titleKey] += $durationSeconds

    $rowObjects += [PSCustomObject]@{
        time = $timeValue
        date = $date
        hour = $hour
        app = $app
        title = $title
        category = $category
        seconds = [math]::Round($durationSeconds, 2)
        durationText = Format-Duration ($durationSeconds / 60)
    }
}

$totalSeconds = 0
foreach ($r in $rowObjects) {
    $totalSeconds += $r.seconds
}

$totalMinutes = $totalSeconds / 60
$totalTimeText = Format-Duration $totalMinutes

$productivityScore = Get-ProductivityScore -CategorySeconds $categorySeconds

$sortedRows = $rowObjects | Sort-Object time
$firstTime = ($sortedRows | Select-Object -First 1).time
$lastTime = ($sortedRows | Select-Object -Last 1).time

if ([string]::IsNullOrWhiteSpace($firstTime)) { $firstTime = "Not available" }
if ([string]::IsNullOrWhiteSpace($lastTime)) { $lastTime = "Not available" }

$trackingNote = "Partial report"
if ($totalMinutes -lt 2) { $trackingNote = "Very early report" }
elseif ($totalMinutes -lt 30) { $trackingNote = "Short tracking report" }
elseif ($totalMinutes -lt 240) { $trackingNote = "Same-day partial report" }
else { $trackingNote = "Detailed activity report" }

$topApps = $appSeconds.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10
$topCategories = $categorySeconds.GetEnumerator() | Sort-Object Value -Descending
$topTitles = $titleSeconds.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 8

$summaryText = ""
$summaryText += "Tracking note: $trackingNote`n"
$summaryText += "Tracked period: $firstTime to $lastTime`n"
$summaryText += "Rows collected: $($rowObjects.Count)`n"
$summaryText += "Total tracked time: $totalTimeText`n"
$summaryText += "Productivity score: $productivityScore/100`n"
$summaryText += "`nTop apps:`n"

foreach ($a in $topApps) {
    $summaryText += "- $($a.Key): $(Format-Duration ($a.Value / 60))`n"
}

$summaryText += "`nCategory usage:`n"

foreach ($c in $topCategories) {
    $summaryText += "- $($c.Key): $(Format-Duration ($c.Value / 60))`n"
}

$summaryText += "`nTop active windows/titles:`n"

foreach ($t in $topTitles) {
    $summaryText += "- $($t.Key): $(Format-Duration ($t.Value / 60))`n"
}

$aiText = ""
$usedModel = "AI unavailable"

if (Get-Command Test-Ollama -ErrorAction SilentlyContinue) {
    if (Test-Ollama) {
        $prompt = @"
You are a personal productivity analyst.

Analyze this Windows app usage data.

Use clean Markdown only.

Data:
$summaryText

Create report in this format:

## Overall Summary
Write 2 short lines.

## App Usage Pattern
- Mention top apps and what it means.

## Productive vs Distracting
- Explain category balance.

## Focus Quality
- Explain if the work pattern looks focused or scattered.

## Suggestions
1. One practical improvement.
2. Second practical improvement.
3. Third practical improvement.

## Final Recommendation
One clear recommendation.

Rules:
- Do not invent apps.
- Use only given data.
- If tracking period is short, clearly say this is an early partial report.
- Keep concise.
"@

        Write-Host "Generating AI productivity summary..." -ForegroundColor Yellow
        $aiResponse = Invoke-Ollama -Prompt $prompt -Config $Config

        if ($aiResponse.Success -eq $true) {
            $aiText = $aiResponse.Text
            $usedModel = $aiResponse.Model
        }
        else {
            $aiText = "## AI Summary Unavailable`n- AI summary generate nahi ho payi.`n- Dashboard available activity data ke basis par ban gaya hai."
        }
    }
    else {
        $aiText = "## AI Summary Unavailable`n- Ollama running nahi hai.`n- Dashboard available activity data ke basis par ban gaya hai."
        $usedModel = "Ollama offline"
    }
}
else {
    $aiText = "## AI Summary Unavailable`n- ollama.ps1 load nahi hua.`n- Dashboard available activity data ke basis par ban gaya hai."
    $usedModel = "AI module missing"
}

$aiHtml = Convert-MarkdownLiteToHtml $aiText
$rowsJsonBase64 = ConvertTo-Base64Json $rowObjects

$dateOptions = ""
foreach ($d in ($rowObjects | Select-Object -ExpandProperty date -Unique | Sort-Object)) {
    $safe = HtmlSafe $d
    $dateOptions += "<option value='$safe'>$safe</option>"
}

$appOptions = ""
foreach ($a in ($rowObjects | Select-Object -ExpandProperty app -Unique | Sort-Object)) {
    $safe = HtmlSafe $a
    $appOptions += "<option value='$safe'>$safe</option>"
}

$categoryOptions = ""
foreach ($c in ($rowObjects | Select-Object -ExpandProperty category -Unique | Sort-Object)) {
    $safe = HtmlSafe $c
    $categoryOptions += "<option value='$safe'>$safe</option>"
}

$today = Get-Date -Format "yyyy-MM-dd-HH-mm"
$htmlPath = Join-Path $ReportsDir "$today-productivity-pro-dashboard.html"

$html = @"
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>TrendAI Productivity Pro Dashboard</title>
<style>
*{box-sizing:border-box}
:root{
  --bg:#eef4f1;
  --card:#ffffff;
  --soft:#f6fbf9;
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
  padding:30px;
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
  padding:34px;
  box-shadow:0 24px 70px rgba(0,0,0,.22);
  position:relative;
  overflow:hidden;
}
.hero:after{
  content:"";
  position:absolute;
  right:-120px;
  top:-130px;
  width:340px;
  height:340px;
  border-radius:50%;
  background:rgba(255,255,255,.13);
}
.topbar{
  display:flex;
  justify-content:space-between;
  align-items:center;
  gap:18px;
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
.actions{
  display:flex;
  gap:10px;
  flex-wrap:wrap;
}
.btn{
  border:none;
  border-radius:14px;
  padding:11px 15px;
  font-weight:900;
  cursor:pointer;
}
.btn.light{
  background:white;
  color:#0b4f3b;
}
.btn.ghost{
  background:rgba(255,255,255,.14);
  color:white;
  border:1px solid rgba(255,255,255,.22);
}
h1{
  font-size:42px;
  line-height:1.08;
  margin:24px 0 10px;
  position:relative;
  z-index:1;
}
.subtitle{
  opacity:.88;
  font-size:16px;
  line-height:1.6;
  max-width:950px;
  position:relative;
  z-index:1;
}
.hero-grid{
  display:grid;
  grid-template-columns:repeat(5,1fr);
  gap:14px;
  margin-top:26px;
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
  font-weight:900;
  margin-top:6px;
  word-break:break-word;
}
.section{
  margin-top:24px;
  background:rgba(255,255,255,.94);
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
.filter-grid{
  display:grid;
  grid-template-columns:1.4fr 1fr 1fr 1fr auto;
  gap:12px;
}
input,select{
  width:100%;
  border:1px solid var(--border);
  background:#fff;
  border-radius:14px;
  padding:12px 13px;
  font-size:14px;
  outline:none;
}
.kpi-grid{
  display:grid;
  grid-template-columns:repeat(4,1fr);
  gap:16px;
}
.kpi{
  background:#fff;
  border:1px solid var(--border);
  border-radius:22px;
  padding:20px;
  box-shadow:0 8px 24px rgba(13,75,55,.05);
}
.kpi-label{
  color:var(--muted);
  font-size:12px;
  font-weight:800;
  text-transform:uppercase;
  letter-spacing:.5px;
}
.kpi-value{
  font-size:34px;
  font-weight:1000;
  color:#0b3b2d;
  margin-top:8px;
}
.kpi-note{
  color:var(--muted);
  font-size:13px;
  margin-top:6px;
  line-height:1.45;
}
.grid-2{
  display:grid;
  grid-template-columns:1fr 1fr;
  gap:20px;
}
.chart-card{
  background:#fff;
  border:1px solid var(--border);
  border-radius:22px;
  padding:20px;
  min-height:320px;
}
.chart-title{
  font-weight:900;
  color:#0b3b2d;
  margin-bottom:16px;
}
.bar-row{
  margin-bottom:14px;
}
.bar-head{
  display:flex;
  justify-content:space-between;
  gap:12px;
  font-size:13px;
  margin-bottom:7px;
}
.bar-name{
  font-weight:900;
  color:#0b3b2d;
  white-space:nowrap;
  overflow:hidden;
  text-overflow:ellipsis;
  max-width:70%;
}
.bar-time{
  color:var(--muted);
  font-weight:800;
}
.bar{
  height:12px;
  background:#e8efec;
  border-radius:999px;
  overflow:hidden;
}
.fill{
  height:100%;
  border-radius:999px;
  background:linear-gradient(90deg,var(--green),var(--green2));
}
.fill.good{
  background:linear-gradient(90deg,#10b981,#34d399);
}
.fill.neutral{
  background:linear-gradient(90deg,#64748b,#94a3b8);
}
.fill.danger{
  background:linear-gradient(90deg,#ef4444,#fb7185);
}
.hour-chart{
  height:260px;
  display:grid;
  grid-template-columns:repeat(auto-fit,minmax(48px,1fr));
  gap:10px;
  align-items:end;
  padding-top:10px;
}
.hour-item{
  height:230px;
  display:flex;
  flex-direction:column;
  align-items:center;
  justify-content:flex-end;
}
.hour-bar{
  width:32px;
  min-height:4px;
  border-radius:16px 16px 6px 6px;
  background:linear-gradient(180deg,#2563eb,#34d399);
  box-shadow:0 8px 22px rgba(37,99,235,.16);
}
.hour-time{
  font-size:11px;
  color:#0b3b2d;
  font-weight:800;
  margin-top:7px;
}
.hour-label{
  font-size:11px;
  color:var(--muted);
  margin-top:5px;
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
.table-wrap{
  max-height:520px;
  overflow:auto;
  border-radius:16px;
}
table{
  width:100%;
  border-collapse:collapse;
  background:white;
  border-radius:16px;
  overflow:hidden;
}
th{
  text-align:left;
  background:#0d5c43;
  color:white;
  padding:13px;
  font-size:13px;
  position:sticky;
  top:0;
}
td{
  padding:12px 13px;
  border-bottom:1px solid #e5efeb;
  font-size:13px;
  color:#33443e;
  vertical-align:top;
}
tr:nth-child(even) td{
  background:#f7fbf9;
}
.cat-pill{
  display:inline-block;
  padding:5px 9px;
  border-radius:999px;
  background:#e9f7f1;
  color:#0d7354;
  font-weight:800;
  font-size:12px;
}
.empty{
  padding:18px;
  border-radius:16px;
  background:#fff7ed;
  color:#9a3412;
  border:1px solid #fed7aa;
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
  .actions,.filters,.footer{display:none!important}
  .section,.kpi,.chart-card{box-shadow:none}
  .hero{box-shadow:none}
}
@media(max-width:1050px){
  .hero-grid,.kpi-grid,.grid-2,.filter-grid{grid-template-columns:1fr}
  .page{padding:16px}
  h1{font-size:32px}
}
</style>
</head>
<body>
<div class="page">

  <div class="hero">
    <div class="topbar">
      <div class="tag">TrendAI Productivity Pro</div>
      <div class="actions">
        <button class="btn light" onclick="window.print()">Save as PDF</button>
        <button class="btn ghost" onclick="resetFilters()">Reset Filters</button>
      </div>
    </div>

    <h1>Professional App Usage Dashboard</h1>
    <div class="subtitle">
      Filterable app usage analytics with dynamic graph recalculation, productivity scoring, hour-wise activity pattern,
      category analysis and AI-rendered Markdown insights.
    </div>

    <div class="hero-grid">
      <div class="hero-stat"><div class="label">Report type</div><div class="value">$trackingNote</div></div>
      <div class="hero-stat"><div class="label">Tracked from</div><div class="value">$firstTime</div></div>
      <div class="hero-stat"><div class="label">Tracked until</div><div class="value">$lastTime</div></div>
      <div class="hero-stat"><div class="label">Total tracked</div><div class="value">$totalTimeText</div></div>
      <div class="hero-stat"><div class="label">AI model</div><div class="value">$usedModel</div></div>
    </div>
  </div>

  <div class="section filters">
    <div class="section-title">
      <div class="title-left"><span></span><h2>Filters</h2></div>
      <div id="filterCount" style="color:#66756f;font-weight:800;">Loading rows...</div>
    </div>
    <div class="filter-grid">
      <input id="searchBox" placeholder="Search app, title, category..." oninput="applyFilters()">
      <select id="dateFilter" onchange="applyFilters()"><option value="">All dates</option>$dateOptions</select>
      <select id="categoryFilter" onchange="applyFilters()"><option value="">All categories</option>$categoryOptions</select>
      <select id="appFilter" onchange="applyFilters()"><option value="">All apps</option>$appOptions</select>
      <button class="btn light" style="background:linear-gradient(135deg,#0d7354,#34d399);color:white" onclick="resetFilters()">Reset</button>
    </div>
  </div>

  <div class="section">
    <div class="section-title">
      <div class="title-left"><span></span><h2>Analytics Overview</h2></div>
    </div>
    <div class="kpi-grid">
      <div class="kpi"><div class="kpi-label">Productivity score</div><div class="kpi-value" id="scoreKpi">0</div><div class="kpi-note">Dynamic score based on filtered data</div></div>
      <div class="kpi"><div class="kpi-label">Tracked time</div><div class="kpi-value" id="timeKpi">0 sec</div><div class="kpi-note">Total visible activity duration</div></div>
      <div class="kpi"><div class="kpi-label">Rows visible</div><div class="kpi-value" id="rowsKpi">0</div><div class="kpi-note">Rows after filters</div></div>
      <div class="kpi"><div class="kpi-label">Top app</div><div class="kpi-value" id="topAppKpi" style="font-size:24px">-</div><div class="kpi-note">Most used app in current view</div></div>
    </div>
  </div>

  <div class="section">
    <div class="section-title">
      <div class="title-left"><span></span><h2>Graphical Insights</h2></div>
    </div>
    <div class="grid-2">
      <div class="chart-card">
        <div class="chart-title">Top apps by time</div>
        <div id="appChart"></div>
      </div>
      <div class="chart-card">
        <div class="chart-title">Usage by productivity category</div>
        <div id="categoryChart"></div>
      </div>
    </div>
  </div>

  <div class="section">
    <div class="section-title">
      <div class="title-left"><span></span><h2>Time-wise Activity Graph</h2></div>
    </div>
    <div id="hourChart" class="hour-chart"></div>
  </div>

  <div class="section ai-box">
    <div class="ai-head">
      <div class="ai-icon">AI</div>
      <div>
        <div style="font-size:22px;font-weight:1000;color:#0b3b2d;">AI Productivity Summary</div>
        <div class="ai-meta">Markdown rendered insight generated locally from tracked app data.</div>
      </div>
    </div>
    <div class="ai-content">
      $aiHtml
    </div>
  </div>

  <div class="section">
    <div class="section-title">
      <div class="title-left"><span></span><h2>Filterable Activity Log</h2></div>
    </div>
    <div class="table-wrap">
      <table>
        <thead>
          <tr>
            <th>Time</th>
            <th>App</th>
            <th>Category</th>
            <th>Window title</th>
            <th>Duration</th>
          </tr>
        </thead>
        <tbody id="activityBody"></tbody>
      </table>
    </div>
  </div>

  <div class="footer">Generated locally by TrendAI Local Agent · Use Save as PDF button to export this dashboard</div>
</div>

<script>
const activityRowsBase64 = "$rowsJsonBase64";

function decodeBase64Json(base64) {
  const binary = atob(base64);
  const bytes = Uint8Array.from(binary, function(ch) {
    return ch.charCodeAt(0);
  });
  const json = new TextDecoder("utf-8").decode(bytes);
  return JSON.parse(json);
}

const activityRows = decodeBase64Json(activityRowsBase64);
console.log("TrendAI activity rows loaded:", activityRows.length, activityRows);

function fmt(seconds){
  seconds = Math.round(Number(seconds || 0));
  if(seconds < 60) return seconds + " sec";
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  if(h > 0) return h + " h " + m + " min";
  if(s > 0) return m + " min " + s + " sec";
  return m + " min";
}

function escapeHtml(v){
  return String(v === undefined || v === null ? "" : v).replace(/[&<>"']/g, function(m){
    return {"&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;","'":"&#39;"}[m];
  });
}

function groupSum(rows, key){
  const map = {};
  rows.forEach(function(r) {
    const k = r[key] || "Unknown";
    map[k] = (map[k] || 0) + Number(r.seconds || 0);
  });
  return Object.entries(map).map(function(pair) {
    return { name: pair[0], seconds: pair[1] };
  }).sort(function(a,b) {
    return b.seconds - a.seconds;
  });
}

function productivityScore(rows){
  let productive = 0;
  let neutral = 0;
  let distracting = 0;

  rows.forEach(function(r) {
    const s = Number(r.seconds || 0);
    if(["Development","Learning/Research","Documents","File Management"].includes(r.category)) productive += s;
    else if(["Entertainment","Media"].includes(r.category)) distracting += s;
    else neutral += s;
  });

  const total = productive + neutral + distracting;
  if(total <= 0) return 0;

  let score = ((productive * 1.0) + (neutral * 0.45) - (distracting * 0.35)) / total * 100;
  if(score < 0) score = 0;
  if(score > 100) score = 100;

  return Math.round(score);
}

function classForCategory(cat){
  if(["Development","Learning/Research","Documents","File Management"].includes(cat)) return "good";
  if(["Entertainment","Media"].includes(cat)) return "danger";
  return "neutral";
}

function renderBarChart(elId, data, type){
  const el = document.getElementById(elId);

  if(!data.length){
    el.innerHTML = '<div class="empty">No data for selected filters.</div>';
    return;
  }

  const max = Math.max.apply(null, data.map(function(x){ return x.seconds; }).concat([1]));

  el.innerHTML = data.slice(0,10).map(function(item) {
    let pct = Math.round((item.seconds / max) * 100);
    if(pct < 4 && item.seconds > 0) pct = 4;

    const cls = type === "category" ? classForCategory(item.name) : "";

    return ''
      + '<div class="bar-row">'
      + '  <div class="bar-head">'
      + '    <div class="bar-name" title="' + escapeHtml(item.name) + '">' + escapeHtml(item.name) + '</div>'
      + '    <div class="bar-time">' + fmt(item.seconds) + '</div>'
      + '  </div>'
      + '  <div class="bar"><div class="fill ' + cls + '" style="width:' + pct + '%"></div></div>'
      + '</div>';
  }).join("");
}

function renderHourChart(rows){
  const el = document.getElementById("hourChart");
  const grouped = groupSum(rows, "hour").sort(function(a,b) {
    return String(a.name).localeCompare(String(b.name));
  });

  if(!grouped.length){
    el.innerHTML = '<div class="empty">No hourly data for selected filters.</div>';
    return;
  }

  const max = Math.max.apply(null, grouped.map(function(x){ return x.seconds; }).concat([1]));

  el.innerHTML = grouped.map(function(item) {
    let h = Math.round((item.seconds / max) * 100);
    if(h < 4 && item.seconds > 0) h = 4;

    return ''
      + '<div class="hour-item" title="' + escapeHtml(item.name) + ' - ' + fmt(item.seconds) + '">'
      + '  <div class="hour-bar" style="height:' + h + '%"></div>'
      + '  <div class="hour-time">' + fmt(item.seconds) + '</div>'
      + '  <div class="hour-label">' + escapeHtml(item.name) + '</div>'
      + '</div>';
  }).join("");
}

function renderTable(rows){
  const body = document.getElementById("activityBody");

  const sorted = rows.slice().sort(function(a,b) {
    return String(b.time).localeCompare(String(a.time));
  });

  body.innerHTML = sorted.map(function(r) {
    return ''
      + '<tr>'
      + '  <td>' + escapeHtml(r.time) + '</td>'
      + '  <td>' + escapeHtml(r.app) + '</td>'
      + '  <td><span class="cat-pill">' + escapeHtml(r.category) + '</span></td>'
      + '  <td>' + escapeHtml(r.title) + '</td>'
      + '  <td>' + escapeHtml(r.durationText || fmt(r.seconds)) + '</td>'
      + '</tr>';
  }).join("");
}

function getFilteredRows(){
  const search = document.getElementById("searchBox").value.toLowerCase();
  const date = document.getElementById("dateFilter").value;
  const category = document.getElementById("categoryFilter").value;
  const app = document.getElementById("appFilter").value;

  return activityRows.filter(function(r) {
    const blob = String((r.app || "") + " " + (r.title || "") + " " + (r.category || "") + " " + (r.date || "") + " " + (r.hour || "")).toLowerCase();

    if(search && blob.indexOf(search) === -1) return false;
    if(date && r.date !== date) return false;
    if(category && r.category !== category) return false;
    if(app && r.app !== app) return false;

    return true;
  });
}

function applyFilters(){
  const rows = getFilteredRows();
  const total = rows.reduce(function(s,r) {
    return s + Number(r.seconds || 0);
  }, 0);

  const apps = groupSum(rows, "app");
  const cats = groupSum(rows, "category");

  document.getElementById("scoreKpi").innerText = productivityScore(rows);
  document.getElementById("timeKpi").innerText = fmt(total);
  document.getElementById("rowsKpi").innerText = rows.length;
  document.getElementById("topAppKpi").innerText = apps.length ? apps[0].name : "-";
  document.getElementById("filterCount").innerText = "Showing " + rows.length + " of " + activityRows.length + " rows";

  renderBarChart("appChart", apps, "app");
  renderBarChart("categoryChart", cats, "category");
  renderHourChart(rows);
  renderTable(rows);
}

function resetFilters(){
  document.getElementById("searchBox").value = "";
  document.getElementById("dateFilter").value = "";
  document.getElementById("categoryFilter").value = "";
  document.getElementById("appFilter").value = "";
  applyFilters();
}

try {
  applyFilters();
} catch (err) {
  console.error("TrendAI dashboard error:", err);
  document.getElementById("filterCount").innerText = "Dashboard error. Open browser console for details.";
}
</script>
</body>
</html>
"@

Set-Content -Path $htmlPath -Value $html -Encoding UTF8

Write-Host ""
Write-Host "Productivity Pro dashboard created:" -ForegroundColor Green
Write-Host $htmlPath -ForegroundColor Yellow
Write-Host ""
Write-Host "Open browser Console with F12 if data still does not render." -ForegroundColor Cyan
Write-Host ""

Start-Process $htmlPath
