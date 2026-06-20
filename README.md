\# AetherDesk AI



\*\*AetherDesk AI\*\* is a local-first, open-source AI command center for Windows. It combines local AI reports, system health diagnosis, user activity tracking, and productivity intelligence into one lightweight PowerShell-based desktop automation toolkit.



It is designed for developers, researchers, students, makers, and productivity-focused users who want useful AI automation on their own computer without depending on cloud dashboards.



> Local-first. Privacy-aware. Extendable. Open-source ready.



\---



\## What is AetherDesk AI?



AetherDesk AI is a modular local agent system that can:



\* Generate top 10 trending AI and open-source technology reports.

\* Analyze local Windows system health.

\* Track active app usage.

\* Generate productivity dashboards from user activity.

\* Create professional HTML reports.

\* Export reports as PDF using browser print.

\* Work with local Ollama models when available.

\* Gracefully bypass AI features when Ollama is not installed or not running.



The project currently runs through PowerShell scripts and a single BAT launcher menu.



\---



\## Why this project?



Modern AI tools are powerful, but many users need a simple local assistant that can help with practical tasks:



\* What is trending in AI today?

\* Is my system healthy?

\* Which apps did I spend time on?

\* Was my work session productive?

\* Can I generate a clean report from local data?

\* Can I automate this daily or weekly?



AetherDesk AI answers these questions locally using scripts, reports, and optional local LLM support.



\---



\## Project Name Meaning



\*\*AetherDesk AI\*\* combines:



\* \*\*Aether\*\*: a magical invisible layer of intelligence around your system.

\* \*\*Desk\*\*: your personal computer workspace.

\* \*\*AI\*\*: local artificial intelligence and automation.



It represents a personal desktop intelligence layer that quietly observes, analyzes, and reports.



\---



\## Current Modules



\### 1. Trending AI Report Agent



Generates a top 10 report for AI, open-source tools, GitHub projects, articles, videos, PDFs, and research resources.



It can be used for:



\* AI trend monitoring

\* Open-source discovery

\* Daily research reports

\* Developer learning reports

\* Newsletter-style summaries



Output:



\* HTML report

\* PDF-ready report

\* AI summary if Ollama is available



Main file:



```powershell

run-agent.ps1

```



\---



\### 2. System Health AI Agent



Analyzes the local Windows machine and generates a system health dashboard.



It checks:



\* Wi-Fi status

\* Internet connectivity

\* DNS status

\* Bluetooth status

\* CPU usage

\* RAM usage

\* Disk health overview

\* Battery status

\* Top memory-consuming processes



Output:



\* Professional HTML dashboard

\* AI-based diagnostic summary if Ollama is available

\* Useful recommendations for troubleshooting



Main file:



```powershell

run-health-ai.ps1

```



\---



\### 3. User Activity \& Productivity Agent



Tracks active Windows apps and creates productivity reports.



It captures:



\* Active app name

\* Active window title

\* Timestamp

\* Date

\* Duration

\* App category

\* Productivity classification



Categories include:



\* Development

\* Learning/Research

\* Documents

\* Communication

\* Browser

\* Entertainment

\* Media

\* File Management

\* Other



Output:



\* App-wise usage graph

\* Category-wise productivity graph

\* Hour-wise activity graph

\* Filterable activity table

\* Productivity score

\* AI productivity summary if Ollama is available

\* Save as PDF button



Main files:



```powershell

activity-tracker.ps1

activity-report.ps1

```



\---



\## Key Features



\### Local-first design



AetherDesk AI is built to run locally on your Windows computer.



Your activity data and reports stay inside your project folder unless you manually share them.



\---



\### Optional local AI with Ollama



The project supports Ollama for local AI summaries.



Recommended model:



```powershell

ollama pull gemma3:1b

```



If Ollama is not installed or not running, the system should not crash. It can still generate non-AI reports and show setup instructions.



\---



\### Professional HTML reports



Reports are generated as clean HTML dashboards with:



\* Cards

\* Graphs

\* KPI blocks

\* Filterable tables

\* AI insight sections

\* Print/PDF support

\* Responsive layout



\---



\### One-click BAT launcher



AetherDesk AI includes a launcher:



```powershell

TrendAI-Launcher.bat

```



The launcher provides a menu for:



\* Trending AI Report

\* System Health Report

\* Start Activity Tracker

\* Generate Productivity Dashboard

\* Open Reports Folder

\* Schedule Daily/Weekly Tasks

\* Check Ollama Status

\* Show usage instructions



\---



\## Folder Structure



```text

AetherDesk-AI/

│

├── config.json

├── TrendAI-Launcher.bat

│

├── ollama.ps1

├── search.ps1

├── report.ps1

│

├── run-agent.ps1

├── run-health-ai.ps1

│

├── system-health.ps1

├── activity-tracker.ps1

├── activity-report.ps1

│

├── reports/

├── logs/

├── cache/

└── activity-data/

```



\---



\## Requirements



\### Required



\* Windows 10 or Windows 11

\* PowerShell 5.1 or newer

\* Internet connection for trend search reports



\### Optional



\* Ollama for local AI summaries

\* Local model such as `gemma3:1b`



\---



\## Ollama Setup



Download Ollama:



```text

https://ollama.com/download

```



Install Ollama for Windows.



Start Ollama:



```powershell

ollama serve

```



Pull the recommended model:



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



\---



\## Configuration



Edit:



```powershell

config.json

```



Example configuration:



```json

{

&#x20; "appName": "AetherDesk AI",

&#x20; "model": "gemma3:1b",

&#x20; "fastModel": "",

&#x20; "backupModel": "",

&#x20; "topics": \[

&#x20;   "open source AI agents"

&#x20; ],

&#x20; "maxResults": 10,

&#x20; "language": "Hinglish",

&#x20; "includeArticles": true,

&#x20; "includeVideos": true,

&#x20; "includePDFs": true,

&#x20; "includeGithub": true,

&#x20; "outputFolder": "reports",

&#x20; "askTopicOnRun": true

}

```



For scheduled tasks, set:



```json

"askTopicOnRun": false

```



Scheduled tasks cannot answer interactive prompts.



\---



\## How to Use



\### Option 1: Use the BAT launcher



Run:



```powershell

TrendAI-Launcher.bat

```



Or double-click the file.



Menu options:



```text

1\. Top 10 Trending AI / Open Source Tech Report

2\. System Health Report

3\. Start Activity Tracker

4\. Generate Activity Productivity Dashboard

5\. Open Reports Folder

6\. Schedule Daily Trending AI Report

7\. Schedule Daily System Health Report

8\. Schedule Activity Tracker on Windows Login

9\. Schedule Weekly Productivity Report

10\. Check Ollama Status

11\. Ollama Install / Run Instructions

12\. Show Usage Instructions

0\. Exit

```



\---



\## Manual Commands



\### Generate trending AI report



```powershell

cd H:\\python\_project\\TrendAI-Agent

powershell -ExecutionPolicy Bypass -File .\\run-agent.ps1

```



\---



\### Generate system health report



```powershell

cd H:\\python\_project\\TrendAI-Agent

powershell -ExecutionPolicy Bypass -File .\\run-health-ai.ps1

```



\---



\### Start activity tracker



```powershell

cd H:\\python\_project\\TrendAI-Agent

powershell -ExecutionPolicy Bypass -File .\\activity-tracker.ps1

```



Keep this window open. If you close it, tracking will stop.



\---



\### Generate productivity dashboard



```powershell

cd H:\\python\_project\\TrendAI-Agent

powershell -ExecutionPolicy Bypass -File .\\activity-report.ps1

```



The dashboard uses whatever activity data is available. Even if the tracker has run for only one minute, it can still generate a partial report.



\---



\## Activity Tracking Workflow



Step 1: Start tracker.



```powershell

powershell -ExecutionPolicy Bypass -File .\\activity-tracker.ps1

```



Step 2: Work normally on your computer.



Step 3: Generate report.



```powershell

powershell -ExecutionPolicy Bypass -File .\\activity-report.ps1

```



Step 4: Open generated HTML dashboard from:



```text

reports/

```



\---



\## Report Output



All generated reports are stored in:



```text

reports/

```



Activity CSV logs are stored in:



```text

activity-data/

```



\---



\## Scheduling



\### Schedule activity tracker on Windows login



```powershell

schtasks /Create /TN "AetherDesk Activity Tracker" /SC ONLOGON /TR "powershell.exe -ExecutionPolicy Bypass -WindowStyle Minimized -File H:\\python\_project\\TrendAI-Agent\\activity-tracker.ps1" /F

```



\---



\### Schedule daily trending report



```powershell

schtasks /Create /TN "AetherDesk Daily Trending Report" /SC DAILY /ST 09:00 /TR "powershell.exe -ExecutionPolicy Bypass -File H:\\python\_project\\TrendAI-Agent\\run-agent.ps1" /F

```



\---



\### Schedule daily system health report



```powershell

schtasks /Create /TN "AetherDesk Daily System Health" /SC DAILY /ST 10:00 /TR "powershell.exe -ExecutionPolicy Bypass -File H:\\python\_project\\TrendAI-Agent\\run-health-ai.ps1" /F

```



\---



\### Schedule weekly productivity report



```powershell

schtasks /Create /TN "AetherDesk Weekly Productivity Report" /SC WEEKLY /D SUN /ST 20:00 /TR "powershell.exe -ExecutionPolicy Bypass -File H:\\python\_project\\TrendAI-Agent\\activity-report.ps1" /F

```



\---



\## AI Behavior



AetherDesk AI supports two modes.



\### AI Mode



When Ollama is installed and running:



\* Reports include AI-generated summaries.

\* System health includes AI diagnosis.

\* Productivity reports include AI recommendations.

\* Trending reports include AI summaries.



\### Non-AI Mode



When Ollama is not installed or not running:



\* The launcher shows installation instructions.

\* Non-AI data collection can still work.

\* Activity tracker can still collect data.

\* Reports can still be generated where supported.

\* AI summary sections can be skipped or replaced with setup instructions.



\---



\## Privacy



AetherDesk AI is designed as a local-first project.



By default:



\* Activity logs are saved locally.

\* Reports are generated locally.

\* No cloud database is required.

\* Ollama runs locally.

\* User activity is not uploaded by this project.



Important: Trend search uses internet sources to collect public links when running the trending report module.



\---



\## Current Limitations



\* Currently optimized for Windows.

\* PowerShell-based interface.

\* Activity tracking works only while tracker is running.

\* Historical activity before tracker start cannot be recovered.

\* Exact app time depends on tracker interval.

\* AI summaries require Ollama and a local model.

\* Browser title classification may not always be perfect.



\---



\## Upcoming Features



\### ETL Pipeline



Future versions will include an ETL pipeline for collecting, cleaning, transforming, and organizing user activity and report data.



Planned ETL features:



\* Data extraction from local logs

\* Daily aggregation

\* App usage normalization

\* Duplicate removal

\* Session detection

\* Time-block analysis

\* Productivity category refinement

\* Export to CSV, JSON, SQLite, and dashboard formats



\---



\### Vector Database Support



AetherDesk AI will support vector-based storage for semantic search across local reports and activity history.



Planned vector database options:



\* ChromaDB

\* Qdrant

\* LanceDB

\* SQLite vector extensions

\* Local file-based vector index



Possible use cases:



\* Search old reports semantically

\* Ask questions about previous system issues

\* Compare productivity patterns across weeks

\* Find similar activity sessions

\* Build memory for the local AI agent



\---



\### Embedding-powered Intelligence



Future versions will support local embeddings.



Planned embedding features:



\* Embedding activity summaries

\* Embedding system health logs

\* Embedding daily trend reports

\* Semantic search over reports

\* RAG-based local question answering

\* Personal productivity memory

\* Long-term insight generation



Example future query:



```text

What were the main reasons my productivity dropped last week?

```



AetherDesk AI will search previous activity summaries, compare patterns, and generate a grounded answer.



\---



\### Local Agent Memory



Future versions may include local memory for:



\* User preferred work hours

\* Common apps

\* Daily routines

\* Frequent system issues

\* Weekly productivity patterns

\* Report history

\* Saved recommendations



\---



\### Desktop UI



A future desktop interface may include:



\* Dashboard home screen

\* Report center

\* Activity timeline

\* Health monitor

\* Scheduler manager

\* Ollama model manager

\* Settings screen

\* Theme customization

\* Notification center



Possible technologies:



\* Tauri

\* Electron

\* Flutter Desktop

\* Python + PySide

\* .NET MAUI



\---



\### Notification System



Planned notifications:



\* Daily report ready

\* Weekly productivity report ready

\* High CPU/RAM warning

\* Low disk space alert

\* Tracker not running reminder

\* Ollama not running warning

\* Focus session reminder



\---



\### Hugging Face Connectivity



Future optional support:



\* Download compatible local models

\* Use Hugging Face model metadata

\* Search open-source models

\* Compare model sizes

\* Suggest lightweight models for local machines



\---



\### Plugin System



AetherDesk AI may support plugins for:



\* GitHub monitoring

\* Local file management

\* Document summarization

\* Deployment doctor

\* Software update checker

\* Log analyzer

\* Personal knowledge base

\* Research assistant



\---



\## Suggested Tech Roadmap



\### Current Version



\* PowerShell

\* BAT launcher

\* HTML dashboard

\* Ollama local LLM

\* CSV storage



\### Next Version



\* SQLite storage

\* Better scheduler manager

\* System tray launcher

\* Improved report templates

\* Export to PDF automatically



\### Future Version



\* ETL engine

\* Vector database

\* Local embeddings

\* RAG assistant

\* Desktop UI

\* Plugin architecture



\---



\## Suggested Repository Tags



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



\---



\## Example Use Cases



\### Developer



A developer can track how much time was spent in VS Code, browser documentation, terminals, GitHub, and distracting apps.



\### Student



A student can monitor study time, research browsing, YouTube usage, and productivity patterns.



\### Researcher



A researcher can generate daily AI trend reports and save them for future analysis.



\### Power User



A power user can monitor system health, activity patterns, and automate local reports.



\---



\## Security Notes



This project is intended for personal and local use.



Do not use it to monitor other users without consent.



Activity tracking should be transparent and controlled by the computer owner.



\---



\## Contributing



Contributions are welcome.



Suggested contribution areas:



\* Better app categorization

\* More dashboard themes

\* SQLite support

\* ETL pipeline

\* Vector database integration

\* Embedding support

\* Cross-platform support

\* Better documentation

\* Installer script

\* Desktop UI



\---



\## License



This project is intended to be released as open source.



Recommended licenses:



\* MIT License for maximum flexibility

\* Apache 2.0 if patent protection is preferred

\* GPLv3 if derivative projects should remain open source



Recommended default:



```text

MIT License

```



\---



\## Project Status



AetherDesk AI is currently in early development.



Current modules are functional but evolving:



\* Trending AI Report Agent

\* System Health Agent

\* Activity Tracker

\* Productivity Dashboard

\* BAT Launcher

\* Ollama support



The project roadmap includes ETL, vector search, embeddings, desktop UI, and long-term local AI memory.



\---



\## Final Vision



AetherDesk AI aims to become a personal local AI operating layer for your computer.



It should help users understand:



\* What is happening in their system

\* What they worked on

\* Where their time went

\* What technology is trending

\* How to improve productivity

\* How to search their own local history using AI



The long-term goal is to build a privacy-friendly, open-source, local AI assistant that works with your files, activity, system, reports, and personal knowledge base.



