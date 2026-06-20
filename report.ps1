# report.ps1
# AetherDesk AI - Fixed Professional Trending AI Report Generator
# Fixes:
# - Safe script root path
# - Markdown rendering
# - No PowerShell backtick parser error
# - No null Join-Path / Split-Path error

$Script:ReportBaseDir = $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($Script:ReportBaseDir)) {
    $Script:ReportBaseDir = (Get-Location).Path
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

        $safe = [regex]::Replace($safe, '\*\*(.+?)\*\*', '<strong>$1</strong>')
        $safe = [regex]::Replace($safe, '\*(.+?)\*', '<em>$1</em>')
        $safe = [regex]::Replace($safe, '`([^`]+)`', '<code>$1</code>')

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

function Get-ResultTypeClass {
    param([string]$Type)

    $t = ""
    if ($Type) {
        $t = $Type.ToLower()
    }

    if ($t -match "github") {
        return "github"
    }

    if ($t -match "video|youtube") {
        return "video"
    }

    if ($t -match "pdf|paper|research") {
        return "pdf"
    }

    return "article"
}

function Get-ResultTypeLabel {
    param([string]$Type)

    if ([string]::IsNullOrWhiteSpace($Type)) {
        return "Article"
    }

    return $Type
}

function New-AiPrompt {
    param(
        [string]$Topic,
        [array]$Results,
        [object]$Config
    )

    $items = ""
    $i = 1

    foreach ($r in $Results) {
        $title = $r.Title
        $link = $r.Link
        $type = $r.Type
        $snippet = $r.Snippet

        if ([string]::IsNullOrWhiteSpace($title)) {
            $title = "Untitled"
        }

        if ([string]::IsNullOrWhiteSpace($type)) {
            $type = "Article"
        }

        $items += "$i. [$type] $title`n"

        if ($snippet) {
            $items += "   Snippet: $snippet`n"
        }

        if ($link) {
            $items += "   Link: $link`n"
        }

        $items += "`n"
        $i++
    }

    return @"
You are an AI technology analyst.

Analyze the following search results for topic: "$Topic"

Results:
$items

Create a concise Markdown report using this exact format:

## Executive Summary
Write 2-3 lines about the topic trend.

## Key Trends
- Mention important trends from the links.
- Mention what is gaining attention.
- Mention what developers or researchers should watch.

## Best Resources
1. Mention the most useful resource.
2. Mention second useful resource.
3. Mention third useful resource.

## GitHub / Open Source Signals
- Mention open-source relevance if any GitHub links exist.
- If no GitHub result, say no strong GitHub signal found.

## Learning Path
- Suggest how a beginner or developer should explore this topic.

## Final Recommendation
Give one practical recommendation.

Rules:
- Use only the provided results.
- Do not invent facts.
- Keep it useful and short.
- Use clean Markdown.
"@
}

function New-TrendReport {
    param(
        [string]$Topic,
        [array]$Results,
        [object]$AiText,
        [object]$Config
    )

    $BaseDir = $Script:ReportBaseDir

    if ([string]::IsNullOrWhiteSpace($BaseDir)) {
        $BaseDir = (Get-Location).Path
    }

    $outputFolder = "reports"

    if ($Config -and $Config.PSObject.Properties.Name -contains "outputFolder") {
        if (-not [string]::IsNullOrWhiteSpace($Config.outputFolder)) {
            $outputFolder = $Config.outputFolder
        }
    }

    $ReportsDir = Join-Path $BaseDir $outputFolder

    if (!(Test-Path $ReportsDir)) {
        New-Item -ItemType Directory -Path $ReportsDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm"
    $safeTopic = ($Topic -replace '[\\/:*?"<>|]', '-')

    if ([string]::IsNullOrWhiteSpace($safeTopic)) {
        $safeTopic = "trend-report"
    }

    $htmlPath = Join-Path $ReportsDir "$timestamp-$safeTopic-trending-ai-dashboard.html"

    $aiRaw = ""

    if ($AiText -is [hashtable]) {
        if ($AiText.ContainsKey("Text")) {
            $aiRaw = [string]$AiText.Text
        }
    }
    elseif ($AiText -and $AiText.PSObject.Properties.Name -contains "Text") {
        $aiRaw = [string]$AiText.Text
    }
    else {
        $aiRaw = [string]$AiText
    }

    if ([string]::IsNullOrWhiteSpace($aiRaw)) {
        $aiRaw = "## AI Summary Unavailable`n- AI summary was not generated.`n- The report still includes collected search results."
    }

    $aiHtml = Convert-MarkdownLiteToHtml $aiRaw

    $totalResults = 0
    if ($Results) {
        $totalResults = $Results.Count
    }

    $articleCount = 0
    $videoCount = 0
    $pdfCount = 0
    $githubCount = 0

    foreach ($r in $Results) {
        $cls = Get-ResultTypeClass $r.Type

        if ($cls -eq "article") {
            $articleCount++
        }
        elseif ($cls -eq "video") {
            $videoCount++
        }
        elseif ($cls -eq "pdf") {
            $pdfCount++
        }
        elseif ($cls -eq "github") {
            $githubCount++
        }
    }

    $safeTotal = [math]::Max($totalResults, 1)

    $articleWidth = [math]::Max(4, [math]::Round(($articleCount / $safeTotal) * 100))
    $videoWidth = [math]::Max(4, [math]::Round(($videoCount / $safeTotal) * 100))
    $pdfWidth = [math]::Max(4, [math]::Round(($pdfCount / $safeTotal) * 100))
    $githubWidth = [math]::Max(4, [math]::Round(($githubCount / $safeTotal) * 100))

    $cards = ""
    $rank = 1

    foreach ($r in $Results) {
        $title = HtmlSafe $r.Title
        $link = HtmlSafe $r.Link
        $snippet = HtmlSafe $r.Snippet
        $typeLabel = HtmlSafe (Get-ResultTypeLabel $r.Type)
        $typeClass = Get-ResultTypeClass $r.Type

        if ([string]::IsNullOrWhiteSpace($title)) {
            $title = "Untitled resource"
        }

        if ([string]::IsNullOrWhiteSpace($snippet)) {
            $snippet = "No snippet available."
        }

        $cards += @"
        <article class="resource-card">
            <div class="resource-top">
                <div class="rank">#$rank</div>
                <div class="badge $typeClass">$typeLabel</div>
            </div>
            <h3>$title</h3>
            <p>$snippet</p>
            <a class="open-link" href="$link" target="_blank">Open resource →</a>
        </article>
"@

        $rank++
    }

    if ([string]::IsNullOrWhiteSpace($cards)) {
        $cards = "<div class='empty'>No search results found for this topic.</div>"
    }

    $topicSafe = HtmlSafe $Topic
    $generatedAt = Get-Date -Format "dd MMM yyyy, hh:mm tt"

    $html = @"
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>$topicSafe - AetherDesk AI Trending Report</title>
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
  --red:#ef4444;
  --amber:#f59e0b;
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
  font-size:22px;
  font-weight:1000;
  margin-top:6px;
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
}
.bar-time{
  color:var(--muted);
  font-weight:800;
}
.bar{
  height:13px;
  background:#e8efec;
  border-radius:999px;
  overflow:hidden;
}
.fill{
  height:100%;
  border-radius:999px;
  background:linear-gradient(90deg,var(--green),var(--green2));
}
.fill.video{
  background:linear-gradient(90deg,#ef4444,#fb7185);
}
.fill.pdf{
  background:linear-gradient(90deg,#f59e0b,#fbbf24);
}
.fill.github{
  background:linear-gradient(90deg,#111827,#475569);
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
.ai-content code{
  background:#e9f7f1;
  color:#0b4f3b;
  padding:2px 6px;
  border-radius:7px;
}
.resource-grid{
  display:grid;
  grid-template-columns:repeat(2,1fr);
  gap:18px;
}
.resource-card{
  background:#fff;
  border:1px solid var(--border);
  border-radius:22px;
  padding:20px;
  box-shadow:0 8px 24px rgba(13,75,55,.05);
  transition:.2s ease;
}
.resource-card:hover{
  transform:translateY(-2px);
  box-shadow:0 16px 35px rgba(13,75,55,.10);
}
.resource-top{
  display:flex;
  justify-content:space-between;
  align-items:center;
  margin-bottom:12px;
}
.rank{
  font-size:13px;
  font-weight:1000;
  color:#0b3b2d;
  background:#e9f7f1;
  padding:6px 10px;
  border-radius:999px;
}
.badge{
  font-size:12px;
  font-weight:900;
  border-radius:999px;
  padding:6px 10px;
  background:#e9f7f1;
  color:#0d7354;
}
.badge.video{
  background:#fee2e2;
  color:#b91c1c;
}
.badge.pdf{
  background:#fef3c7;
  color:#92400e;
}
.badge.github{
  background:#e5e7eb;
  color:#111827;
}
.resource-card h3{
  margin:0 0 10px;
  color:#0b3b2d;
  font-size:18px;
  line-height:1.35;
}
.resource-card p{
  color:#4b5f58;
  line-height:1.6;
  font-size:14px;
}
.open-link{
  display:inline-block;
  margin-top:10px;
  color:#0d7354;
  font-weight:900;
  text-decoration:none;
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
  .topbar,.footer{display:none!important}
  .section,.resource-card,.chart-card,.hero{box-shadow:none}
}
@media(max-width:1000px){
  .hero-grid,.grid-2,.resource-grid{grid-template-columns:1fr}
  .page{padding:16px}
  h1{font-size:32px}
}
</style>
</head>
<body>
<div class="page">

  <div class="hero">
    <div class="topbar">
      <div class="tag">AetherDesk AI · Trending Intelligence</div>
      <button class="btn" onclick="window.print()">Save as PDF</button>
    </div>

    <h1>$topicSafe</h1>
    <div class="subtitle">
      Professional AI trend dashboard with collected resources, open-source signals, AI-generated Markdown summary and PDF-ready layout.
    </div>

    <div class="hero-grid">
      <div class="hero-stat"><div class="label">Generated</div><div class="value" style="font-size:16px">$generatedAt</div></div>
      <div class="hero-stat"><div class="label">Total results</div><div class="value">$totalResults</div></div>
      <div class="hero-stat"><div class="label">Articles</div><div class="value">$articleCount</div></div>
      <div class="hero-stat"><div class="label">Videos/PDFs</div><div class="value">$($videoCount + $pdfCount)</div></div>
      <div class="hero-stat"><div class="label">GitHub</div><div class="value">$githubCount</div></div>
    </div>
  </div>

  <div class="section">
    <div class="section-title">
      <div class="title-left"><span></span><h2>Graphical Overview</h2></div>
    </div>

    <div class="grid-2">
      <div class="chart-card">
        <div class="bar-row">
          <div class="bar-head"><div class="bar-name">Articles</div><div class="bar-time">$articleCount</div></div>
          <div class="bar"><div class="fill" style="width:$articleWidth%"></div></div>
        </div>
        <div class="bar-row">
          <div class="bar-head"><div class="bar-name">Videos</div><div class="bar-time">$videoCount</div></div>
          <div class="bar"><div class="fill video" style="width:$videoWidth%"></div></div>
        </div>
        <div class="bar-row">
          <div class="bar-head"><div class="bar-name">PDF / Research</div><div class="bar-time">$pdfCount</div></div>
          <div class="bar"><div class="fill pdf" style="width:$pdfWidth%"></div></div>
        </div>
        <div class="bar-row">
          <div class="bar-head"><div class="bar-name">GitHub / Open Source</div><div class="bar-time">$githubCount</div></div>
          <div class="bar"><div class="fill github" style="width:$githubWidth%"></div></div>
        </div>
      </div>

      <div class="chart-card">
        <h3 style="margin-top:0;color:#0b3b2d;">Report Quality Notes</h3>
        <p style="color:#4b5f58;line-height:1.7">
          This report combines public search results with local AI analysis. GitHub links indicate open-source signal,
          PDF links indicate deeper research value, and video/article links provide quick learning material.
        </p>
      </div>
    </div>
  </div>

  <div class="section ai-box">
    <div class="ai-head">
      <div class="ai-icon">AI</div>
      <div>
        <div style="font-size:22px;font-weight:1000;color:#0b3b2d;">AI Trend Summary</div>
        <div class="ai-meta">Markdown rendered summary generated locally when Ollama is available.</div>
      </div>
    </div>

    <div class="ai-content">
      $aiHtml
    </div>
  </div>

  <div class="section">
    <div class="section-title">
      <div class="title-left"><span></span><h2>Top Resources</h2></div>
    </div>

    <div class="resource-grid">
      $cards
    </div>
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
    Write-Host "Professional trending report created:" -ForegroundColor Green
    Write-Host $htmlPath -ForegroundColor Yellow
    Write-Host ""

    Start-Process $htmlPath

    return $htmlPath
}
