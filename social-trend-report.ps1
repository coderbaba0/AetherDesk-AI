# social-trend-report.ps1
# AetherDesk TrendRadar - Social Intelligence HTML report generator

param(
    [string]$Topic
)

$ErrorActionPreference = "Continue"

$BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if ([string]::IsNullOrWhiteSpace($BaseDir)) {
    $BaseDir = (Get-Location).Path
}

. (Join-Path $BaseDir "social-trends.ps1")

function ConvertTo-TrendRadarHtmlSafe {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    return [System.Net.WebUtility]::HtmlEncode($Text)
}

function New-TrendRadarListHtml {
    param(
        [array]$Items,
        [string]$EmptyText = "No signal available."
    )

    if (-not $Items -or $Items.Count -eq 0) {
        return "<p class='muted'>$EmptyText</p>"
    }

    $html = "<ul>"

    foreach ($item in $Items) {
        $html += "<li>" + (ConvertTo-TrendRadarHtmlSafe ([string]$item)) + "</li>"
    }

    $html += "</ul>"
    return $html
}

function New-TrendRadarResourceHtml {
    param([array]$Platforms)

    $html = ""

    foreach ($platform in $Platforms) {
        $name = ConvertTo-TrendRadarHtmlSafe $platform.Name
        $items = ""

        foreach ($r in @($platform.Results | Select-Object -First 5)) {
            $title = ConvertTo-TrendRadarHtmlSafe $r.Title
            $link = ConvertTo-TrendRadarHtmlSafe $r.Link
            $desc = ConvertTo-TrendRadarHtmlSafe $r.Description

            if ([string]::IsNullOrWhiteSpace($desc)) {
                $desc = "No description available."
            }

            $items += @"
<article class="resource">
  <h4>$title</h4>
  <p>$desc</p>
  <a href="$link" target="_blank">Open signal</a>
</article>
"@
        }

        if ([string]::IsNullOrWhiteSpace($items)) {
            $items = "<p class='muted'>No public signal found for this platform.</p>"
        }

        $html += @"
<section class="platform-section">
  <div class="platform-heading">
    <h3>$name</h3>
    <span>$($platform.Score)/100</span>
  </div>
  $items
</section>
"@
    }

    return $html
}

function New-TrendRadarReport {
    param(
        [object]$TrendData,
        [string]$BaseDir
    )

    $reportsDir = Join-Path $BaseDir "reports"

    if (!(Test-Path $reportsDir)) {
        New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
    }

    $topicSafe = ConvertTo-TrendRadarHtmlSafe $TrendData.Topic
    $slug = $TrendData.Slug
    $date = $TrendData.Date
    $generatedAt = Get-Date -Format "dd MMM yyyy, hh:mm tt"
    $reportPath = Join-Path $reportsDir "$date-$slug-trendradar.html"

    $platformBars = ""

    foreach ($platform in $TrendData.Platforms) {
        $name = ConvertTo-TrendRadarHtmlSafe $platform.Name
        $score = [int]$platform.Score
        $count = [int]$platform.ResultCount
        $platformBars += @"
<div class="bar-row">
  <div class="bar-head">
    <span>$name</span>
    <strong>$score/100 · $count signals</strong>
  </div>
  <div class="bar"><div class="fill" style="width:$score%"></div></div>
</div>
"@
    }

    $keywordHtml = New-TrendRadarListHtml -Items $TrendData.KeywordClusters
    $hashtagHtml = New-TrendRadarListHtml -Items $TrendData.HashtagIdeas
    $youtubeHtml = New-TrendRadarListHtml -Items $TrendData.YouTubeTitleIdeas
    $linkedinHtml = New-TrendRadarListHtml -Items $TrendData.LinkedInPostAngles
    $twitterHtml = New-TrendRadarListHtml -Items $TrendData.TwitterPostIdeas
    $resourceHtml = New-TrendRadarResourceHtml -Platforms $TrendData.Platforms
    $predictionSafe = ConvertTo-TrendRadarHtmlSafe $TrendData.SocialBehaviourPrediction
    $formatSafe = ConvertTo-TrendRadarHtmlSafe $TrendData.BestContentFormat
    $bestPlatformSafe = ConvertTo-TrendRadarHtmlSafe $TrendData.BestPlatform
    $actionSafe = ConvertTo-TrendRadarHtmlSafe $TrendData.RecommendedAction

    $html = @"
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>$topicSafe - AetherDesk TrendRadar</title>
<style>
*{box-sizing:border-box}
:root{
  --bg:#f4f7fb;
  --ink:#152033;
  --muted:#657184;
  --card:#ffffff;
  --line:#dce4ef;
  --primary:#126b5c;
  --primary2:#29b391;
  --blue:#2563eb;
  --orange:#f59e0b;
  --shadow:0 18px 42px rgba(21,32,51,.10);
}
body{margin:0;background:var(--bg);color:var(--ink);font-family:"Segoe UI",Arial,sans-serif}
.page{padding:30px;min-height:100vh;background:linear-gradient(135deg,#f7fbff,#eef7f3)}
.hero{border-radius:26px;padding:34px;background:linear-gradient(135deg,#102238,#126b5c 65%,#29b391);color:#fff;box-shadow:var(--shadow)}
.topline{display:flex;justify-content:space-between;gap:16px;align-items:center;flex-wrap:wrap}
.tag{padding:8px 13px;border-radius:999px;background:rgba(255,255,255,.14);border:1px solid rgba(255,255,255,.24);font-size:12px;font-weight:800;letter-spacing:.5px;text-transform:uppercase}
.print{border:0;border-radius:12px;padding:10px 14px;font-weight:900;color:#126b5c;background:#fff;cursor:pointer}
h1{font-size:42px;line-height:1.08;margin:24px 0 10px}
.hero p{max-width:900px;line-height:1.6;opacity:.9}
.stats{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin-top:24px}
.stat{padding:16px;border-radius:18px;background:rgba(255,255,255,.12);border:1px solid rgba(255,255,255,.22)}
.stat span{display:block;font-size:12px;opacity:.78}
.stat strong{display:block;font-size:25px;margin-top:7px}
.section{margin-top:22px;background:var(--card);border:1px solid var(--line);border-radius:22px;padding:22px;box-shadow:var(--shadow)}
.section h2{margin:0 0 16px;font-size:24px}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:18px}
.card{border:1px solid var(--line);border-radius:18px;padding:18px;background:#fff}
.card h3{margin:0 0 10px}
.muted{color:var(--muted)}
.bar-row{margin-bottom:14px}
.bar-head{display:flex;justify-content:space-between;gap:12px;margin-bottom:7px;font-size:13px}
.bar{height:13px;border-radius:999px;background:#e7edf5;overflow:hidden}
.fill{height:100%;border-radius:999px;background:linear-gradient(90deg,var(--primary),var(--primary2))}
ul{margin:0;padding-left:20px}
li{margin:8px 0;line-height:1.45}
.platform-section{border:1px solid var(--line);border-radius:18px;padding:18px;margin-bottom:16px;background:#fff}
.platform-heading{display:flex;justify-content:space-between;gap:12px;align-items:center;margin-bottom:12px}
.platform-heading h3{margin:0}
.platform-heading span{font-weight:900;color:var(--primary)}
.resource{border-top:1px solid #edf1f6;padding:13px 0}
.resource:first-of-type{border-top:0}
.resource h4{margin:0 0 6px;font-size:15px}
.resource p{margin:0 0 8px;color:var(--muted);font-size:13px;line-height:1.45}
.resource a{font-weight:900;color:var(--blue);text-decoration:none}
.recommend{background:linear-gradient(135deg,#fff7ed,#ecfdf5);border-color:#fed7aa}
@media(max-width:900px){.page{padding:16px}.stats,.grid{grid-template-columns:1fr}h1{font-size:32px}}
@media print{.print{display:none}.page{padding:0}.section,.hero{box-shadow:none}}
</style>
</head>
<body>
<main class="page">
  <section class="hero">
    <div class="topline">
      <span class="tag">AetherDesk TrendRadar</span>
      <button class="print" onclick="window.print()">Save as PDF</button>
    </div>
    <h1>$topicSafe</h1>
    <p>Social Trend Intelligence + Behaviour Prediction Report generated from public search, RSS, web, community, video, news, and open-source signals.</p>
    <div class="stats">
      <div class="stat"><span>Opportunity Score</span><strong>$($TrendData.OverallTrendOpportunityScore)/100</strong></div>
      <div class="stat"><span>Best Platform</span><strong>$bestPlatformSafe</strong></div>
      <div class="stat"><span>Reddit Signal</span><strong>$($TrendData.RedditDiscussionSignal)/100</strong></div>
      <div class="stat"><span>GitHub Signal</span><strong>$($TrendData.GitHubOpenSourceSignal)/100</strong></div>
    </div>
  </section>

  <section class="section">
    <h2>Platform-wise Score</h2>
    $platformBars
  </section>

  <section class="section grid">
    <div class="card">
      <h3>Social Behaviour Prediction</h3>
      <p>$predictionSafe</p>
    </div>
    <div class="card">
      <h3>Best Content Format</h3>
      <p>$formatSafe</p>
    </div>
  </section>

  <section class="section grid">
    <div class="card">
      <h3>Keyword Clusters</h3>
      $keywordHtml
    </div>
    <div class="card">
      <h3>Hashtag Ideas</h3>
      $hashtagHtml
    </div>
  </section>

  <section class="section grid">
    <div class="card">
      <h3>YouTube Title Ideas</h3>
      $youtubeHtml
    </div>
    <div class="card">
      <h3>LinkedIn Post Angles</h3>
      $linkedinHtml
    </div>
  </section>

  <section class="section grid">
    <div class="card">
      <h3>X/Twitter Post Ideas</h3>
      $twitterHtml
    </div>
    <div class="card recommend">
      <h3>Recommended Action</h3>
      <p>$actionSafe</p>
    </div>
  </section>

  <section class="section">
    <h2>Public Signals</h2>
    $resourceHtml
  </section>

  <section class="section">
    <p class="muted">Generated at $generatedAt. Raw data is saved date-wise in <strong>social-data/</strong>.</p>
  </section>
</main>
</body>
</html>
"@

    Set-Content -Path $reportPath -Value $html -Encoding UTF8
    return $reportPath
}

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host " AetherDesk TrendRadar" -ForegroundColor Green
Write-Host " Social Trend Intelligence Report" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

if ([string]::IsNullOrWhiteSpace($Topic)) {
    $Topic = Read-Host "Please enter topic for social trend analysis"
}

if ([string]::IsNullOrWhiteSpace($Topic)) {
    Write-Host "Topic is required." -ForegroundColor Red
    exit 1
}

try {
    $result = Get-TrendRadarSignals -Topic $Topic -BaseDir $BaseDir
    $reportPath = New-TrendRadarReport -TrendData $result.Data -BaseDir $BaseDir

    Write-Host ""
    Write-Host "TrendRadar raw data saved:" -ForegroundColor Green
    Write-Host $result.RawPath -ForegroundColor Yellow
    Write-Host ""
    Write-Host "TrendRadar report created:" -ForegroundColor Green
    Write-Host $reportPath -ForegroundColor Yellow
    Write-Host ""
}
catch {
    Write-Host "TrendRadar failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
