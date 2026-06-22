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

if (Test-Path (Join-Path $BaseDir "ollama.ps1")) {
    . (Join-Path $BaseDir "ollama.ps1")
}

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

function Convert-TrendRadarMarkdownLiteToHtml {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return "<p>No Gemma summary available.</p>"
    }

    $html = ""
    $inList = $false

    foreach ($rawLine in ($Text -replace "`r`n", "`n" -split "`n")) {
        $line = $rawLine.Trim()

        if ([string]::IsNullOrWhiteSpace($line)) {
            if ($inList) {
                $html += "</ul>"
                $inList = $false
            }
            continue
        }

        $safe = ConvertTo-TrendRadarHtmlSafe $line
        $safe = [regex]::Replace($safe, '\*\*(.+?)\*\*', '<strong>$1</strong>')

        if ($safe -match '^#{1,3}\s+(.+)$') {
            if ($inList) {
                $html += "</ul>"
                $inList = $false
            }
            $html += "<h4>$($matches[1])</h4>"
        }
        elseif ($safe -match '^[-*]\s+(.+)$') {
            if (-not $inList) {
                $html += "<ul>"
                $inList = $true
            }
            $html += "<li>$($matches[1])</li>"
        }
        else {
            if ($inList) {
                $html += "</ul>"
                $inList = $false
            }
            $html += "<p>$safe</p>"
        }
    }

    if ($inList) {
        $html += "</ul>"
    }

    return $html
}

function New-TrendRadarAiPrompt {
    param([object]$TrendData)

    $platformLines = ""

    foreach ($platform in $TrendData.Platforms) {
        $platformLines += "- $($platform.Name): score $($platform.Score)/100, signals $($platform.ResultCount), keywords: $(@($platform.Keywords | Select-Object -First 5) -join ', ')`n"
    }

    $keywordLine = @($TrendData.KeywordClusters | Select-Object -First 10) -join ", "
    $relatedLine = @($TrendData.SuggestedRelatedTopics | Select-Object -First 10) -join ", "

    return @"
You are Gemma running locally inside AetherDesk AI.

Create a practical social trend intelligence summary for the topic "$($TrendData.Topic)".

Platform data:
$platformLines

Top keywords:
$keywordLine

Suggested related topics:
$relatedLine

Best platform detected: $($TrendData.BestPlatform)
Best content format: $($TrendData.BestContentFormat)

Write concise Markdown in this exact structure:

## Gemma Trend Summary
- 3 bullets explaining what the trend signal means.

## Platform Decision
- Tell which platform should be used first and why.
- Mention the second-best platform if useful.

## Behaviour Prediction
- Predict how users may react to content on this topic.

## Content Plan
- 3 practical content actions for the next 7 days.

## Related Topic Opportunities
- 5 topic ideas related to the main topic.

Rules:
- Use only the given platform data.
- Do not invent metrics.
- Platform score is the value before "/100"; signal count is separate. Never use signal count as a score.
- Be direct and useful.
"@
}

function Invoke-TrendRadarGemmaSummary {
    param(
        [object]$TrendData,
        [string]$BaseDir
    )

    $configPath = Join-Path $BaseDir "config.json"

    if (!(Test-Path $configPath)) {
        return [PSCustomObject]@{
            Success = $false
            Model = ""
            Text = "Gemma summary skipped because config.json was not found."
        }
    }

    if (-not (Get-Command Test-Ollama -ErrorAction SilentlyContinue) -or -not (Get-Command Invoke-Ollama -ErrorAction SilentlyContinue)) {
        return [PSCustomObject]@{
            Success = $false
            Model = ""
            Text = "Gemma summary skipped because ollama.ps1 was not available."
        }
    }

    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
    }
    catch {
        return [PSCustomObject]@{
            Success = $false
            Model = ""
            Text = "Gemma summary skipped because config.json could not be read."
        }
    }

    if (-not (Test-Ollama)) {
        return [PSCustomObject]@{
            Success = $false
            Model = $config.model
            Text = "Gemma summary skipped because Ollama is not running. Start Ollama with: ollama serve"
        }
    }

    $prompt = New-TrendRadarAiPrompt -TrendData $TrendData
    $result = Invoke-Ollama -Prompt $prompt -Config $config

    return [PSCustomObject]@{
        Success = $result.Success
        Model = $result.Model
        Text = $result.Text
    }
}

function New-TrendRadarLineChartHtml {
    param([array]$Platforms)

    $width = 760
    $height = 260
    $left = 54
    $right = 26
    $top = 24
    $bottom = 54
    $plotWidth = $width - $left - $right
    $plotHeight = $height - $top - $bottom
    $count = [math]::Max(1, $Platforms.Count)
    $step = if ($count -gt 1) { $plotWidth / ($count - 1) } else { 0 }
    $points = @()
    $labels = ""
    $dots = ""

    for ($i = 0; $i -lt $Platforms.Count; $i++) {
        $score = [int]$Platforms[$i].Score
        $x = [math]::Round($left + ($i * $step), 2)
        $y = [math]::Round($top + ($plotHeight - (($score / 100) * $plotHeight)), 2)
        $points += "$x,$y"
        $name = ConvertTo-TrendRadarHtmlSafe $Platforms[$i].Name
        $labels += "<text x='$x' y='$($height - 20)' text-anchor='middle' class='axis-label'>$name</text>"
        $dots += "<circle cx='$x' cy='$y' r='5' class='line-dot'></circle><text x='$x' y='$($y - 10)' text-anchor='middle' class='score-label'>$score</text>"
    }

    $pointString = $points -join " "

    return @"
<svg class="line-chart" viewBox="0 0 $width $height" role="img" aria-label="Platform trend line comparison">
  <line x1="$left" y1="$top" x2="$left" y2="$($top + $plotHeight)" class="grid-axis"></line>
  <line x1="$left" y1="$($top + $plotHeight)" x2="$($width - $right)" y2="$($top + $plotHeight)" class="grid-axis"></line>
  <line x1="$left" y1="$top" x2="$($width - $right)" y2="$top" class="grid-soft"></line>
  <line x1="$left" y1="$($top + ($plotHeight * .5))" x2="$($width - $right)" y2="$($top + ($plotHeight * .5))" class="grid-soft"></line>
  <text x="12" y="$($top + 5)" class="axis-label">100</text>
  <text x="20" y="$($top + ($plotHeight * .5) + 5)" class="axis-label">50</text>
  <text x="26" y="$($top + $plotHeight + 5)" class="axis-label">0</text>
  <polyline points="$pointString" class="trend-line"></polyline>
  $dots
  $labels
</svg>
"@
}

function New-TrendRadarComparisonTableHtml {
    param([array]$Platforms)

    $rows = ""
    $rank = 1

    foreach ($platform in @($Platforms | Sort-Object Score -Descending)) {
        $name = ConvertTo-TrendRadarHtmlSafe $platform.Name
        $type = ConvertTo-TrendRadarHtmlSafe $platform.Type
        $keywords = ConvertTo-TrendRadarHtmlSafe (@($platform.Keywords | Select-Object -First 5) -join ", ")
        $decision = "Test"

        if ($rank -eq 1) {
            $decision = "Use first"
        }
        elseif ($rank -eq 2) {
            $decision = "Use second"
        }

        $rows += @"
<tr>
  <td>$rank</td>
  <td><strong>$name</strong><span>$type</span></td>
  <td>$($platform.Score)/100</td>
  <td>$($platform.ResultCount)</td>
  <td>$keywords</td>
  <td>$decision</td>
</tr>
"@
        $rank++
    }

    return @"
<div class="table-wrap">
  <table>
    <thead>
      <tr>
        <th>Rank</th>
        <th>Platform</th>
        <th>Score</th>
        <th>Signals</th>
        <th>Top Keywords</th>
        <th>Decision</th>
      </tr>
    </thead>
    <tbody>
      $rows
    </tbody>
  </table>
</div>
"@
}

function New-TrendRadarRelatedTopicTableHtml {
    param(
        [array]$Topics,
        [string]$BestPlatform
    )

    if (-not $Topics -or $Topics.Count -eq 0) {
        return "<p class='muted'>No related topic suggestions available.</p>"
    }

    $rows = ""
    $rank = 1

    foreach ($topic in @($Topics | Select-Object -First 10)) {
        $safeTopic = ConvertTo-TrendRadarHtmlSafe ([string]$topic)
        $angle = "Educational post"

        if ($rank -le 3) {
            $angle = "High-priority content test"
        }
        elseif ($rank -le 6) {
            $angle = "Secondary keyword experiment"
        }

        $rows += @"
<tr>
  <td>$rank</td>
  <td><strong>$safeTopic</strong></td>
  <td>$BestPlatform</td>
  <td>$angle</td>
</tr>
"@
        $rank++
    }

    return @"
<div class="table-wrap">
  <table>
    <thead>
      <tr>
        <th>#</th>
        <th>Suggested Topic</th>
        <th>Best Platform</th>
        <th>Use Case</th>
      </tr>
    </thead>
    <tbody>
      $rows
    </tbody>
  </table>
</div>
"@
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

    $lineChartHtml = New-TrendRadarLineChartHtml -Platforms $TrendData.Platforms
    $comparisonTableHtml = New-TrendRadarComparisonTableHtml -Platforms $TrendData.Platforms
    $keywordHtml = New-TrendRadarListHtml -Items $TrendData.KeywordClusters
    $hashtagHtml = New-TrendRadarListHtml -Items $TrendData.HashtagIdeas
    $youtubeHtml = New-TrendRadarListHtml -Items $TrendData.YouTubeTitleIdeas
    $linkedinHtml = New-TrendRadarListHtml -Items $TrendData.LinkedInPostAngles
    $twitterHtml = New-TrendRadarListHtml -Items $TrendData.TwitterPostIdeas
    $relatedTopicHtml = New-TrendRadarRelatedTopicTableHtml -Topics $TrendData.SuggestedRelatedTopics -BestPlatform $TrendData.BestPlatform
    $resourceHtml = New-TrendRadarResourceHtml -Platforms $TrendData.Platforms
    $aiResult = Invoke-TrendRadarGemmaSummary -TrendData $TrendData -BaseDir $BaseDir
    $aiHtml = Convert-TrendRadarMarkdownLiteToHtml $aiResult.Text
    $aiStatus = "Local Gemma summary"

    if ($aiResult.Success -ne $true) {
        $aiStatus = "Gemma summary fallback"
    }

    if ([string]::IsNullOrWhiteSpace($aiResult.Model)) {
        $aiModel = "gemma3:1b"
    }
    else {
        $aiModel = ConvertTo-TrendRadarHtmlSafe $aiResult.Model
    }

    $TrendData | Add-Member -NotePropertyName GemmaSummary -NotePropertyValue $aiResult.Text -Force
    $TrendData | Add-Member -NotePropertyName GemmaModel -NotePropertyValue $aiResult.Model -Force
    $TrendData | Add-Member -NotePropertyName GemmaSummarySuccess -NotePropertyValue $aiResult.Success -Force

    $predictionSafe = ConvertTo-TrendRadarHtmlSafe $TrendData.SocialBehaviourPrediction
    $formatSafe = ConvertTo-TrendRadarHtmlSafe $TrendData.BestContentFormat
    $bestPlatformSafe = ConvertTo-TrendRadarHtmlSafe $TrendData.BestPlatform
    $actionSafe = ConvertTo-TrendRadarHtmlSafe $TrendData.RecommendedAction
    $aiStatusSafe = ConvertTo-TrendRadarHtmlSafe $aiStatus

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
.line-chart{width:100%;height:auto;display:block}
.grid-axis{stroke:#93a4b8;stroke-width:1.2}
.grid-soft{stroke:#dce4ef;stroke-width:1}
.trend-line{fill:none;stroke:#2563eb;stroke-width:4;stroke-linecap:round;stroke-linejoin:round}
.line-dot{fill:#fff;stroke:#2563eb;stroke-width:3}
.axis-label{font-size:11px;fill:#657184;font-weight:800}
.score-label{font-size:12px;fill:#152033;font-weight:900}
.table-wrap{overflow:auto;border:1px solid var(--line);border-radius:16px}
table{width:100%;border-collapse:collapse;background:#fff;min-width:820px}
th,td{text-align:left;padding:13px 14px;border-bottom:1px solid #edf1f6;vertical-align:top}
th{font-size:12px;text-transform:uppercase;letter-spacing:.5px;color:#657184;background:#f8fafc}
td span{display:block;color:#657184;font-size:12px;margin-top:3px}
.ai-summary{background:linear-gradient(135deg,#eef6ff,#ecfdf5);border-color:#bfdbfe}
.ai-meta{display:flex;gap:10px;flex-wrap:wrap;margin-bottom:12px}
.pill{display:inline-block;padding:7px 10px;border-radius:999px;background:#fff;border:1px solid var(--line);font-size:12px;font-weight:900;color:#126b5c}
.resource-grid{display:grid;grid-template-columns:repeat(2,1fr);gap:16px}
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
@media(max-width:900px){.page{padding:16px}.stats,.grid,.resource-grid{grid-template-columns:1fr}h1{font-size:32px}}
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
    <h2>Platform Comparison Dashboard</h2>
    <div class="grid">
      <div class="card">
        <h3>Bar Graph: Platform Strength</h3>
        $platformBars
      </div>
      <div class="card">
        <h3>Line Graph: Trend Momentum</h3>
        $lineChartHtml
      </div>
    </div>
  </section>

  <section class="section">
    <h2>Which Platform Is Best?</h2>
    $comparisonTableHtml
  </section>

  <section class="section ai-summary">
    <h2>Gemma Local AI Summary</h2>
    <div class="ai-meta">
      <span class="pill">$aiStatusSafe</span>
      <span class="pill">Model: $aiModel</span>
      <span class="pill">Ollama local mode</span>
    </div>
    <div class="ai-content">
      $aiHtml
    </div>
  </section>

  <section class="section">
    <h2>Public Signals and Results</h2>
    <p class="muted">These are the public signals used for the platform comparison. Review the links before publishing content.</p>
    <div class="resource-grid">
      $resourceHtml
    </div>
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
    <div class="card">
      <h3>Suggested Topic Table</h3>
      $relatedTopicHtml
    </div>
  </section>

  <section class="section">
    <div class="card recommend">
      <h3>Recommended Action</h3>
      <p>$actionSafe</p>
    </div>
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
    $result.Data | ConvertTo-Json -Depth 12 | Set-Content -Path $result.RawPath -Encoding UTF8

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
