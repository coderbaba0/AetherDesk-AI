# AetherDeskAI-UI.ps1
# WPF desktop control center for AetherDesk AI.

$ErrorActionPreference = "Continue"

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml

$Script:BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if ([string]::IsNullOrWhiteSpace($Script:BaseDir)) {
    $Script:BaseDir = (Get-Location).Path
}

$Script:PowerShellExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$Script:CurrentJob = $null
$Script:CurrentAction = ""
$Script:SpinnerIndex = 0
$Script:SpinnerFrames = @("|", "/", "-", "\")
$Script:BusyMessages = @(
    "Preparing local workflow",
    "Collecting public signals",
    "Checking local AI context",
    "Running AetherDesk module",
    "Building professional HTML report",
    "Finalizing dashboard"
)
$Script:BrushConverter = New-Object Windows.Media.BrushConverter

function Get-UiBrush {
    param([string]$Color)
    return $Script:BrushConverter.ConvertFromString($Color)
}

foreach ($folder in @("reports", "logs", "cache", "activity-data", "social-data")) {
    $path = Join-Path $Script:BaseDir $folder
    if (!(Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

function Get-ProjectPath {
    param([string]$RelativePath)
    return (Join-Path $Script:BaseDir $RelativePath)
}

function Get-ConfigPath {
    return (Get-ProjectPath "config.json")
}

function Get-UiConfig {
    $configPath = Get-ConfigPath

    if (!(Test-Path $configPath)) {
        return [PSCustomObject]@{
            appName = "AetherDesk AI"
            model = "gemma3:1b"
            fastModel = ""
            backupModel = ""
            topics = @("open source AI agents")
            maxResults = 10
            language = "Hinglish"
            includeArticles = $true
            includeVideos = $true
            includePDFs = $true
            includeGithub = $true
            outputFolder = "reports"
            askTopicOnRun = $true
        }
    }

    return Get-Content $configPath -Raw | ConvertFrom-Json
}

function Set-SettingsFields {
    param([object]$Config)

    $topicText = ""
    if ($Config.topics -and $Config.topics.Count -gt 0) {
        $topicText = ($Config.topics -join ", ")
    }

    $SettingsAppNameBox.Text = [string]$Config.appName
    $SettingsModelBox.Text = [string]$Config.model
    $SettingsFastModelBox.Text = [string]$Config.fastModel
    $SettingsBackupModelBox.Text = [string]$Config.backupModel
    $SettingsTopicsBox.Text = $topicText
    $SettingsMaxResultsBox.Text = [string]$Config.maxResults
    $SettingsLanguageBox.Text = [string]$Config.language
    $SettingsOutputFolderBox.Text = [string]$Config.outputFolder
    $SettingsAskTopicCheck.IsChecked = [bool]$Config.askTopicOnRun
    $SettingsArticlesCheck.IsChecked = [bool]$Config.includeArticles
    $SettingsVideosCheck.IsChecked = [bool]$Config.includeVideos
    $SettingsPdfsCheck.IsChecked = [bool]$Config.includePDFs
    $SettingsGithubCheck.IsChecked = [bool]$Config.includeGithub

    if (-not [string]::IsNullOrWhiteSpace($topicText)) {
        $TrendTopicBox.Text = ($Config.topics | Select-Object -First 1)
    }
}

function Load-Settings {
    try {
        $config = Get-UiConfig
        Set-SettingsFields -Config $config
        Add-Log "Settings loaded from config.json."
    }
    catch {
        Add-Log "Could not load config.json: $($_.Exception.Message)" "ERROR"
    }
}

function Save-Settings {
    try {
        $maxResults = 10
        if (-not [int]::TryParse($SettingsMaxResultsBox.Text.Trim(), [ref]$maxResults)) {
            $maxResults = 10
        }

        $topics = @(
            $SettingsTopicsBox.Text -split "," |
                ForEach-Object { $_.Trim() } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )

        if ($topics.Count -eq 0) {
            $topics = @("open source AI agents")
        }

        $config = [ordered]@{
            appName = $SettingsAppNameBox.Text.Trim()
            model = $SettingsModelBox.Text.Trim()
            fastModel = $SettingsFastModelBox.Text.Trim()
            backupModel = $SettingsBackupModelBox.Text.Trim()
            topics = @($topics)
            maxResults = $maxResults
            language = $SettingsLanguageBox.Text.Trim()
            includeArticles = [bool]$SettingsArticlesCheck.IsChecked
            includeVideos = [bool]$SettingsVideosCheck.IsChecked
            includePDFs = [bool]$SettingsPdfsCheck.IsChecked
            includeGithub = [bool]$SettingsGithubCheck.IsChecked
            outputFolder = $SettingsOutputFolderBox.Text.Trim()
            askTopicOnRun = [bool]$SettingsAskTopicCheck.IsChecked
        }

        if ([string]::IsNullOrWhiteSpace($config.appName)) {
            $config.appName = "AetherDesk AI"
        }

        if ([string]::IsNullOrWhiteSpace($config.model)) {
            $config.model = "gemma3:1b"
        }

        if ([string]::IsNullOrWhiteSpace($config.language)) {
            $config.language = "Hinglish"
        }

        if ([string]::IsNullOrWhiteSpace($config.outputFolder)) {
            $config.outputFolder = "reports"
        }

        $config | ConvertTo-Json -Depth 8 | Set-Content -Path (Get-ConfigPath) -Encoding UTF8
        $TrendTopicBox.Text = $topics[0]
        Add-Log "Settings saved to config.json."
        Set-UiBusy $false "Settings saved."
    }
    catch {
        Add-Log "Could not save settings: $($_.Exception.Message)" "ERROR"
    }
}

function Add-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $time = Get-Date -Format "HH:mm:ss"
    $Window.Dispatcher.Invoke([Action]{
        $OutputBox.AppendText("[$time] [$Level] $Message`r`n")
        $OutputBox.ScrollToEnd()
    })
}

function Set-UiBusy {
    param(
        [bool]$Busy,
        [string]$Message = ""
    )

    $Window.Dispatcher.Invoke([Action]{
        $ProgressBar.IsIndeterminate = $Busy
        $ProgressBar.Visibility = if ($Busy) { "Visible" } else { "Collapsed" }

        foreach ($button in $Script:ActionButtons) {
            $button.IsEnabled = -not $Busy
        }

        if ($Busy) {
            $StatusText.Text = $Message
            $StatusBadgeText.Text = "RUNNING"
            $StatusBadge.Background = Get-UiBrush "#FFF59E0B"
        }
        else {
            $StatusText.Text = if ([string]::IsNullOrWhiteSpace($Message)) { "Ready" } else { $Message }
            $StatusBadgeText.Text = "READY"
            $StatusBadge.Background = Get-UiBrush "#FF10B981"
        }
    })
}

function Get-LatestReport {
    $reportsDir = Get-ProjectPath "reports"

    if (!(Test-Path $reportsDir)) {
        return $null
    }

    return Get-ChildItem -Path $reportsDir -Filter "*.html" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

function Open-Path {
    param([string]$Path)

    if (Test-Path $Path) {
        Start-Process $Path
    }
    else {
        Add-Log "Path not found: $Path" "WARN"
    }
}

function Start-ModuleJob {
    param(
        [string]$Name,
        [string]$ScriptFile,
        [string[]]$Arguments = @()
    )

    if ($Script:CurrentJob -and $Script:CurrentJob.State -eq "Running") {
        Add-Log "Another module is already running." "WARN"
        return
    }

    $scriptPath = Get-ProjectPath $ScriptFile

    if (!(Test-Path $scriptPath)) {
        Add-Log "$ScriptFile not found." "ERROR"
        return
    }

    $Script:CurrentAction = $Name
    $Script:CurrentJob = Start-Job -ScriptBlock {
        param($PowerShellExe, $ScriptPath, $ArgsList, $WorkingDir)

        Set-Location $WorkingDir
        & $PowerShellExe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @ArgsList *>&1 |
            ForEach-Object { $_.ToString() }
    } -ArgumentList $Script:PowerShellExe, $scriptPath, $Arguments, $Script:BaseDir

    Add-Log "Started: $Name"
    Set-UiBusy $true "$Name is running..."
}

function Start-ScheduleJob {
    param(
        [string]$Name,
        [string]$Mode,
        [string]$TaskName,
        [string]$ScriptFile = "",
        [string]$Time = "",
        [string]$Day = "",
        [string]$WindowStyle = ""
    )

    if ($Script:CurrentJob -and $Script:CurrentJob.State -eq "Running") {
        Add-Log "Another task is already running." "WARN"
        return
    }

    $scriptPath = if ([string]::IsNullOrWhiteSpace($ScriptFile)) { "" } else { Get-ProjectPath $ScriptFile }
    $Script:CurrentAction = $Name
    $Script:CurrentJob = Start-Job -ScriptBlock {
        param($Mode, $TaskName, $ScriptPath, $Time, $Day, $WindowStyle)

        if ($Mode -eq "Delete") {
            schtasks /Delete /TN $TaskName /F
            return
        }

        $styleArg = ""
        if (-not [string]::IsNullOrWhiteSpace($WindowStyle)) {
            $styleArg = "-WindowStyle $WindowStyle "
        }

        $taskRun = "powershell.exe -NoProfile -ExecutionPolicy Bypass $styleArg-File `"$ScriptPath`""

        if ($Mode -eq "Daily") {
            schtasks /Create /TN $TaskName /SC DAILY /ST $Time /TR $taskRun /F
        }
        elseif ($Mode -eq "Weekly") {
            schtasks /Create /TN $TaskName /SC WEEKLY /D $Day /ST $Time /TR $taskRun /F
        }
        elseif ($Mode -eq "OnLogon") {
            schtasks /Create /TN $TaskName /SC ONLOGON /TR $taskRun /F
        }
    } -ArgumentList $Mode, $TaskName, $scriptPath, $Time, $Day, $WindowStyle

    Add-Log "Started: $Name"
    Set-UiBusy $true "$Name is running..."
}

function Start-ActivityTrackerWindow {
    $trackerPath = Get-ProjectPath "activity-tracker.ps1"

    if (!(Test-Path $trackerPath)) {
        Add-Log "activity-tracker.ps1 not found." "ERROR"
        return
    }

    Start-Process -FilePath $Script:PowerShellExe -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-NoExit",
        "-File", "`"$trackerPath`""
    )

    Add-Log "Activity Tracker started in a new terminal."
    Set-UiBusy $false "Activity Tracker opened in a new terminal."
}

function Test-UiOllama {
    try {
        $null = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 5
        return $true
    }
    catch {
        return $false
    }
}

function Update-OllamaCard {
    $ok = Test-UiOllama

    if ($ok) {
        $OllamaState.Text = "Ollama running"
        $OllamaState.Foreground = Get-UiBrush "#FF10B981"
        Add-Log "Ollama server is running."
    }
    else {
        $OllamaState.Text = "Ollama offline"
        $OllamaState.Foreground = Get-UiBrush "#FFF59E0B"
        Add-Log "Ollama is not running. AI summaries may use fallback mode." "WARN"
    }
}

function Get-ReportCount {
    param([string[]]$Patterns)

    $reportsDir = Get-ProjectPath "reports"

    if (!(Test-Path $reportsDir)) {
        return 0
    }

    $items = @()
    foreach ($pattern in $Patterns) {
        $items += Get-ChildItem -Path $reportsDir -Filter $pattern -File -ErrorAction SilentlyContinue
    }

    return @($items | Sort-Object FullName -Unique).Count
}

function Test-ScheduledTaskExists {
    param([string]$TaskName)

    try {
        $null = schtasks /Query /TN $TaskName 2>$null
        return ($LASTEXITCODE -eq 0)
    }
    catch {
        return $false
    }
}

function Get-SocialRawCount {
    $socialDir = Get-ProjectPath "social-data"

    if (!(Test-Path $socialDir)) {
        return 0
    }

    return @(Get-ChildItem -Path $socialDir -Filter "*-social-raw.json" -File -Recurse -ErrorAction SilentlyContinue).Count
}

function Update-DashboardStats {
    $trendReports = Get-ReportCount @("*trending-ai-dashboard.html", "*trend-report*.html")
    $healthReports = Get-ReportCount @("*system-health*.html", "*health*.html")
    $activityReports = Get-ReportCount @("*productivity*.html", "*activity*.html")
    $trendRadarReports = Get-ReportCount @("*trendradar.html")
    $socialRawCount = Get-SocialRawCount

    $trendTask = Test-ScheduledTaskExists "AetherDesk Daily Trending Report"
    $healthTask = Test-ScheduledTaskExists "AetherDesk Daily System Health"
    $activityTask = Test-ScheduledTaskExists "AetherDesk Activity Tracker"
    $productivityTask = Test-ScheduledTaskExists "AetherDesk Weekly Productivity Report"
    $activityTaskCount = @(($activityTask, $productivityTask) | Where-Object { $_ -eq $true }).Count

    $activeTasks = @(($trendTask, $healthTask, $activityTask, $productivityTask) | Where-Object { $_ -eq $true }).Count

    $TrendStatsText.Text = "Reports: $trendReports  |  Schedule: $(if ($trendTask) { 'Active' } else { 'Off' })"
    $HealthStatsText.Text = "Reports: $healthReports  |  Schedule: $(if ($healthTask) { 'Active' } else { 'Off' })"
    $ActivityStatsText.Text = "Dashboards: $activityReports  |  Tasks: $activityTaskCount/2"
    $TrendRadarStatsText.Text = "Reports: $trendRadarReports  |  Raw data: $socialRawCount"
    $SchedulerStatsText.Text = "$activeTasks of 4 scheduled tasks active"

    Add-Log "Dashboard metrics refreshed."
}

$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="AetherDesk AI Control Center"
        Height="780"
        Width="1180"
        MinHeight="720"
        MinWidth="1060"
        WindowStartupLocation="CenterScreen"
        Background="#F3F7FB"
        FontFamily="Segoe UI">
    <Window.Resources>
        <Style x:Key="PrimaryButton" TargetType="Button">
            <Setter Property="Height" Value="42"/>
            <Setter Property="MinWidth" Value="132"/>
            <Setter Property="Padding" Value="14,8"/>
            <Setter Property="Margin" Value="0,6,8,0"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="HorizontalContentAlignment" Value="Center"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Background" Value="#2563EB"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="11">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource PrimaryButton}">
            <Setter Property="Background" Value="#0F766E"/>
        </Style>
        <Style x:Key="GhostButton" TargetType="Button" BasedOn="{StaticResource PrimaryButton}">
            <Setter Property="Background" Value="#E8EEF8"/>
            <Setter Property="Foreground" Value="#152033"/>
        </Style>
    </Window.Resources>
    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="290"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <Border Grid.Column="0" Background="#101827">
            <DockPanel Margin="22">
                <StackPanel DockPanel.Dock="Top">
                    <Border Background="#1D2A3D" CornerRadius="18" Padding="18" Margin="0,0,0,18">
                        <StackPanel>
                            <TextBlock Text="AetherDesk AI" Foreground="White" FontSize="28" FontWeight="Bold"/>
                            <TextBlock Text="Local AI command center" Foreground="#A7B2C4" Margin="0,5,0,0"/>
                            <TextBlock Text="flutterfever.com" Foreground="#6EE7B7" Margin="0,14,0,0" FontWeight="SemiBold"/>
                        </StackPanel>
                    </Border>

                    <Border Background="#172235" CornerRadius="16" Padding="15" Margin="0,0,0,14">
                        <StackPanel>
                            <TextBlock Text="LOCAL AI STATUS" Foreground="#A7B2C4" FontSize="11" FontWeight="Bold"/>
                            <TextBlock x:Name="OllamaState" Text="Checking..." Foreground="#F59E0B" FontSize="18" FontWeight="Bold" Margin="0,8,0,0"/>
                            <Button x:Name="BtnCheckOllama" Style="{StaticResource GhostButton}" Content="Check Ollama" Margin="0,14,0,0"/>
                        </StackPanel>
                    </Border>

                    <Border Background="#172235" CornerRadius="16" Padding="15">
                        <StackPanel>
                            <TextBlock Text="QUICK ACTIONS" Foreground="#A7B2C4" FontSize="11" FontWeight="Bold"/>
                            <Button x:Name="BtnOpenLatest" Style="{StaticResource GhostButton}" Content="Open Latest Report" Margin="0,14,0,0"/>
                            <Button x:Name="BtnOpenReports" Style="{StaticResource GhostButton}" Content="Open Reports Folder" Margin="0,8,0,0"/>
                            <Button x:Name="BtnOpenData" Style="{StaticResource GhostButton}" Content="Open Social Data" Margin="0,8,0,0"/>
                        </StackPanel>
                    </Border>
                </StackPanel>

                <StackPanel DockPanel.Dock="Bottom">
                    <TextBlock Text="Status" Foreground="#A7B2C4" FontSize="12" FontWeight="Bold"/>
                    <Border x:Name="StatusBadge" Background="#10B981" CornerRadius="999" Padding="10,5" HorizontalAlignment="Left" Margin="0,8,0,8">
                        <TextBlock x:Name="StatusBadgeText" Text="READY" Foreground="White" FontSize="11" FontWeight="Bold"/>
                    </Border>
                    <TextBlock x:Name="StatusText" Text="Ready" Foreground="White" TextWrapping="Wrap"/>
                </StackPanel>
            </DockPanel>
        </Border>

        <Grid Grid.Column="1" Margin="24">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="210"/>
            </Grid.RowDefinitions>

            <Border Grid.Row="0" CornerRadius="24" Padding="26" Margin="0,0,0,18">
                <Border.Background>
                    <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                        <GradientStop Color="#102238" Offset="0"/>
                        <GradientStop Color="#126B5C" Offset="0.62"/>
                        <GradientStop Color="#29B391" Offset="1"/>
                    </LinearGradientBrush>
                </Border.Background>
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="260"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel>
                        <TextBlock Text="AI Dashboard Launcher" Foreground="White" FontSize="34" FontWeight="Bold"/>
                        <TextBlock Text="Run reports, watch progress, manage schedules, and open generated dashboards from one Windows UI." Foreground="#D8FFF4" FontSize="15" Margin="0,8,0,0" TextWrapping="Wrap"/>
                    </StackPanel>
                    <StackPanel Grid.Column="1" VerticalAlignment="Center">
                        <TextBlock Text="TrendRadar Topic" Foreground="#D8FFF4" FontSize="12" FontWeight="Bold"/>
                        <TextBox x:Name="TrendTopicBox" Text="local ai agent" Height="38" Margin="0,8,0,0" Padding="10,8" BorderThickness="0"/>
                    </StackPanel>
                </Grid>
            </Border>

            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                <StackPanel>
                    <UniformGrid Columns="2" Rows="2">
                        <Border Background="White" CornerRadius="18" Padding="18" Margin="0,0,12,12">
                            <StackPanel>
                                <TextBlock Text="AI" Foreground="#2563EB" FontSize="13" FontWeight="Bold"/>
                                <TextBlock Text="Trending AI Report" FontSize="21" FontWeight="Bold" Margin="0,4,0,0"/>
                                <TextBlock Text="Search public AI/open-source signals and generate local Gemma report." Foreground="#657184" TextWrapping="Wrap" Margin="0,6,0,12"/>
                                <Border Background="#EFF6FF" CornerRadius="999" Padding="10,5" HorizontalAlignment="Left" Margin="0,0,0,8">
                                    <TextBlock x:Name="TrendStatsText" Text="Reports: 0  |  Schedule: Off" Foreground="#1D4ED8" FontSize="12" FontWeight="SemiBold"/>
                                </Border>
                                <Button x:Name="BtnTrend" Style="{StaticResource PrimaryButton}" Content="Run Trending Report"/>
                            </StackPanel>
                        </Border>

                        <Border Background="White" CornerRadius="18" Padding="18" Margin="0,0,0,12">
                            <StackPanel>
                                <TextBlock Text="SYS" Foreground="#0F766E" FontSize="13" FontWeight="Bold"/>
                                <TextBlock Text="System Health AI" FontSize="21" FontWeight="Bold" Margin="0,4,0,0"/>
                                <TextBlock Text="Generate CPU, RAM, disk, network, battery, and process health dashboard." Foreground="#657184" TextWrapping="Wrap" Margin="0,6,0,12"/>
                                <Border Background="#ECFDF5" CornerRadius="999" Padding="10,5" HorizontalAlignment="Left" Margin="0,0,0,8">
                                    <TextBlock x:Name="HealthStatsText" Text="Reports: 0  |  Schedule: Off" Foreground="#047857" FontSize="12" FontWeight="SemiBold"/>
                                </Border>
                                <Button x:Name="BtnHealth" Style="{StaticResource SecondaryButton}" Content="Run Health Report"/>
                            </StackPanel>
                        </Border>

                        <Border Background="White" CornerRadius="18" Padding="18" Margin="0,0,12,12">
                            <StackPanel>
                                <TextBlock Text="ACT" Foreground="#7C3AED" FontSize="13" FontWeight="Bold"/>
                                <TextBlock Text="Activity Productivity" FontSize="21" FontWeight="Bold" Margin="0,4,0,0"/>
                                <TextBlock Text="Start tracker in a terminal or build a productivity dashboard from saved activity." Foreground="#657184" TextWrapping="Wrap" Margin="0,6,0,12"/>
                                <Border Background="#F5F3FF" CornerRadius="999" Padding="10,5" HorizontalAlignment="Left" Margin="0,0,0,10">
                                    <TextBlock x:Name="ActivityStatsText" Text="Dashboards: 0  |  Tracker: Manual" Foreground="#6D28D9" FontSize="12" FontWeight="SemiBold"/>
                                </Border>
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="150"/>
                                        <ColumnDefinition Width="150"/>
                                    </Grid.ColumnDefinitions>
                                    <Button Grid.Column="0" x:Name="BtnTracker" Style="{StaticResource PrimaryButton}" Background="#7C3AED" Content="Start Tracker" Margin="0,0,10,0"/>
                                    <Button Grid.Column="1" x:Name="BtnProductivity" Style="{StaticResource GhostButton}" Content="Build Dashboard" Margin="0"/>
                                </Grid>
                            </StackPanel>
                        </Border>

                        <Border Background="White" CornerRadius="18" Padding="18" Margin="0,0,0,12">
                            <StackPanel>
                                <TextBlock Text="TR" Foreground="#F59E0B" FontSize="13" FontWeight="Bold"/>
                                <TextBlock Text="TrendRadar Social AI" FontSize="21" FontWeight="Bold" Margin="0,4,0,0"/>
                                <TextBlock Text="Compare YouTube, X, LinkedIn, Reddit, GitHub, Web, and News with Gemma summary." Foreground="#657184" TextWrapping="Wrap" Margin="0,6,0,12"/>
                                <Border Background="#FFF7ED" CornerRadius="999" Padding="10,5" HorizontalAlignment="Left" Margin="0,0,0,8">
                                    <TextBlock x:Name="TrendRadarStatsText" Text="Reports: 0  |  Raw data: 0" Foreground="#C2410C" FontSize="12" FontWeight="SemiBold"/>
                                </Border>
                                <Button x:Name="BtnTrendRadar" Style="{StaticResource PrimaryButton}" Background="#F59E0B" Content="Run TrendRadar"/>
                            </StackPanel>
                        </Border>
                    </UniformGrid>

                    <Border Background="White" CornerRadius="18" Padding="18" Margin="0,6,0,14">
                        <StackPanel>
                            <DockPanel Margin="0,0,0,12">
                                <StackPanel DockPanel.Dock="Left">
                                    <TextBlock Text="Settings Center" FontSize="22" FontWeight="Bold"/>
                                    <TextBlock Text="Edit config.json from the UI without opening the file manually." Foreground="#657184" Margin="0,5,0,0"/>
                                </StackPanel>
                                <WrapPanel DockPanel.Dock="Right" HorizontalAlignment="Right">
                                    <Button x:Name="BtnReloadSettings" Style="{StaticResource GhostButton}" Content="Reload"/>
                                    <Button x:Name="BtnSaveSettings" Style="{StaticResource SecondaryButton}" Content="Save Settings"/>
                                </WrapPanel>
                            </DockPanel>

                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>

                                <StackPanel Grid.Column="0" Margin="0,0,14,0">
                                    <TextBlock Text="App Name"/>
                                    <TextBox x:Name="SettingsAppNameBox" Height="34" Padding="8"/>
                                    <TextBlock Text="Model" Margin="0,8,0,0"/>
                                    <TextBox x:Name="SettingsModelBox" Height="34" Padding="8"/>
                                    <TextBlock Text="Language" Margin="0,8,0,0"/>
                                    <TextBox x:Name="SettingsLanguageBox" Height="34" Padding="8"/>
                                </StackPanel>

                                <StackPanel Grid.Column="1" Margin="0,0,14,0">
                                    <TextBlock Text="Topics (comma separated)"/>
                                    <TextBox x:Name="SettingsTopicsBox" Height="34" Padding="8"/>
                                    <TextBlock Text="Max Results" Margin="0,8,0,0"/>
                                    <TextBox x:Name="SettingsMaxResultsBox" Height="34" Padding="8"/>
                                    <TextBlock Text="Output Folder" Margin="0,8,0,0"/>
                                    <TextBox x:Name="SettingsOutputFolderBox" Height="34" Padding="8"/>
                                </StackPanel>

                                <StackPanel Grid.Column="2">
                                    <TextBlock Text="Optional Models"/>
                                    <TextBox x:Name="SettingsFastModelBox" Height="34" Padding="8" ToolTip="Optional fast model"/>
                                    <TextBox x:Name="SettingsBackupModelBox" Height="34" Padding="8" Margin="0,8,0,0" ToolTip="Optional backup model"/>
                                    <WrapPanel Margin="0,10,0,0">
                                        <CheckBox x:Name="SettingsArticlesCheck" Content="Articles" Margin="0,4,12,4"/>
                                        <CheckBox x:Name="SettingsVideosCheck" Content="Videos" Margin="0,4,12,4"/>
                                        <CheckBox x:Name="SettingsPdfsCheck" Content="PDFs" Margin="0,4,12,4"/>
                                        <CheckBox x:Name="SettingsGithubCheck" Content="GitHub" Margin="0,4,12,4"/>
                                        <CheckBox x:Name="SettingsAskTopicCheck" Content="Ask topic on run" Margin="0,4,12,4"/>
                                    </WrapPanel>
                                </StackPanel>
                            </Grid>
                        </StackPanel>
                    </Border>

                    <Border Background="White" CornerRadius="18" Padding="18" Margin="0,6,0,14">
                        <StackPanel>
                            <TextBlock Text="Scheduler Center" FontSize="22" FontWeight="Bold"/>
                            <TextBlock Text="Create Windows scheduled tasks for recurring reports and background tracking." Foreground="#657184" Margin="0,5,0,12"/>
                            <Border Background="#F8FAFC" CornerRadius="999" Padding="10,5" HorizontalAlignment="Left" Margin="0,0,0,12">
                                <TextBlock x:Name="SchedulerStatsText" Text="0 of 4 scheduled tasks active" Foreground="#334155" FontSize="12" FontWeight="SemiBold"/>
                            </Border>
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" Margin="0,0,14,0">
                                    <TextBlock Text="Daily Trending Time"/>
                                    <TextBox x:Name="TrendTimeBox" Text="09:00" Height="34" Padding="8"/>
                                    <Button x:Name="BtnScheduleTrend" Style="{StaticResource GhostButton}" Content="Schedule Trend"/>
                                </StackPanel>
                                <StackPanel Grid.Column="1" Margin="0,0,14,0">
                                    <TextBlock Text="Daily Health Time"/>
                                    <TextBox x:Name="HealthTimeBox" Text="10:00" Height="34" Padding="8"/>
                                    <Button x:Name="BtnScheduleHealth" Style="{StaticResource GhostButton}" Content="Schedule Health"/>
                                </StackPanel>
                                <StackPanel Grid.Column="2">
                                    <TextBlock Text="Weekly Productivity Time"/>
                                    <TextBox x:Name="ProductivityTimeBox" Text="20:00" Height="34" Padding="8"/>
                                    <UniformGrid Columns="3" Margin="0,6,0,0">
                                        <Button x:Name="BtnScheduleProductivity" Style="{StaticResource GhostButton}" Content="Weekly Report" MinWidth="0" Margin="0,0,8,0"/>
                                        <Button x:Name="BtnScheduleTracker" Style="{StaticResource GhostButton}" Content="Tracker Login" MinWidth="0" Margin="0,0,8,0"/>
                                        <Button x:Name="BtnRemoveTrackerSchedule" Style="{StaticResource GhostButton}" Content="Remove Tracker" MinWidth="0" Margin="0"/>
                                    </UniformGrid>
                                </StackPanel>
                            </Grid>
                        </StackPanel>
                    </Border>
                </StackPanel>
            </ScrollViewer>

            <Border Grid.Row="2" Background="#0B1220" CornerRadius="18" Padding="14">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <DockPanel Grid.Row="0" Margin="0,0,0,10">
                        <TextBlock Text="Live Output" Foreground="White" FontWeight="Bold" FontSize="16" DockPanel.Dock="Left"/>
                        <ProgressBar x:Name="ProgressBar" DockPanel.Dock="Right" Width="220" Height="8" Visibility="Collapsed" IsIndeterminate="True"/>
                    </DockPanel>
                    <TextBox x:Name="OutputBox" Grid.Row="1" Background="#070B14" Foreground="#D6E4FF" BorderThickness="0" FontFamily="Consolas" FontSize="12" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>
                </Grid>
            </Border>
        </Grid>
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$Window = [Windows.Markup.XamlReader]::Load($reader)

$BtnTrend = $Window.FindName("BtnTrend")
$BtnHealth = $Window.FindName("BtnHealth")
$BtnTracker = $Window.FindName("BtnTracker")
$BtnProductivity = $Window.FindName("BtnProductivity")
$BtnTrendRadar = $Window.FindName("BtnTrendRadar")
$BtnCheckOllama = $Window.FindName("BtnCheckOllama")
$BtnOpenLatest = $Window.FindName("BtnOpenLatest")
$BtnOpenReports = $Window.FindName("BtnOpenReports")
$BtnOpenData = $Window.FindName("BtnOpenData")
$BtnScheduleTrend = $Window.FindName("BtnScheduleTrend")
$BtnScheduleHealth = $Window.FindName("BtnScheduleHealth")
$BtnScheduleProductivity = $Window.FindName("BtnScheduleProductivity")
$BtnScheduleTracker = $Window.FindName("BtnScheduleTracker")
$BtnRemoveTrackerSchedule = $Window.FindName("BtnRemoveTrackerSchedule")
$BtnReloadSettings = $Window.FindName("BtnReloadSettings")
$BtnSaveSettings = $Window.FindName("BtnSaveSettings")
$TrendTopicBox = $Window.FindName("TrendTopicBox")
$TrendTimeBox = $Window.FindName("TrendTimeBox")
$HealthTimeBox = $Window.FindName("HealthTimeBox")
$ProductivityTimeBox = $Window.FindName("ProductivityTimeBox")
$SettingsAppNameBox = $Window.FindName("SettingsAppNameBox")
$SettingsModelBox = $Window.FindName("SettingsModelBox")
$SettingsFastModelBox = $Window.FindName("SettingsFastModelBox")
$SettingsBackupModelBox = $Window.FindName("SettingsBackupModelBox")
$SettingsTopicsBox = $Window.FindName("SettingsTopicsBox")
$SettingsMaxResultsBox = $Window.FindName("SettingsMaxResultsBox")
$SettingsLanguageBox = $Window.FindName("SettingsLanguageBox")
$SettingsOutputFolderBox = $Window.FindName("SettingsOutputFolderBox")
$SettingsAskTopicCheck = $Window.FindName("SettingsAskTopicCheck")
$SettingsArticlesCheck = $Window.FindName("SettingsArticlesCheck")
$SettingsVideosCheck = $Window.FindName("SettingsVideosCheck")
$SettingsPdfsCheck = $Window.FindName("SettingsPdfsCheck")
$SettingsGithubCheck = $Window.FindName("SettingsGithubCheck")
$TrendStatsText = $Window.FindName("TrendStatsText")
$HealthStatsText = $Window.FindName("HealthStatsText")
$ActivityStatsText = $Window.FindName("ActivityStatsText")
$TrendRadarStatsText = $Window.FindName("TrendRadarStatsText")
$SchedulerStatsText = $Window.FindName("SchedulerStatsText")
$OutputBox = $Window.FindName("OutputBox")
$ProgressBar = $Window.FindName("ProgressBar")
$StatusText = $Window.FindName("StatusText")
$StatusBadge = $Window.FindName("StatusBadge")
$StatusBadgeText = $Window.FindName("StatusBadgeText")
$OllamaState = $Window.FindName("OllamaState")

$Script:ActionButtons = @(
    $BtnTrend,
    $BtnHealth,
    $BtnProductivity,
    $BtnTrendRadar,
    $BtnScheduleTrend,
    $BtnScheduleHealth,
    $BtnScheduleProductivity,
    $BtnScheduleTracker,
    $BtnRemoveTrackerSchedule,
    $BtnSaveSettings,
    $BtnReloadSettings
)

$BtnTrend.Add_Click({
    $topic = $TrendTopicBox.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($topic)) {
        $topic = "open source AI agents"
    }

    Start-ModuleJob -Name "Trending AI Report" -ScriptFile "run-agent.ps1" -Arguments @("-Topic", $topic)
})

$BtnHealth.Add_Click({
    Start-ModuleJob -Name "System Health Report" -ScriptFile "run-health-ai.ps1"
})

$BtnTracker.Add_Click({
    Start-ActivityTrackerWindow
})

$BtnProductivity.Add_Click({
    Start-ModuleJob -Name "Productivity Dashboard" -ScriptFile "activity-report.ps1"
})

$BtnTrendRadar.Add_Click({
    $topic = $TrendTopicBox.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($topic)) {
        Add-Log "Enter a TrendRadar topic first." "WARN"
        return
    }

    Start-ModuleJob -Name "TrendRadar Social Intelligence" -ScriptFile "social-trend-report.ps1" -Arguments @("-Topic", $topic)
})

$BtnCheckOllama.Add_Click({
    Update-OllamaCard
})

$BtnReloadSettings.Add_Click({
    Load-Settings
})

$BtnSaveSettings.Add_Click({
    Save-Settings
})

$BtnOpenLatest.Add_Click({
    $latest = Get-LatestReport

    if ($latest) {
        Add-Log "Opening latest report: $($latest.Name)"
        Open-Path $latest.FullName
    }
    else {
        Add-Log "No HTML reports found yet." "WARN"
    }
})

$BtnOpenReports.Add_Click({
    Open-Path (Get-ProjectPath "reports")
})

$BtnOpenData.Add_Click({
    Open-Path (Get-ProjectPath "social-data")
})

$BtnScheduleTrend.Add_Click({
    $time = $TrendTimeBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($time)) { $time = "09:00" }
    Start-ScheduleJob -Name "Schedule Daily Trending Report" -Mode "Daily" -TaskName "AetherDesk Daily Trending Report" -ScriptFile "run-agent.ps1" -Time $time
})

$BtnScheduleHealth.Add_Click({
    $time = $HealthTimeBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($time)) { $time = "10:00" }
    Start-ScheduleJob -Name "Schedule Daily System Health" -Mode "Daily" -TaskName "AetherDesk Daily System Health" -ScriptFile "run-health-ai.ps1" -Time $time
})

$BtnScheduleProductivity.Add_Click({
    $time = $ProductivityTimeBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($time)) { $time = "20:00" }
    Start-ScheduleJob -Name "Schedule Weekly Productivity Report" -Mode "Weekly" -TaskName "AetherDesk Weekly Productivity Report" -ScriptFile "activity-report.ps1" -Time $time -Day "SUN"
})

$BtnScheduleTracker.Add_Click({
    Start-ScheduleJob -Name "Schedule Activity Tracker Login" -Mode "OnLogon" -TaskName "AetherDesk Activity Tracker" -ScriptFile "activity-tracker.ps1" -WindowStyle "Minimized"
})

$BtnRemoveTrackerSchedule.Add_Click({
    Start-ScheduleJob -Name "Remove Activity Tracker Schedule" -Mode "Delete" -TaskName "AetherDesk Activity Tracker"
})

$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(450)
$timer.Add_Tick({
    if ($Script:CurrentJob) {
        $newOutput = Receive-Job -Job $Script:CurrentJob -ErrorAction SilentlyContinue

        foreach ($line in $newOutput) {
            Add-Log $line.ToString() "OUT"
        }

        if ($Script:CurrentJob.State -eq "Running") {
            $Script:SpinnerIndex++
            $frame = $Script:SpinnerFrames[$Script:SpinnerIndex % $Script:SpinnerFrames.Count]
            $message = $Script:BusyMessages[$Script:SpinnerIndex % $Script:BusyMessages.Count]
            $StatusText.Text = "$frame $message..."
        }
        else {
            $state = $Script:CurrentJob.State
            $remainingOutput = Receive-Job -Job $Script:CurrentJob -ErrorAction SilentlyContinue

            foreach ($line in $remainingOutput) {
                Add-Log $line.ToString() "OUT"
            }

            Remove-Job -Job $Script:CurrentJob -Force -ErrorAction SilentlyContinue
            $finishedAction = $Script:CurrentAction
            $Script:CurrentJob = $null
            $Script:CurrentAction = ""

            if ($state -eq "Completed") {
                Add-Log "$finishedAction completed."
                Set-UiBusy $false "$finishedAction completed."
                Update-DashboardStats
            }
            else {
                Add-Log "$finishedAction finished with state: $state" "WARN"
                Set-UiBusy $false "$finishedAction finished with state: $state"
                Update-DashboardStats
            }
        }
    }
})

$Window.Add_Loaded({
    Add-Log "AetherDesk AI UI ready."
    Add-Log "Project path: $Script:BaseDir"
    Load-Settings
    Update-OllamaCard
    Update-DashboardStats
    $timer.Start()
})

$Window.Add_Closing({
    if ($Script:CurrentJob -and $Script:CurrentJob.State -eq "Running") {
        Stop-Job -Job $Script:CurrentJob -Force -ErrorAction SilentlyContinue
        Remove-Job -Job $Script:CurrentJob -Force -ErrorAction SilentlyContinue
    }
})

[void]$Window.ShowDialog()
