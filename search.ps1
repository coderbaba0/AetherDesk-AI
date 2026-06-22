# search.ps1

function ConvertTo-SafeText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    $clean = $Text -replace "<.*?>", ""
    $clean = $clean -replace "&nbsp;", " "
    $clean = $clean -replace "&amp;", "&"
    $clean = $clean -replace "&quot;", '"'
    $clean = $clean -replace "&#39;", "'"
    return $clean.Trim()
}

function Search-BingRss {
    param(
        [string]$Query,
        [string]$Type
    )

    $encodedQuery = [uri]::EscapeDataString($Query)
    $url = "https://www.bing.com/search?q=$encodedQuery&format=rss"

    $results = @()

    try {
        $web = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 30
        [xml]$rss = $web.Content

        foreach ($item in $rss.rss.channel.item) {
            $title = ConvertTo-SafeText ([string]$item.title)
            $link = [string]$item.link
            $desc = ConvertTo-SafeText ([string]$item.description)

            if (-not [string]::IsNullOrWhiteSpace($title) -and -not [string]::IsNullOrWhiteSpace($link)) {
                $results += [PSCustomObject]@{
                    Type = $Type
                    Source = "Bing RSS"
                    Title = $title
                    Link = $link
                    Description = $desc
                }
            }
        }
    }
    catch {
        Write-Host "Search failed: $Query" -ForegroundColor Yellow
    }

    return $results
}

function Get-TopicResults {
    param(
        [string]$Topic,
        [object]$Config
    )

    $allResults = @()

    if ($Config.includeArticles -eq $true) {
        $allResults += Search-BingRss -Query "$Topic latest articles open source AI technology" -Type "Article"
    }

    if ($Config.includeVideos -eq $true) {
        $allResults += Search-BingRss -Query "$Topic site:youtube.com/watch" -Type "Video"
    }

    if ($Config.includePDFs -eq $true) {
        $allResults += Search-BingRss -Query "$Topic filetype:pdf AI research" -Type "PDF"
    }

    if ($Config.includeGithub -eq $true) {
        $allResults += Search-BingRss -Query "$Topic site:github.com open source repository" -Type "GitHub"
    }

    $uniqueResults = $allResults |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace($_.Title) -and
            -not [string]::IsNullOrWhiteSpace($_.Link)
        } |
        Sort-Object Link -Unique |
        Select-Object -First ([int]$Config.maxResults)

    return $uniqueResults
}
