# AetherDesk AI

**AetherDesk AI** is a local-first AI command center for Windows that helps users generate AI trend reports, monitor system health, track app usage, and create productivity dashboards from local computer activity.

> Local AI. Local reports. Local productivity intelligence.

**Built by:** [flutterfever.com](https://flutterfever.com)

---

## Overview

AetherDesk AI is an open-source Windows automation toolkit powered by PowerShell, HTML dashboards, and optional local AI through Ollama.

It currently includes three major modules:

1. **Trending AI Report Agent**
2. **System Health AI Agent**
3. **Activity Tracker & Productivity Dashboard**

The project is designed for users who want local AI-powered reporting without depending on a cloud dashboard.

---

## Key Features

| Feature                | Description                                                |
| ---------------------- | ---------------------------------------------------------- |
| Local-first design     | Activity logs and reports stay on your computer            |
| Ollama support         | Uses local LLMs such as `gemma3:1b`                        |
| Trending AI reports    | Generates top AI/open-source technology reports            |
| System health reports  | Checks CPU, RAM, disk, Wi-Fi, Bluetooth, DNS, and internet |
| Activity tracking      | Tracks active Windows apps and window titles               |
| Productivity dashboard | Shows app-wise, category-wise, and time-wise usage         |
| HTML reports           | Generates professional browser-based reports               |
| Save as PDF            | Reports include print/PDF export support                   |
| Scheduler support      | Can run daily/weekly tasks through Windows Task Scheduler  |
| BAT launcher           | Single launcher menu for all modules                       |

---

## Project Modules

### 1. Trending AI Report Agent

Generates a professional report for AI and open-source technology topics.

It can collect and summarize:

* Articles
* Videos
* PDF/research links
* GitHub/open-source links
* Public AI trend resources

Main script:

```powershell
run-agent.ps1
```

Output:

```text
reports/
```

---

### 2. System Health AI Agent

Creates a Windows system health dashboard.

It checks:

* CPU usage
* RAM usage
* Disk usage
* Wi-Fi status
* Bluetooth status
* Internet connectivity
* DNS status
* Battery status
* System uptime
* Top memory-consuming processes

Main script:

```powershell
run-health-ai.ps1
```

Output:

```text
reports/
```

---

### 3. Activity Tracker and Productivity Dashboard

Tracks active app usage and creates a productivity report.

It captures:

* Active app name
* Active window title
* Timestamp
* Date
* Duration
* Productivity category

Main scripts:

```powershell
activity-tracker.ps1
activity-report.ps1
```

Output folders:

```text
activity-data/
reports/
```

---

## Folder Structure

```text
AetherDeskAI/
│
├── AetherDeskAI-Launcher.bat
├── README.md
├── config.json
│
├── ollama.ps1
├── search.ps1
├── report.ps1
│
├── run-agent.ps1
├── run-health-ai.ps1
├── system-health.ps1
│
├── activity-tracker.ps1
├── activity-report.ps1
│
├── reports/
├── logs/
├── cache/
└── activity-data/
```

---

## Requirements

### Required

* Windows 10 or Windows 11
* PowerShell 5.1 or newer
* Internet connection for trending reports

### Optional

* Ollama
* Local AI model such as `gemma3:1b`

---

## Ollama Setup

Download Ollama from:

```text
https://ollama.com/download
```

Start Ollama:

```powershell
ollama serve
```

Pull the recommended lightweight model:

```powershell
ollama pull gemma3:1b
```

Test the model:

```powershell
ollama run gemma3:1b "hello"
```

Check installed models:

```powershell
ollama list
```

---

## Configuration

Edit:

```text
config.json
```

Example:

```json
{
  "appName": "AetherDesk AI",
  "model": "gemma3:1b",
  "fastModel": "",
  "backupModel": "",
  "topics": [
    "Top 10 Trending AI topic"
  ],
  "maxResults": 10,
  "language": "English",
  "includeArticles": true,
  "includeVideos": true,
  "includePDFs": true,
  "includeGithub": true,
  "outputFolder": "reports",
  "askTopicOnRun": true
}
```

For scheduled tasks, set:

```json
"askTopicOnRun": false
```

Scheduled tasks cannot answer interactive prompts.

---

## How to Run

### Use the Launcher

Run:

```powershell
H:\python_project\AetherDeskAI\AetherDeskAI-Launcher.bat
```

The launcher provides menu options for all modules.

---

## Launcher Menu

```text
1. Top 10 Trending AI / Open Source Tech Report
2. System Health AI Report
3. Start Activity Tracker
4. Generate Activity Productivity Dashboard
5. Open Reports Folder

6. Schedule Daily Trending AI Report
7. Schedule Daily System Health Report
8. Schedule Activity Tracker on Windows Login
9. Schedule Weekly Productivity Report

10. Check Ollama Status
11. Ollama Install / Run Instructions
12. Show Usage Instructions
13. Remove Activity Tracker Login Schedule

0. Exit
```

---

## Manual Commands

### Generate Trending AI Report

```powershell
cd H:\python_project\AetherDeskAI
powershell -ExecutionPolicy Bypass -File .\run-agent.ps1
```

---

### Generate System Health Report

```powershell
cd H:\python_project\AetherDeskAI
powershell -ExecutionPolicy Bypass -File .\run-health-ai.ps1
```

---

### Start Activity Tracker

```powershell
cd H:\python_project\AetherDeskAI
powershell -ExecutionPolicy Bypass -File .\activity-tracker.ps1
```

Keep the tracker window open. Closing it will stop tracking.

---

### Generate Productivity Dashboard

```powershell
cd H:\python_project\AetherDeskAI
powershell -ExecutionPolicy Bypass -File .\activity-report.ps1
```

The productivity dashboard uses whatever activity data is available. Even one minute of tracking can generate a partial report.

---

## Activity Tracker Workflow

1. Start the launcher.
2. Choose **Start Activity Tracker**.
3. The tracker opens in a new terminal window.
4. Keep the tracker window open.
5. Work normally on your computer.
6. Return to the launcher.
7. Choose **Generate Activity Productivity Dashboard**.

Reports are saved in:

```text
reports/
```

Activity logs are saved in:

```text
activity-data/
```

---

## Scheduling

### Start Activity Tracker on Windows Login

```powershell
schtasks /Create /TN "AetherDesk Activity Tracker" /SC ONLOGON /TR "powershell.exe -ExecutionPolicy Bypass -WindowStyle Minimized -File H:\python_project\AetherDeskAI\activity-tracker.ps1" /F
```

---

### Schedule Daily Trending AI Report

```powershell
schtasks /Create /TN "AetherDesk Daily Trending Report" /SC DAILY /ST 09:00 /TR "powershell.exe -ExecutionPolicy Bypass -File H:\python_project\AetherDeskAI\run-agent.ps1" /F
```

---

### Schedule Daily System Health Report

```powershell
schtasks /Create /TN "AetherDesk Daily System Health" /SC DAILY /ST 10:00 /TR "powershell.exe -ExecutionPolicy Bypass -File H:\python_project\AetherDeskAI\run-health-ai.ps1" /F
```

---

### Schedule Weekly Productivity Report

```powershell
schtasks /Create /TN "AetherDesk Weekly Productivity Report" /SC WEEKLY /D SUN /ST 20:00 /TR "powershell.exe -ExecutionPolicy Bypass -File H:\python_project\AetherDeskAI\activity-report.ps1" /F
```

---

### Remove Activity Tracker Login Schedule

```powershell
schtasks /Delete /TN "AetherDesk Activity Tracker" /F
```

---

## Report Types

AetherDesk AI generates professional HTML reports.

Current report types:

* Trending AI dashboard
* System health dashboard
* Productivity dashboard

Reports include:

* KPI cards
* Graphical sections
* AI summary boxes
* Markdown-rendered AI text
* Filterable activity tables
* Save as PDF button

---

## AI Mode and Non-AI Mode

### AI Mode

When Ollama is installed and running, AetherDesk AI can generate:

* AI trend summaries
* System health diagnosis
* Productivity recommendations
* Markdown-based report insights

### Non-AI Mode

When Ollama is missing or not running:

* Activity tracker still works
* Productivity graphs still work
* HTML dashboards can still be generated
* Setup instructions are shown
* AI sections can be skipped or replaced with a fallback message

---

## Privacy

AetherDesk AI is designed to be local-first.

By default:

* Activity data stays on your computer
* Reports are generated locally
* Ollama runs locally
* No cloud database is required
* No activity data is uploaded by this project

Important: The trending report module uses internet search sources to collect public links.

---

## Current Limitations

* Windows-only at the current stage
* PowerShell-based interface
* Activity tracking works only while the tracker is running
* Past activity before tracker start cannot be recovered
* App categorization is rule-based
* AI summaries require Ollama
* Browser tab classification depends on active window title

---

## Roadmap

### Near-term

* Better HTML dashboard themes
* More stable PDF export
* SQLite storage
* Improved scheduler manager
* Better app category mapping
* Installer script

### Upcoming ETL Pipeline

Future versions will include an ETL system for:

* Extracting local logs
* Cleaning activity data
* Transforming app usage records
* Aggregating daily/weekly summaries
* Detecting sessions
* Normalizing app names
* Exporting CSV, JSON, SQLite, and dashboard data

---

## Vector Database Roadmap

AetherDesk AI will support vector-based storage for semantic search over local reports and activity history.

Planned vector database options:

* ChromaDB
* Qdrant
* LanceDB
* SQLite vector extensions
* Local file-based vector index

Possible use cases:

* Search old reports semantically
* Ask questions about previous productivity patterns
* Find similar system health issues
* Compare week-by-week work behavior
* Build local AI memory

---

## Embedding-Powered Intelligence

Future versions will use embeddings for:

* Activity summaries
* System health logs
* Trend reports
* Semantic search
* Local RAG
* Long-term personal productivity memory

Example future query:

```text
Why did my productivity drop last week?
```

AetherDesk AI will search previous reports, compare patterns, and generate a grounded answer.

---

## Planned Desktop UI

A future desktop version may include:

* Dashboard home screen
* Report center
* Activity timeline
* Health monitor
* Scheduler manager
* Ollama model manager
* Local memory explorer
* Notification center

Possible UI stacks:

* Tauri
* Electron
* Flutter Desktop
* Python PySide
* .NET MAUI

---

## Planned Notifications

Future notification features:

* Daily report ready
* Weekly productivity report ready
* High CPU/RAM warning
* Low disk space alert
* Tracker not running reminder
* Ollama offline warning
* Focus session reminder

---

## Planned Plugin System

Possible plugin modules:

* GitHub monitor
* Local file manager
* Document summarizer
* Deployment doctor
* Software update checker
* Log analyzer
* Personal knowledge base
* Research assistant
* Local RAG assistant

---

## Suggested Repository Topics

```text
local-ai
ollama
windows
powershell
productivity
system-health
activity-tracker
ai-agent
open-source
desktop-automation
local-first
privacy
html-dashboard
```

---

## Suggested Repository Name

Recommended:

```text
aetherdesk-ai
```

Other options:

```text
aetherdesk-local-agent
aetherdesk-windows-ai
localmind-desktop
deskgenie-ai
```

---

## License

Recommended license:

```text
MIT License
```

MIT is simple and flexible for open-source projects.

---

## Contributing

Contributions are welcome.

Suggested contribution areas:

* Better dashboards
* Better app categorization
* SQLite support
* ETL pipeline
* Vector database integration
* Embedding support
* Cross-platform support
* Installer script
* Desktop UI
* Documentation improvements

---

## Responsible Use

This project is intended for personal and transparent use.

Do not use activity tracking to monitor another person without clear consent.

---

## Final Vision

AetherDesk AI aims to become a privacy-friendly local AI operating layer for personal computers.

It should help users understand:

* What is happening on their system
* Which apps they use most
* Where their time goes
* What technology is trending
* How healthy their system is
* How to improve productivity
* How to search their own local history using AI
