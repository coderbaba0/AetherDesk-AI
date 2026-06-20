# run-agent.ps1

$ErrorActionPreference = "Continue"

$BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $BaseDir "config.json"
$LogsDir = Join-Path $BaseDir "logs"

if (!(Test-Path $LogsDir)) {
    New-Item -ItemType Directory -Path $LogsDir | Out-Null
}

$today = Get-Date -Format "yyyy-MM-dd"
$LogFile = Join-Path $LogsDir "$today.log"

function Write-AgentLog {
    param([string]$Message)

    $time = Get-Date -Format "HH:mm:ss"
    $line = "[$time] $Message"
    Add-Content -Path $LogFile -Value $line
}

function Stop-WithMessage {
    param([string]$Message)

    Write-Host $Message -ForegroundColor Red
    Write-AgentLog $Message
    exit
}

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host " TrendAI Local Agent Started" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

Write-AgentLog "Agent started."

if (!(Test-Path $ConfigPath)) {
    Stop-WithMessage "config.json not found."
}

. (Join-Path $BaseDir "ollama.ps1")
. (Join-Path $BaseDir "search.ps1")
. (Join-Path $BaseDir "report.ps1")

try {
    $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    Write-AgentLog "Config loaded."
}
catch {
    Stop-WithMessage "config.json read error."
}

if (-not (Test-Ollama)) {
    Stop-WithMessage "Ollama running nahi hai. Pehle run karo: ollama serve"
}

Write-Host "Ollama connected." -ForegroundColor Green
Write-Host "Primary model: $($Config.model)" -ForegroundColor Yellow
Write-Host ""

# Topic input logic
$topicsToRun = @()

if ($Config.askTopicOnRun -eq $true) {
    $defaultTopic = ""

    if ($Config.topics.Count -gt 0) {
        $defaultTopic = $Config.topics[0]
    }

    Write-Host "Default topic: $defaultTopic" -ForegroundColor DarkGray
    $inputTopic = Read-Host "Topic enter karo, ya default ke liye Enter dabao"

    if ([string]::IsNullOrWhiteSpace($inputTopic)) {
        $topicsToRun = @($defaultTopic)
    }
    else {
        $topicsToRun = @($inputTopic)
    }
}
else {
    $topicsToRun = $Config.topics
}

foreach ($topic in $topicsToRun) {
    if ([string]::IsNullOrWhiteSpace($topic)) {
        continue
    }

    Write-Host ""
    Write-Host "Topic: $topic" -ForegroundColor Cyan
    Write-AgentLog "Searching topic: $topic"

    $results = Get-TopicResults -Topic $topic -Config $Config

    if ($results.Count -eq 0) {
        Write-Host "No results found for topic: $topic" -ForegroundColor Yellow
        Write-AgentLog "No results found for topic: $topic"
        continue
    }

    Write-Host "Results found: $($results.Count)" -ForegroundColor Green
    Write-AgentLog "Results found: $($results.Count)"

    $prompt = New-AiPrompt -Topic $topic -Results $results -Config $Config

    Write-Host "Generating AI report..." -ForegroundColor DarkGray
    Write-AgentLog "Sending prompt to Ollama."

    $aiResponse = Invoke-Ollama -Prompt $prompt -Config $Config

    if ($aiResponse.Success -ne $true) {
        Write-Host "AI failed for topic: $topic" -ForegroundColor Red
        Write-AgentLog "AI failed for topic: $topic"
        continue
    }

    $reportPath = New-TrendReport `
        -Topic $topic `
        -Results $results `
        -AiText $aiResponse.Text `
        -UsedModel $aiResponse.Model `
        -Config $Config `
        -BaseDir $BaseDir

    Write-Host "Report created:" -ForegroundColor Green
    Write-Host $reportPath -ForegroundColor Yellow
    Write-AgentLog "Report created: $reportPath"
    Write-Host ""
}

Write-AgentLog "Agent completed."
Write-Host "Done." -ForegroundColor Green
Write-Host ""