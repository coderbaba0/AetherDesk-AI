# social-trends.ps1
# AetherDesk TrendRadar - public social trend signal collector

$Script:TrendRadarBaseDir = $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($Script:TrendRadarBaseDir)) {
    $Script:TrendRadarBaseDir = (Get-Location).Path
}

function ConvertTo-TrendRadarSafeText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    $clean = $Text -replace "<.*?>", ""
    $clean = $clean -replace "&nbsp;", " "
    $clean = $clean -replace "&amp;", "&"
    $clean = $clean -replace "&quot;", '"'
    $clean = $clean -replace "&#39;", "'"
    $clean = $clean -replace "\s+", " "
    return $clean.Trim()
}

function ConvertTo-TrendRadarSlug {
    param([string]$Text)

    $slug = ($Text.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')

    if ([string]::IsNullOrWhiteSpace($slug)) {
        return "social-trend"
    }

    return $slug
}

function Search-TrendRadarBingRss {
    param(
        [string]$Query,
        [string]$Platform,
        [string]$SignalType = "Web",
        [int]$Limit = 8
    )

    $encodedQuery = [uri]::EscapeDataString($Query)
    $url = "https://www.bing.com/search?q=$encodedQuery&format=rss"

    if ($SignalType -eq "News") {
        $url = "https://www.bing.com/news/search?q=$encodedQuery&format=rss"
    }

    $results = @()

    try {
        $web = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 25
        [xml]$rss = $web.Content

        foreach ($item in $rss.rss.channel.item) {
            $title = ConvertTo-TrendRadarSafeText ([string]$item.title)
            $link = [string]$item.link
            $description = ConvertTo-TrendRadarSafeText ([string]$item.description)
            $published = ConvertTo-TrendRadarSafeText ([string]$item.pubDate)

            if (-not [string]::IsNullOrWhiteSpace($title) -and -not [string]::IsNullOrWhiteSpace($link)) {
                $results += [PSCustomObject]@{
                    Platform = $Platform
                    Type = $SignalType
                    Title = $title
                    Link = $link
                    Description = $description
                    Published = $published
                    Query = $Query
                }
            }
        }
    }
    catch {
        Write-Host "Search failed for $Platform signal." -ForegroundColor Yellow
    }

    return @(
        $results |
            Sort-Object Link -Unique |
            Select-Object -First $Limit
    )
}

function Get-TrendRadarTopTerms {
    param(
        [array]$Results,
        [string]$Topic,
        [int]$Limit = 10
    )

    $stopWords = @(
        "the", "and", "for", "with", "from", "that", "this", "your", "you", "are", "was", "were",
        "how", "why", "what", "when", "where", "into", "about", "after", "before", "latest",
        "best", "new", "news", "video", "watch", "github", "reddit", "linkedin", "twitter", "youtube"
    )

    $topicWords = @($Topic.ToLowerInvariant() -split '[^a-z0-9]+' | Where-Object { $_.Length -gt 1 })
    $counts = @{}

    foreach ($r in $Results) {
        $text = "$($r.Title) $($r.Description)".ToLowerInvariant()
        $words = $text -split '[^a-z0-9]+'

        foreach ($word in $words) {
            if ($word.Length -lt 3) {
                continue
            }

            if ($stopWords -contains $word) {
                continue
            }

            if ($topicWords -contains $word) {
                continue
            }

            if (-not $counts.ContainsKey($word)) {
                $counts[$word] = 0
            }

            $counts[$word]++
        }
    }

    return @(
        $counts.GetEnumerator() |
            Sort-Object Value -Descending |
            Select-Object -First $Limit |
            ForEach-Object { $_.Key }
    )
}

function Get-TrendRadarPlatformScore {
    param([array]$Results)

    $count = 0
    if ($Results) {
        $count = $Results.Count
    }

    $score = [math]::Min(100, [math]::Round(($count * 12) + 8))
    return [int]$score
}

function Get-TrendRadarContentFormat {
    param([string]$BestPlatform)

    switch ($BestPlatform) {
        "YouTube" { return "Short tutorial, comparison video, or build-in-public demo" }
        "LinkedIn" { return "Practical carousel, founder insight, or professional case study" }
        "X/Twitter" { return "Short thread with strong hook, proof, and takeaway" }
        "Reddit" { return "Discussion post asking for opinions, pain points, and use cases" }
        "GitHub" { return "Open-source repository, demo README, or technical changelog" }
        "News" { return "Explainer article with market context and clear examples" }
        default { return "Search-focused article, tutorial, or trend explainer" }
    }
}

function New-TrendRadarIdeas {
    param(
        [string]$Topic,
        [array]$Keywords,
        [string]$BestPlatform
    )

    $primary = $Topic
    $keywordText = ""

    if ($Keywords -and $Keywords.Count -gt 0) {
        $keywordText = $Keywords[0]
    }
    else {
        $keywordText = "workflow"
    }

    $hashtags = @()
    $hashtags += "#" + (($Topic -replace '[^A-Za-z0-9]', '')).Trim()

    foreach ($k in @($Keywords | Select-Object -First 7)) {
        $tag = "#" + (($k -replace '[^A-Za-z0-9]', '')).Trim()
        if ($tag.Length -gt 1 -and $hashtags -notcontains $tag) {
            $hashtags += $tag
        }
    }

    return [PSCustomObject]@{
        Hashtags = @($hashtags | Select-Object -First 8)
        YouTubeTitles = @(
            "I tested $primary so you do not have to",
            "$primary explained with a real workflow",
            "Is $primary the next practical AI opportunity?",
            "${primary}: tools, examples, and mistakes to avoid"
        )
        LinkedInAngles = @(
            "What $primary means for builders and small teams",
            "A practical framework to evaluate $primary before adopting it",
            "The hidden behaviour shift behind $primary",
            "Why $keywordText is becoming important in the $primary conversation"
        )
        TwitterIdeas = @(
            "A short thread: what is actually changing around $primary",
            "Hot take: $primary matters less for hype and more for workflow design",
            "3 signals showing why $primary is worth watching",
            "Question for builders: where does $primary fit in your stack?"
        )
    }
}

function Get-TrendRadarPrediction {
    param(
        [int]$OverallScore,
        [string]$BestPlatform,
        [array]$Keywords
    )

    $keywordLine = "workflow, automation, and practical adoption"

    if ($Keywords -and $Keywords.Count -gt 0) {
        $keywordLine = (@($Keywords | Select-Object -First 3) -join ", ")
    }

    if ($OverallScore -ge 75) {
        return "High opportunity: the topic has broad platform coverage. Expect stronger engagement around $keywordLine, especially on $BestPlatform."
    }

    if ($OverallScore -ge 50) {
        return "Moderate opportunity: the topic has visible signals but needs a sharper angle. Use $BestPlatform first and test content around $keywordLine."
    }

    return "Early signal: the topic is searchable but not yet strongly distributed. Start with educational content and monitor whether $keywordLine keeps appearing."
}

function Get-TrendRadarSignals {
    param(
        [string]$Topic,
        [string]$BaseDir = $Script:TrendRadarBaseDir
    )

    if ([string]::IsNullOrWhiteSpace($Topic)) {
        throw "Topic is required."
    }

    if ([string]::IsNullOrWhiteSpace($BaseDir)) {
        $BaseDir = (Get-Location).Path
    }

    $platformQueries = @(
        [PSCustomObject]@{ Name = "YouTube"; Type = "Video"; Query = "$Topic site:youtube.com/watch" },
        [PSCustomObject]@{ Name = "X/Twitter"; Type = "Social"; Query = "$Topic site:x.com OR site:twitter.com" },
        [PSCustomObject]@{ Name = "LinkedIn"; Type = "Social"; Query = "$Topic site:linkedin.com/posts OR site:linkedin.com/pulse" },
        [PSCustomObject]@{ Name = "Reddit"; Type = "Community"; Query = "$Topic site:reddit.com/r" },
        [PSCustomObject]@{ Name = "GitHub"; Type = "Open Source"; Query = "$Topic site:github.com repository open source" },
        [PSCustomObject]@{ Name = "Google/Web"; Type = "Web"; Query = "$Topic latest trend guide analysis" },
        [PSCustomObject]@{ Name = "News"; Type = "News"; Query = "$Topic latest news trend" }
    )

    $platforms = @()
    $allResults = @()

    foreach ($platform in $platformQueries) {
        Write-Host "Collecting $($platform.Name) signal..." -ForegroundColor DarkGray

        $results = Search-TrendRadarBingRss `
            -Query $platform.Query `
            -Platform $platform.Name `
            -SignalType $platform.Type `
            -Limit 8

        $score = Get-TrendRadarPlatformScore -Results $results
        $terms = Get-TrendRadarTopTerms -Results $results -Topic $Topic -Limit 8

        $platforms += [PSCustomObject]@{
            Name = $platform.Name
            Type = $platform.Type
            Query = $platform.Query
            Score = $score
            ResultCount = @($results).Count
            Keywords = @($terms)
            Results = @($results)
        }

        $allResults += $results
    }

    $bestPlatform = "Google/Web"
    $best = $platforms | Sort-Object Score -Descending | Select-Object -First 1

    if ($best) {
        $bestPlatform = $best.Name
    }

    $coverage = @($platforms | Where-Object { $_.ResultCount -gt 0 }).Count
    $avgScore = 0

    if ($platforms.Count -gt 0) {
        $avgScore = [math]::Round((($platforms | Measure-Object Score -Average).Average), 0)
    }

    $overallScore = [int][math]::Min(100, [math]::Round(($avgScore * 0.75) + (($coverage / 7) * 25)))
    $keywords = Get-TrendRadarTopTerms -Results $allResults -Topic $Topic -Limit 12
    $ideas = New-TrendRadarIdeas -Topic $Topic -Keywords $keywords -BestPlatform $bestPlatform
    $prediction = Get-TrendRadarPrediction -OverallScore $overallScore -BestPlatform $bestPlatform -Keywords $keywords
    $format = Get-TrendRadarContentFormat -BestPlatform $bestPlatform
    $slug = ConvertTo-TrendRadarSlug $Topic
    $date = Get-Date -Format "yyyy-MM-dd"

    $raw = [PSCustomObject]@{
        Module = "AetherDesk TrendRadar"
        Purpose = "Social Trend Intelligence + Behaviour Prediction Report"
        Topic = $Topic
        Slug = $slug
        Date = $date
        GeneratedAt = (Get-Date).ToString("s")
        OverallTrendOpportunityScore = $overallScore
        BestPlatform = $bestPlatform
        BestContentFormat = $format
        SocialBehaviourPrediction = $prediction
        KeywordClusters = @($keywords)
        HashtagIdeas = @($ideas.Hashtags)
        YouTubeTitleIdeas = @($ideas.YouTubeTitles)
        LinkedInPostAngles = @($ideas.LinkedInAngles)
        TwitterPostIdeas = @($ideas.TwitterIdeas)
        RedditDiscussionSignal = (($platforms | Where-Object { $_.Name -eq "Reddit" } | Select-Object -First 1).Score)
        GitHubOpenSourceSignal = (($platforms | Where-Object { $_.Name -eq "GitHub" } | Select-Object -First 1).Score)
        RecommendedAction = "Start with $bestPlatform using a $format. Re-check signals weekly and turn top keywords into experiments."
        Platforms = @($platforms)
    }

    $dataRoot = Join-Path $BaseDir "social-data"
    $dataDir = Join-Path $dataRoot $date

    if (!(Test-Path $dataDir)) {
        New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
    }

    $rawPath = Join-Path $dataDir "$slug-social-raw.json"
    $raw | ConvertTo-Json -Depth 12 | Set-Content -Path $rawPath -Encoding UTF8

    return [PSCustomObject]@{
        RawPath = $rawPath
        Data = $raw
    }
}
