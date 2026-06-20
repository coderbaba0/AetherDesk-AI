# ollama.ps1
# Stable Ollama helper with magical loader animation

function Test-Ollama {
    try {
        $null = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 5
        return $true
    }
    catch {
        return $false
    }
}

function Invoke-Ollama {
    param(
        [string]$Prompt,
        [object]$Config
    )

    $modelName = $Config.model

    if ([string]::IsNullOrWhiteSpace($modelName)) {
        return @{
            Success = $false
            Model = ""
            Text = "Model config me blank hai."
        }
    }

    Write-Host ""
    Write-Host "Using model: $modelName" -ForegroundColor DarkGray
    Write-Host "AI report generate ho raha hai..." -ForegroundColor Yellow
    Write-Host ""

    $body = @{
        model = $modelName
        prompt = $Prompt
        stream = $false
        options = @{
            temperature = 0.3
            num_ctx = 3072
            num_predict = 700
        }
    } | ConvertTo-Json -Depth 10

    $job = Start-Job -ScriptBlock {
        param($jsonBody)

        try {
            $response = Invoke-RestMethod `
                -Uri "http://localhost:11434/api/generate" `
                -Method Post `
                -ContentType "application/json" `
                -Body $jsonBody `
                -TimeoutSec 900

            return @{
                Success = $true
                Response = $response.response
                Error = ""
            }
        }
        catch {
            return @{
                Success = $false
                Response = ""
                Error = $_.Exception.Message
            }
        }
    } -ArgumentList $body

    $frames = @(
        "✦ Gathering signals from the web",
        "✧ Reading top links",
        "✺ Thinking with local Gemma",
        "✹ Creating tech insight",
        "✷ Ranking useful resources",
        "✶ Building magazine report"
    )

    $spark = @("⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏")
    $seconds = 0
    $i = 0

    while ($job.State -eq "Running") {
        $seconds++
        $frame = $frames[$i % $frames.Count]
        $spin = $spark[$i % $spark.Count]

        Write-Host -NoNewline "`r$spin $frame... $seconds sec     " -ForegroundColor Cyan

        Start-Sleep -Seconds 1
        $i++
    }

    Write-Host ""
    Write-Host "✨ AI response received. Finalizing report..." -ForegroundColor Green
    Write-Host ""

    $result = Receive-Job $job
    Remove-Job $job -Force

    if ($result.Success -eq $true -and -not [string]::IsNullOrWhiteSpace($result.Response)) {
        Write-Host "----------------------------------------" -ForegroundColor DarkGray
        Write-Host $result.Response -ForegroundColor White
        Write-Host "----------------------------------------" -ForegroundColor DarkGray

        return @{
            Success = $true
            Model = $modelName
            Text = $result.Response
        }
    }

    Write-Host "Ollama error:" -ForegroundColor Red
    Write-Host $result.Error -ForegroundColor Red

    return @{
        Success = $false
        Model = $modelName
        Text = $result.Error
    }
}